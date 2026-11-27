'use strict';

const crypto = require('crypto');
const { PlannerV2Error } = require('./errors');

const ALLOWED_CLAIM_KEYS = ['instructor', 'profesor', 'teacher', 'admin', 'curriculum_admin'];
const ALLOWED_TOKEN_ROLES = new Set(['instructor', 'profesor', 'teacher', 'admin', 'administrador']);

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
  const rawTokenRole = typeof token.rol === 'string' ? token.rol.trim().toLowerCase() : '';
  if (rawTokenRole && ALLOWED_TOKEN_ROLES.has(rawTokenRole)) {
    matched.push(`rol:${rawTokenRole}`);
  }
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
 * Atomic transactional Firestore quota and requestId idempotency store (`PED-04C2-D`).
 * Enforces emulator-only safety by default unless `allowLiveFirestore: true` is explicitly passed.
 */
class FirestoreTransactionQuotaStore {
  constructor(firestoreDb, { allowLiveFirestore = false, collectionPrefix = 'planner_ai' } = {}) {
    this.db = firestoreDb;
    this.allowLiveFirestore = allowLiveFirestore === true;
    this.usageCollection = `${collectionPrefix}_usage`;
    this.requestsCollection = `${collectionPrefix}_requests`;
  }

  _assertSafeFirestoreTarget() {
    if (!this.db) {
      throw new PlannerV2Error(
        'PRODUCTION_WRITE_BLOCKED',
        'No se proporcionó una instancia de Firestore válida para FirestoreTransactionQuotaStore.',
        { httpStatus: 503 }
      );
    }
    const isEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
    if (!isEmulator && !this.allowLiveFirestore) {
      throw new PlannerV2Error(
        'PRODUCTION_WRITE_BLOCKED',
        'Escritura bloqueada: FirestoreTransactionQuotaStore requiere FIRESTORE_EMULATOR_HOST o autorización explícita.',
        { httpStatus: 503 }
      );
    }
  }

