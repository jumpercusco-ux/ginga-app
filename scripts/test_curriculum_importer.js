#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const http = require('http');
const {
  buildImportPlan,
  runImport,
  createInMemoryStore,
  createEmulatorRestStore,
} = require('./import_curriculum_to_firestore');
const { CATALOG_PATH } = require('./validate_curriculum_catalog');

function clearFirestoreEmulator(emulatorHost, projectId) {
  const [hostname, port] = emulatorHost.split(':');
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname,
      port: Number(port),
      path: `/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      method: 'DELETE',
    }, (res) => {
      let body = '';
      res.on('data', (c) => { body += c; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve();
        } else {
          reject(new Error(`DELETE emulator documents falló (${res.statusCode}): ${body}`));
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function seedLegacyTutorials(catalogData) {
  const tutorials = {};
  for (const t of catalogData.tutorial_mapping) {
    tutorials[t.tutorial_doc_id] = {
      titulo: t.titulo_prod,
      categoria: t.categoria_prod,
      nivel: t.nivel_prod,
      corda: t.corda_prod,
      visible: true,
      imagen_url: `assets/images/${t.tutorial_doc_id}.jpg`,
      video_url: t.has_real_video ? `https://storage.googleapis.com/demo/${t.tutorial_doc_id}.mp4` : '',
      likes: t.has_real_video ? 42 : 0,
    };
  }
  return tutorials;
}

