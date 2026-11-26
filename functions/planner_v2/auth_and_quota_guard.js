'use strict';

const { PlannerV2Error } = require('./errors');

const ALLOWED_CLAIM_KEYS = ['instructor', 'teacher', 'admin', 'curriculum_admin'];

/**
 * Verifies actor authorization strictly via signed Firebase Auth Custom Claims.
 * NEVER trusts mutable Firestore fields (`users/{uid}.rol`) or client payload fields.
 * Local development unauthenticated bypass is allowed ONLY when explicitly enabled in serverConfig
 * AND not running in production or Cloud Functions runtime.
 */
function assertAuthorizedActor(authContext, serverConfig) {
  const token = authContext?.token || {};
  const uid = typeof authContext?.uid === 'string' ? authContext.uid.trim() : '';

  if (!uid) {
    const canBypass =
      serverConfig.allowLocalDevSimulatedBypass === true &&
      serverConfig.isProductionEnv !== true &&
      !process.env.FUNCTION_TARGET &&
      !process.env.K_SERVICE;

    if (canBypass) {
      return {
        actorId: 'local_dev_simulated_instructor',
        actorMode: 'local_dev_simulated_unauthenticated',
        claimsMatched: ['local_dev_bypass'],
      };
    }

    throw new PlannerV2Error(
      'UNAUTHENTICATED',
      'Debes iniciar sesión con una cuenta autorizada de instructor.',
      { httpStatus: 401 }
    );
  }

  const matched = ALLOWED_CLAIM_KEYS.filter((k) => token[k] === true);
  if (matched.length === 0) {
    throw new PlannerV2Error(
      'FORBIDDEN_ROLE',
      'Tu cuenta no posee Custom Claims firmados de instructor o administrador para usar el planificador IA.',
      { httpStatus: 403 }
    );
  }

  return {
    actorId: uid,
    actorMode: 'custom_claims',
    claimsMatched: matched,
  };
}

function getLimaDayBucket(nowMs) {
  // America/Lima is fixed UTC-5 year-round (no DST).
  const limaMs = nowMs - 5 * 60 * 60 * 1000;
  return new Date(limaMs).toISOString().slice(0, 10);
}

/**
 * Atomic in-memory quota and requestId idempotency store.
 * Simulates Firestore transaction semantics (`runTransaction`) with serialized per-actor locking.
 */
class InMemoryAtomicQuotaStore {
  constructor() {
    this._actors = new Map();
    this._idempotency = new Map();
    this._mutexes = new Map();
  }

  async _withActorLock(actorId, fn) {
    const prev = this._mutexes.get(actorId) || Promise.resolve();
    let releaseNext;
    const next = new Promise((resolve) => {
      releaseNext = resolve;
    });
    this._mutexes.set(actorId, prev.then(() => next, () => next));
    await prev;
    try {
      return await fn();
    } finally {
      releaseNext();
    }
  }