  _requestDocId(actorId, requestId) {
    const reqHash = crypto.createHash('sha256').update(`${actorId}::${requestId}`).digest('hex').slice(0, 32);
    const safeActor = String(actorId).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 48);
    return `${safeActor}__${reqHash}`;
  }

  _usageDocId(actorId, dayBucket) {
    const safeActor = String(actorId).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 64);
    return `${safeActor}_${dayBucket}`;
  }

  async acquireSlot({
    actorId,
    requestId,
    nowMs = Date.now(),
    dailyLimit = 20,
    perMinuteLimit = 4,
  }) {
    this._assertSafeFirestoreTarget();
    const cleanReqId = typeof requestId === 'string' ? requestId.trim() : '';
    if (!cleanReqId) {
      throw new PlannerV2Error(
        'INVALID_REQUEST',
        'El identificador request_id es obligatorio para idempotencia y control de cuota.',
        { httpStatus: 400 }
      );
    }

    const dayBucket = getLimaDayBucket(nowMs);
    const usageRef = this.db.collection(this.usageCollection).doc(this._usageDocId(actorId, dayBucket));
    const reqRef = this.db.collection(this.requestsCollection).doc(this._requestDocId(actorId, cleanReqId));

    return this.db.runTransaction(async (tx) => {
      const reqSnap = await tx.get(reqRef);
      if (reqSnap.exists) {
        const existing = reqSnap.data() || {};
        if (existing.status === 'completed' && existing.response_json) {
          return {
            status: 'replay',
            cachedResponse: JSON.parse(existing.response_json),
          };
        }
        if (existing.status === 'in_progress') {
          throw new PlannerV2Error(
            'CONCURRENT_REQUEST_IN_PROGRESS',
            'Ya existe una solicitud en curso con el mismo request_id.',
            { httpStatus: 409, retryable: true }
          );
        }
      }

      const usageSnap = await tx.get(usageRef);
      const usageData = usageSnap.exists ? usageSnap.data() || {} : {};
      let dailyReserved = usageData.day_bucket === dayBucket ? Number(usageData.daily_reserved || 0) : 0;
      let minuteTimestamps = Array.isArray(usageData.minute_timestamps)
        ? usageData.minute_timestamps.map((n) => Number(n)).filter((ts) => nowMs - ts < 60000)
        : [];

      if (dailyReserved >= dailyLimit) {
        throw new PlannerV2Error(
          'QUOTA_EXCEEDED',
          `Se alcanzó la cuota diaria de ${dailyLimit} generaciones para este instructor.`,
          { httpStatus: 429, details: { scope: 'daily', limit: dailyLimit } }
        );
      }

      if (minuteTimestamps.length >= perMinuteLimit) {
        throw new PlannerV2Error(
          'QUOTA_EXCEEDED',
          `Se alcanzó el límite de ${perMinuteLimit} generaciones por minuto. Intenta nuevamente en unos segundos.`,
          { httpStatus: 429, details: { scope: 'per_minute', limit: perMinuteLimit }, retryable: true }
        );
      }

      dailyReserved += 1;
      minuteTimestamps.push(nowMs);
      const reservationToken = `${nowMs}_${dailyReserved}`;

      tx.set(usageRef, {
        actor_id: actorId,
        day_bucket: dayBucket,
        daily_reserved: dailyReserved,
        minute_timestamps: minuteTimestamps,
        updated_at_ms: nowMs,
      });

      tx.set(reqRef, {
        actor_id: actorId,
        request_id: cleanReqId,
        day_bucket: dayBucket,
        status: 'in_progress',
        started_at_ms: nowMs,
        reservation_token: reservationToken,
      });

      return {
        status: 'acquired',
        reservationToken,
        usageSnapshot: {
          dayBucket,
          dailyUsed: dailyReserved,
          dailyLimit,
          minuteUsed: minuteTimestamps.length,
          perMinuteLimit,
        },
      };
    });
  }

  async commitResult({ actorId, requestId, response }) {
    this._assertSafeFirestoreTarget();
    const cleanReqId = String(requestId || '').trim();
    const reqRef = this.db.collection(this.requestsCollection).doc(this._requestDocId(actorId, cleanReqId));
    await reqRef.set(
      {
        actor_id: actorId,
        request_id: cleanReqId,
        status: 'completed',
        completed_at_ms: Date.now(),
        response_json: JSON.stringify(response),
      },
      { merge: true }
    );
  }

  async releaseOnFailure({ actorId, requestId, nowMs = Date.now(), billable = false }) {
    this._assertSafeFirestoreTarget();
    const cleanReqId = String(requestId || '').trim();
    if (!cleanReqId) return;
    const dayBucket = getLimaDayBucket(nowMs);
    const reqRef = this.db.collection(this.requestsCollection).doc(this._requestDocId(actorId, cleanReqId));
    const usageRef = this.db.collection(this.usageCollection).doc(this._usageDocId(actorId, dayBucket));

    await this.db.runTransaction(async (tx) => {
      const reqSnap = await tx.get(reqRef);
      const usageSnap = await tx.get(usageRef);
      if (reqSnap.exists && reqSnap.data()?.status === 'in_progress') {
        tx.delete(reqRef);
      }
      if (!billable && usageSnap.exists) {
        const usageData = usageSnap.data() || {};
        const dailyReserved = Math.max(0, Number(usageData.daily_reserved || 0) - 1);
        const minuteTimestamps = Array.isArray(usageData.minute_timestamps)
          ? usageData.minute_timestamps.map((n) => Number(n)).filter((ts) => nowMs - ts < 60000)
          : [];
        if (minuteTimestamps.length > 0) {
          minuteTimestamps.pop();
        }
        tx.set(
          usageRef,
          {
            ...usageData,
            daily_reserved: dailyReserved,
            minute_timestamps: minuteTimestamps,
            updated_at_ms: nowMs,
          },
          { merge: true }
        );
      }
    });
  }
}

module.exports = {
  ALLOWED_CLAIM_KEYS,
  assertAuthorizedActor,
  getLimaDayBucket,
  InMemoryAtomicQuotaStore,
  FirestoreTransactionQuotaStore,
};
