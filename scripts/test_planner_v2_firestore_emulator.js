#!/usr/bin/env node
'use strict';

/**
 * Verifies production readiness of `FirestoreTransactionQuotaStore`, atomic idempotency,
 * Firebase Auth Custom Claims authorization, and `createGenerateClassPlanV2CallableHandler`
 * against Firebase Firestore Emulator (`demo-ginga-test`, JDK 21).
 */

const assert = require('assert');
const admin = require('../functions/node_modules/firebase-admin');
const {
  FirestoreTransactionQuotaStore,
  PlannerV2Error,
} = require('../functions/planner_v2');
const {
  createGenerateClassPlanV2CallableHandler,
} = require('../functions/planner_v2/callable_handler');

async function main() {
  assert(
    process.env.FIRESTORE_EMULATOR_HOST,
    'Este test debe ejecutarse con FIRESTORE_EMULATOR_HOST activo (firebase emulators:exec --only firestore --project demo-ginga-test).'
  );

  const projectId = process.env.GCLOUD_PROJECT || 'demo-ginga-test';
  const app = admin.apps.length
    ? admin.app()
    : admin.initializeApp({ projectId });
  const db = app.firestore();

  // 1. FirestoreTransactionQuotaStore blocks writes if allowLiveFirestore=false without emulator
  const savedHost = process.env.FIRESTORE_EMULATOR_HOST;
  delete process.env.FIRESTORE_EMULATOR_HOST;
  let blockedProd = false;
  try {
    const prodGuardStore = new FirestoreTransactionQuotaStore(db, { allowLiveFirestore: false });
    await prodGuardStore.acquireSlot({ actorId: 'a1', requestId: 'r1' });
  } catch (e) {
    blockedProd = e instanceof PlannerV2Error && e.code === 'PRODUCTION_WRITE_BLOCKED';
  } finally {
    process.env.FIRESTORE_EMULATOR_HOST = savedHost;
  }
  assert(blockedProd, 'Debe bloquear escrituras fuera de emulador salvo autorización explícita.');

  // 2. Concurrent transactional burst against Firestore Emulator (perMinuteLimit=4)
  const store = new FirestoreTransactionQuotaStore(db, { collectionPrefix: 'test_planner_ai' });
  const nowMs = Date.now();
  const burst = await Promise.allSettled(
    Array.from({ length: 6 }, (_, idx) =>
      store.acquireSlot({
        actorId: 'inst_emu_burst',
        requestId: `burst_req_${idx}`,
        nowMs,
        dailyLimit: 20,
        perMinuteLimit: 4,
      })
    )
  );
  const acquired = burst.filter((r) => r.status === 'fulfilled' && r.value.status === 'acquired');
  const quotaExceeded = burst.filter((r) => r.status === 'rejected' && r.reason?.code === 'QUOTA_EXCEEDED');
  assert.strictEqual(acquired.length, 4, `Esperados 4 adquiridos en emulador, hubo ${acquired.length}`);
  assert.strictEqual(quotaExceeded.length, 2, `Esperados 2 QUOTA_EXCEEDED en emulador, hubo ${quotaExceeded.length}`);

  // Verify releaseOnFailure(billable=false) frees slot vs duplicate in-progress rejection
  let dupRejected = false;
  try {
    await store.acquireSlot({
      actorId: 'inst_emu_burst',
      requestId: 'burst_req_0',
      nowMs,
    });
  } catch (e) {
    dupRejected = e.code === 'CONCURRENT_REQUEST_IN_PROGRESS';
  }
  assert(dupRejected, 'Debe rechazar solicitud concurrente con el mismo request_id.');

  await store.releaseOnFailure({
    actorId: 'inst_emu_burst',
    requestId: 'burst_req_0',
    nowMs,
    billable: false,
  });
  const reacquired = await store.acquireSlot({
    actorId: 'inst_emu_burst',
    requestId: 'burst_req_0_retry',
    nowMs,
    dailyLimit: 20,
    perMinuteLimit: 4,
  });
  assert.strictEqual(reacquired.status, 'acquired');

  // 3. Callable handler authorization & Firestore resource integration (simulated offline provider inside emulator test)
  const uid = 'inst_emu_prof_01';
  await db.collection('users').doc(uid).set({ rol: 'profesor', nombre: 'Solo Firestore Rol' });
  await db.collection('users').doc(uid).collection('pizarra_ideas').doc('res_emu_01').set({
    title: 'Drill esquiva en parejas emulador',
    type: 'video',
    media_kind: 'video',
    category: 'Técnica Marcial',
    notes: 'Rondas continuas sin pausa',
    shared: false,
  });

  const callableHandler = createGenerateClassPlanV2CallableHandler({
    db,
    serverOverrides: {
      providerMode: 'simulated',
      realProviderEnabled: false,
    },
  });

  const baseReq = {
    contract_version: '2.1.0',
    request_id: 'emu_callable_req_01',
    creation_mode: 'avanzada',
    group_context: {
      source: 'real_class',
      group_label: 'Adultos M/J 19:00',
      audience_type: 'adultos',
      age_min: 16,
      age_max: 40,
      estimated_participants: 12,
      experience_distribution: { principiantes: 5, intermedios: 5, avanzados: 2, manually_confirmed: true },
    },
    curriculum_context: { scope: 'adulto_fiu', target_corda_index: 2 },
    space_context: { space_size: 'mediano', floor_type: 'tatami', available_mats: true, instructors_available: 1 },
    session_config: {
      duration_min: 60,
      focuses: ['Técnica', 'Secuencias'],
      include_musicality_roda: true,
      allow_ai_complementary_proposals: true,
      free_instructions: 'Progresión limpia.',
    },
    selected_movements: [{ movement_id: 'queixada', priority: 'required' }],
    selected_resources: [{ resource_id: 'res_emu_01', priority: 'required', usage_note: 'Aplicar tras calentamiento' }],
  };

  // Unauthenticated -> unauthenticated
  let unauthOk = false;
  try {
    await callableHandler({ request: baseReq }, {});
  } catch (e) {
    unauthOk = e.code === 'unauthenticated';
  }
  assert(unauthOk, 'Callable debe rechazar invocación sin auth.');

  // Mutable Firestore role without signed Custom Claim -> permission-denied
  let mutableRoleBlocked = false;
  try {
    await callableHandler({ request: baseReq }, { auth: { uid, token: {} } });
  } catch (e) {
    mutableRoleBlocked = e.code === 'permission-denied';
  }
  assert(mutableRoleBlocked, 'Callable debe ignorar users/{uid}.rol y exigir Custom Claim.');

  // Signed Custom Claim instructor: true -> executes, reads Pizarra doc & persists atomic quota + idempotency
  const firstResp = await callableHandler(
    { request: baseReq },
    { auth: { uid, token: { instructor: true } } }
  );
  assert.strictEqual(firstResp.status, 'ok');
  assert.strictEqual(firstResp.validation_report.infrastructure.custom_claims_verified, true);
  assert.strictEqual(firstResp.generation_meta.idempotent_replay, false);

  // Duplicate request_id returns idempotent replay from Firestore without burning quota
  const replayResp = await callableHandler(
    { request: baseReq },
    { auth: { uid, token: { instructor: true } } }
  );
  assert.strictEqual(replayResp.generation_meta.idempotent_replay, true);

  console.log('ALL PLANNER V2 FIRESTORE EMULATOR TESTS PASSED.');
}

main().catch((err) => {
  console.error('FAIL test_planner_v2_firestore_emulator:', err);
  process.exitCode = 1;
});
