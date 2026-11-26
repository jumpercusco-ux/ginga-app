#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');
const SOURCE_CATALOG_PATH = path.join(ROOT, 'data/curriculum/fiu_adulto_v1.json');
const BACKEND_CATALOG_PATH = path.join(ROOT, 'functions/planner_v2/data/fiu_adulto_v1.json');
const MANIFEST_PATH = path.join(ROOT, 'functions/planner_v2/data/fiu_adulto_v1.sha256.json');

const EXPECTED_CORDAS = {
  adulto_corda_01: 'Corda Crua',
  adulto_corda_02: 'Corda Crua e Verde',
  adulto_corda_03: 'Corda Verde',
  adulto_corda_04: 'Corda Verde e Laranja',
  adulto_corda_05: 'Corda Laranja',
  adulto_corda_06: 'Corda Laranja e Amarelo',
};

function sha256File(filePath) {
  const buf = fs.readFileSync(filePath);
  return {
    buf,
    hash: crypto.createHash('sha256').update(buf).digest('hex'),
  };
}

function main() {
  const errors = [];
  const check = (cond, msg) => {
    if (!cond) errors.push(msg);
  };

  check(fs.existsSync(SOURCE_CATALOG_PATH), `No existe catálogo fuente: ${SOURCE_CATALOG_PATH}`);
  check(fs.existsSync(BACKEND_CATALOG_PATH), `No existe catálogo backend: ${BACKEND_CATALOG_PATH}`);
  check(fs.existsSync(MANIFEST_PATH), `No existe manifiesto SHA-256: ${MANIFEST_PATH}`);

  if (errors.length === 0) {
    const src = sha256File(SOURCE_CATALOG_PATH);
    const dst = sha256File(BACKEND_CATALOG_PATH);
    const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
    const data = JSON.parse(dst.buf.toString('utf8'));

    check(src.hash === dst.hash, `SHA-256 distinto entre fuente (${src.hash}) y backend (${dst.hash})`);
    check(src.hash === manifest.sha256, `SHA-256 real (${src.hash}) no coincide con manifiesto (${manifest.sha256})`);
    check(Buffer.compare(src.buf, dst.buf) === 0, 'Los archivos no son idénticos byte a byte.');

    const movements = Array.isArray(data.movements) ? data.movements : [];
    const eligible = movements.filter((m) => m.ai_planner_eligible === true);
    const excluded = movements
      .filter((m) => m.ai_planner_eligible !== true)
      .map((m) => m.movement_id)
      .sort();

    check(movements.length === 97, `Movimientos esperados 97; encontrados ${movements.length}`);
    check(eligible.length === 94, `Movimientos elegibles IA esperados 94; encontrados ${eligible.length}`);
    check(
      JSON.stringify(excluded) === JSON.stringify(['au_chibata_pulado', 'desequilibrante', 'espelho_cruz']),
      `IDs excluidos inesperados: ${JSON.stringify(excluded)}`
    );
    check(movements.length === manifest.movements_count, 'Manifest movements_count desactualizado.');
    check(eligible.length === manifest.ai_planner_eligible_count, 'Manifest ai_planner_eligible_count desactualizado.');
    check(
      JSON.stringify(excluded) === JSON.stringify([...manifest.excluded_pending_ids].sort()),
      'Manifest excluded_pending_ids desactualizado.'
    );

    const cordasSummary = data.tracks?.adulto?.cordas_index_summary || [];
    for (const [cordaId, expectedName] of Object.entries(EXPECTED_CORDAS)) {
      const entry = cordasSummary.find((c) => c.corda_id === cordaId);
      check(Boolean(entry), `Falta corda en tracks.adulto.cordas_index_summary: ${cordaId}`);
      if (entry) {
        check(
          entry.nombre_manual === expectedName,
          `Nombre de ${cordaId} esperado "${expectedName}", actual "${entry.nombre_manual}"`
        );
      }
    }

    if (errors.length === 0) {
      console.log(
        `PASS verify_planner_v2_catalog_sync: SHA-256=${src.hash}, movements=${movements.length}, eligible=${eligible.length}, excluded=${excluded.join(',')}`
      );
      return;
    }
  }

  console.error('FAIL verify_planner_v2_catalog_sync:');
  for (const err of errors) {
    console.error(`  - ${err}`);
  }
  process.exitCode = 1;
}

main();