  async acquireSlot({
    actorId,
    requestId,
    nowMs = Date.now(),
    dailyLimit = 20,
    perMinuteLimit = 4,
  }) {
    const cleanReqId = typeof requestId === 'string' ? requestId.trim() : '';
    if (!cleanReqId) {
      throw new PlannerV2Error(
        'INVALID_REQUEST',
        'El identificador request_id es obligatorio para idempotencia y control de cuota.',
        { httpStatus: 400 }
      );
    }

    return this._withActorLock(actorId, async () => {
      const idemKey = `${actorId}::${cleanReqId}`;
      const existing = this._idempotency.get(idemKey);

      if (existing) {
        if (existing.status === 'completed') {
          return { status: 'replay', cachedResponse: existing.response };
        }
        if (existing.status === 'in_progress') {
          throw new PlannerV2Error(
            'CONCURRENT_REQUEST_IN_PROGRESS',
            'Ya existe una solicitud en curso con el mismo request_id.',
            { httpStatus: 409, retryable: true }
          );
        }
      }

      const dayBucket = getLimaDayBucket(nowMs);
      let state = this._actors.get(actorId);
      if (!state || state.dayBucket !== dayBucket) {
        state = {
          dayBucket,
          dailyReserved: 0,
          minuteTimestamps: [],
        };
      }

      // Prune entries older than 60 seconds
      state.minuteTimestamps = state.minuteTimestamps.filter((ts) => nowMs - ts < 60000);

      if (state.dailyReserved >= dailyLimit) {
        throw new PlannerV2Error(
          'QUOTA_EXCEEDED',
          `Se alcanzó la cuota diaria de ${dailyLimit} generaciones para este instructor.`,
          { httpStatus: 429, details: { scope: 'daily', limit: dailyLimit } }
        );
      }

      if (state.minuteTimestamps.length >= perMinuteLimit) {
        throw new PlannerV2Error(
          'QUOTA_EXCEEDED',
          `Se alcanzó el límite de ${perMinuteLimit} generaciones por minuto. Intenta nuevamente en unos segundos.`,
          { httpStatus: 429, details: { scope: 'per_minute', limit: perMinuteLimit }, retryable: true }
        );
      }

      state.dailyReserved += 1;
      state.minuteTimestamps.push(nowMs);
      this._actors.set(actorId, state);

      const reservationToken = `${nowMs}_${state.dailyReserved}`;
      this._idempotency.set(idemKey, {
        status: 'in_progress',
        startedAtMs: nowMs,
        reservationToken,
      });

      return {
        status: 'acquired',
        reservationToken,
        usageSnapshot: {
          dayBucket,
          dailyUsed: state.dailyReserved,
          dailyLimit,
          minuteUsed: state.minuteTimestamps.length,
          perMinuteLimit,
        },
      };
    });
  }

  async commitResult({ actorId, requestId, response }) {
    const idemKey = `${actorId}::${String(requestId || '').trim()}`;
    return this._withActorLock(actorId, async () => {
      this._idempotency.set(idemKey, {
        status: 'completed',
        completedAtMs: Date.now(),
        response,
      });
    });
  }

  async releaseOnFailure({ actorId, requestId, nowMs = Date.now(), billable = false }) {
    const idemKey = `${actorId}::${String(requestId || '').trim()}`;
    return this._withActorLock(actorId, async () => {
      const existing = this._idempotency.get(idemKey);
      if (existing && existing.status === 'in_progress') {
        this._idempotency.delete(idemKey);
      }
      if (!billable) {
        const state = this._actors.get(actorId);
        if (state && state.dailyReserved > 0) {
          state.dailyReserved -= 1;
          state.minuteTimestamps = state.minuteTimestamps.filter((ts) => nowMs - ts < 60000);
          if (state.minuteTimestamps.length > 0) {
            state.minuteTimestamps.pop();
          }
          this._actors.set(actorId, state);
        }
      }
    });
  }

  getActorUsage(actorId, nowMs = Date.now()) {
    const state = this._actors.get(actorId);
    const dayBucket = getLimaDayBucket(nowMs);
    if (!state || state.dayBucket !== dayBucket) {
      return { dayBucket, dailyUsed: 0, minuteUsed: 0 };
    }
    const minuteUsed = state.minuteTimestamps.filter((ts) => nowMs - ts < 60000).length;
    return { dayBucket, dailyUsed: state.dailyReserved, minuteUsed };
  }
}

/**
 * Production Firestore transaction design blueprint for PED-04C2-D (not invoked in PED-04C2-B).
 */
class FirestoreTransactionQuotaStore {
  constructor(firestoreDb) {
    this.db = firestoreDb;
  }

  async acquireSlot() {
    throw new PlannerV2Error(
      'REAL_PROVIDER_DISABLED',
      'FirestoreTransactionQuotaStore está reservado para PED-04C2-D y no escribe en Firebase durante PED-04C2-B.',
      { httpStatus: 501 }
    );
  }
}

module.exports = {
  ALLOWED_CLAIM_KEYS,
  assertAuthorizedActor,
  getLimaDayBucket,
  InMemoryAtomicQuotaStore,
  FirestoreTransactionQuotaStore,
};