async function runSuite() {
  const catalogData = JSON.parse(fs.readFileSync(CATALOG_PATH, 'utf8'));
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
  const projectId = process.env.GCLOUD_PROJECT || 'demo-ginga-test';
  const mode = emulatorHost ? `FIRESTORE_EMULATOR (${emulatorHost})` : 'IN_MEMORY_MOCK';

  console.log('================================================================');
  console.log(`   TEST SUITE: IMPORTADOR IDEMPOTENTE FIU (${mode})`);
  console.log('================================================================\n');

  let passed = 0;
  let total = 0;
  async function testCase(name, fn) {
    total++;
    await fn();
    passed++;
    console.log(`[PASS] ${name}`);
  }

  // Usar Firestore Emulator si está activo; si no, store en memoria con los 21 tutoriales simulados
  const store = emulatorHost
    ? createEmulatorRestStore(emulatorHost, projectId)
    : createInMemoryStore({ tutoriales: seedLegacyTutorials(catalogData) });

  if (emulatorHost) {
    await clearFirestoreEmulator(emulatorHost, projectId);
    const legacy = seedLegacyTutorials(catalogData);
    for (const [id, data] of Object.entries(legacy)) {
      await store.setDoc('tutoriales', id, data);
    }
  }

  const originalSnapshots = {};
  for (const t of catalogData.tutorial_mapping) {
    originalSnapshots[t.tutorial_doc_id] = await store.getDoc('tutoriales', t.tutorial_doc_id);
  }

  await testCase('01_plan_contiene_164_documentos_esperados', async () => {
    const plan = buildImportPlan(catalogData);
    assert.strictEqual(plan.operations.length, 164, '1 meta + 97 mov + 1 block + 18 cordas + 21 tuts + 26 glosario');
    assert.strictEqual(plan.tutorialAdditiveRefs.length, 21);
  });

  await testCase('02_dry_run_por_defecto_no_realiza_escrituras', async () => {
    const summary = await runImport(catalogData, store, { dryRun: true });
    assert.strictEqual(summary.dryRun, true);
    assert.strictEqual(summary.created, 164);
    assert.strictEqual(summary.updated, 0);
    const meta = await store.getDoc('curriculum_meta', catalogData.catalog_id);
    assert.strictEqual(meta, null, 'Dry-run no debe escribir curriculum_meta');
  });

  await testCase('03_guardia_produccion_rechaza_escritura_no_autorizada', async () => {
    const fakeProdStore = { type: 'firestore_admin' };
    await assert.rejects(
      () => runImport(catalogData, fakeProdStore, {
        dryRun: false,
        emulatorHost: '',
        allowLiveWrite: false,
        confirmProduction: false,
      }),
      /BLOQUEADO/
    );
  });

  await testCase('04_primera_importacion_crea_164_docs_e_intacta_tutoriales', async () => {
    const summary = await runImport(catalogData, store, {
      dryRun: false,
      syncTutorialRefs: false,
      emulatorHost,
    });
    assert.strictEqual(summary.created, 164);
    assert.strictEqual(summary.updated, 0);
    assert.strictEqual(summary.skipped, 0);

    // Verificar bloque compartido 5-6 y cordas 5/6 separadas
    const c5 = await store.getDoc('curriculum_cordas', 'adulto_corda_05');
    const c6 = await store.getDoc('curriculum_cordas', 'adulto_corda_06');
    const b56 = await store.getDoc('curriculum_blocks', 'adulto_bloque_05_06');
    assert.strictEqual(c5.shared_block_id, 'adulto_bloque_05_06');
    assert.strictEqual(c6.shared_block_id, 'adulto_bloque_05_06');
    assert.strictEqual(b56.corda_ids.length, 2);

    // Verificar infantil separado
    const inf1 = await store.getDoc('curriculum_cordas', 'infantil_corda_01');
    assert.strictEqual(inf1.track_id, 'infantil');
    assert.strictEqual(inf1.content_status, 'structure_only_pending_extraction');

    // Verificar exclusión IA en los 3 movimientos ambiguos
    for (const id of ['desequilibrante', 'espelho_cruz', 'au_chibata_pulado']) {
      const m = await store.getDoc('curriculum_movements', id);
      assert.strictEqual(m.ai_planner_eligible, false);
      assert.strictEqual(m.is_ambiguous, true);
      assert.strictEqual(m.review_status, 'pending_technical_review');
    }

    // Verificar los 21 tutoriales 100% intactos
    for (const t of catalogData.tutorial_mapping) {
      const after = await store.getDoc('tutoriales', t.tutorial_doc_id);
      assert.deepStrictEqual(after, originalSnapshots[t.tutorial_doc_id]);
    }
  });

  await testCase('05_segunda_importacion_es_100_por_ciento_idempotente', async () => {
    const summary = await runImport(catalogData, store, {
      dryRun: false,
      syncTutorialRefs: false,
      emulatorHost,
    });
    assert.strictEqual(summary.created, 0);
    assert.strictEqual(summary.updated, 0);
    assert.strictEqual(summary.skipped, 164);
  });

  await testCase('06_sync_aditivo_preserva_videos_y_campos_legacy_en_tutoriales', async () => {
    const summary1 = await runImport(catalogData, store, {
      dryRun: false,
      syncTutorialRefs: true,
      emulatorHost,
    });
    assert.strictEqual(summary1.skipped, 164);
    assert.strictEqual(summary1.tutorialRefsUpdated, 21);

    // Verificar video real compuesto Cocorinha + base
    const cocoBase = await store.getDoc('tutoriales', 'WH4bG3SQ3CSd8ozb1619');
    assert.strictEqual(cocoBase.titulo, 'Cocorinha + base');
    assert.strictEqual(cocoBase.corda, '');
    assert.ok(cocoBase.video_url.endsWith('WH4bG3SQ3CSd8ozb1619.mp4'));
    assert.deepStrictEqual(cocoBase.movement_ids, ['cocorinha']);
    assert.deepStrictEqual(cocoBase.pending_movement_ids, ['ginga']);

    // Verificar Vingativa preserva corda legacy 'Azul' pero recibe referencia curricular
    const vingativa = await store.getDoc('tutoriales', 'nPc9AUD2ynr4JssiV0ys');
    assert.strictEqual(vingativa.corda, 'Azul');
    assert.deepStrictEqual(vingativa.movement_ids, ['vingativa']);
    assert.deepStrictEqual(vingativa.curriculum_corda_ids, ['adulto_corda_04']);

    // Verificar explícitamente preservación de los 21 tutoriales y los 5 videos reales
    assert.strictEqual(catalogData.tutorial_mapping.length, 21);
    const realVideos = catalogData.tutorial_mapping.filter((t) => t.has_real_video);
    assert.strictEqual(realVideos.length, 5);
    for (const t of catalogData.tutorial_mapping) {
      const current = await store.getDoc('tutoriales', t.tutorial_doc_id);
      const orig = originalSnapshots[t.tutorial_doc_id];
      assert.ok(current, `Tutorial faltante: ${t.tutorial_doc_id}`);
      assert.strictEqual(current.titulo, orig.titulo);
      assert.strictEqual(current.categoria, orig.categoria);
      assert.strictEqual(current.nivel, orig.nivel);
      assert.strictEqual(current.corda, orig.corda);
      assert.strictEqual(current.visible, orig.visible);
      assert.strictEqual(current.imagen_url, orig.imagen_url);
      assert.strictEqual(current.video_url, orig.video_url);
      assert.strictEqual(current.likes, orig.likes);
      assert.deepStrictEqual(current.movement_ids, t.movement_ids);
      assert.deepStrictEqual(current.curriculum_corda_ids, t.curriculum_corda_ids);
      if (t.has_real_video) {
        assert.ok(
          typeof current.video_url === 'string' && current.video_url.length > 0,
          `Video real vacío en ${t.tutorial_doc_id}`
        );
      }
    }

    // Re-ejecución idempotente del sync
    const summary2 = await runImport(catalogData, store, {
      dryRun: false,
      syncTutorialRefs: true,
      emulatorHost,
    });
    assert.strictEqual(summary2.tutorialRefsUpdated, 0);
    assert.strictEqual(summary2.tutorialRefsSkipped, 21);
  });

  console.log(`\nRESULTADO IMPORTADOR: ${passed}/${total} PRUEBAS PASS (100%)\n`);
}

if (require.main === module) {
  runSuite().catch((err) => {
    console.error('FAIL en pruebas del importador:', err);
    process.exit(1);
  });
}

module.exports = { runSuite };
