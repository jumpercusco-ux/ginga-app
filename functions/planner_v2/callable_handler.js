'use strict';

const { generateClassPlanV2 } = require('./index');
const { FirestoreTransactionQuotaStore } = require('./auth_and_quota_guard');
const { PlannerV2Error } = require('./errors');

/**
 * Maps internal PlannerV2Error codes into Firebase Functions HttpsError-compatible codes/metadata
 * without trusting mutable Firestore roles or client payload overrides.
 */
function mapPlannerErrorToCallableError(err) {
  const normalized =
    err instanceof PlannerV2Error
      ? err
      : new PlannerV2Error('INTERNAL_ERROR', err?.message || 'Error inesperado en Planner V2.', {
          httpStatus: 500,
        });

  let httpsCode = 'internal';
  switch (normalized.code) {
    case 'UNAUTHENTICATED':
      httpsCode = 'unauthenticated';
      break;
    case 'FORBIDDEN_ROLE':
    case 'UNAUTHORIZED_RESOURCE':
    case 'FORBIDDEN_CLIENT_POLICY_OVERRIDE':
      httpsCode = 'permission-denied';
      break;
    case 'INVALID_REQUEST':
    case 'INVALID_REQUIRED_MOVEMENT':
    case 'INVALID_OR_UNAUTHORIZED_REQUIRED_RESOURCE':
    case 'INVALID_CONTINUITY_CONTEXT':
      httpsCode = 'invalid-argument';
      break;
    case 'CONCURRENT_REQUEST_IN_PROGRESS':
      httpsCode = 'aborted';
      break;
    case 'QUOTA_EXCEEDED':
    case 'PILOT_BUDGET_EXCEEDED':
      httpsCode = 'resource-exhausted';
      break;
    case 'PROVIDER_TIMEOUT':
      httpsCode = 'deadline-exceeded';
      break;
    case 'REAL_PROVIDER_DISABLED':
    case 'PRODUCTION_WRITE_BLOCKED':
      httpsCode = 'failed-precondition';
      break;
    case 'VALIDATION_FAILED_AFTER_REPAIR':
    case 'PROVIDER_TRUNCATED_OUTPUT':
    case 'PROVIDER_REJECTED':
      httpsCode = 'failed-precondition';
      break;
    default:
      httpsCode = 'internal';
      break;
  }

  return {
    code: httpsCode,
    message: normalized.message,
    details: {
      planner_code: normalized.code,
      retryable: normalized.retryable === true,
      http_status: normalized.httpStatus || 500,
    },
  };
}

function buildFirestorePizarraResourceRepository(db, uid) {
  return {
    async getResourcesByIds(resourceIds) {
      const out = new Map();
      if (!db || !uid || !Array.isArray(resourceIds) || resourceIds.length === 0) {
        return out;
      }
      const uniqueIds = Array.from(new Set(resourceIds.map((id) => String(id || '').trim()).filter(Boolean)));
      for (const resId of uniqueIds) {
        const snap = await db.collection('users').doc(uid).collection('pizarra_ideas').doc(resId).get();
        if (!snap.exists) continue;
        const data = snap.data() || {};
        out.set(resId, {
          resourceId: resId,
          ownerId: uid,
          shared: data.shared === true,
          title: String(data.title || data.titulo || 'Recurso de Pizarra'),
          type: String(data.type || data.tipo || 'nota'),
          mediaKind: String(data.media_kind || data.type || data.tipo || 'nota'),
          category: String(data.category || data.categoria || 'General'),
          notes: String(data.notes || data.notas || data.descripcion || ''),
          url: String(data.url || data.video_url || ''),
        });
      }
      return out;
    },
  };
}

/**
 * Contract for future `exports.generarPlanClaseV2` Cloud Function Callable.
 * Leaves `functions/index.js` untouched until production activation is authorized.
 */
function createGenerateClassPlanV2CallableHandler({
  db,
  deps = {},
  serverOverrides = {},
  allowLiveFirestore = false,
} = {}) {
  const quotaStore =
    deps.quotaStore || new FirestoreTransactionQuotaStore(db, { allowLiveFirestore });

  return async function handleCallable(data, context) {
    const uid = typeof context?.auth?.uid === 'string' ? context.auth.uid.trim() : '';
    const token = context?.auth?.token && typeof context.auth.token === 'object' ? context.auth.token : {};
    const authContext = uid ? { uid, token } : {};

    const resourceRepository =
      deps.resourceRepository || buildFirestorePizarraResourceRepository(db, uid);

    try {
      const rawRequest =
        data && typeof data === 'object' && data.request && typeof data.request === 'object'
          ? data.request
          : data;

      return await generateClassPlanV2({
        request: rawRequest,
        authContext,
        deps: {
          ...deps,
          quotaStore,
          resourceRepository,
        },
        serverOverrides,
      });
    } catch (err) {
      const callableErr = mapPlannerErrorToCallableError(err);
      const wrapped = new Error(callableErr.message);
      wrapped.code = callableErr.code;
      wrapped.details = callableErr.details;
      wrapped.plannerError = err;
      throw wrapped;
    }
  };
}

module.exports = {
  createGenerateClassPlanV2CallableHandler,
  buildFirestorePizarraResourceRepository,
  mapPlannerErrorToCallableError,
};
