#!/usr/bin/env node
'use strict';

/**
 * scripts/seed_staging_synthetic_data.js
 *
 * Sembrador sintético e idempotente (CERO PII, CERO producción) para entorno Emulator o Staging autorizado.
 *
 * Uso:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed_staging_synthetic_data.js --dry-run
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed_staging_synthetic_data.js --apply
 */

const fs = require('fs');
const http = require('http');
const https = require('https');
const path = require('path');
const admin = require('../functions/node_modules/firebase-admin');
const { runImport, computeContentHash } = require('./import_curriculum_to_firestore');

const CATALOG_PATH = path.resolve(__dirname, '../data/curriculum/fiu_adulto_v1.json');

function parseArgs(argv) {
  const args = {
    apply: false,
    dryRun: true,
    includeCurriculum: true,
    projectId: process.env.GCLOUD_PROJECT || 'demo-ginga-test',
    allowStaging: '',
  };
  for (const raw of argv) {
    if (raw === '--apply') {
      args.apply = true;
      args.dryRun = false;
    } else if (raw === '--dry-run') {
      args.apply = false;
      args.dryRun = true;
    } else if (raw === '--skip-curriculum') {
      args.includeCurriculum = false;
    } else if (raw.startsWith('--project=')) {
      args.projectId = raw.split('=')[1].trim() || args.projectId;
    } else if (raw.startsWith('--allow-staging=')) {
      args.allowStaging = raw.split('=')[1].trim();
    }
  }
  return args;
}

function assertSafeTarget(projectId, allowStaging) {
  if (!projectId || projectId === 'capoeirafiu-ea8ljo') {
    throw new Error('BLOQUEADO: prohibido sembrar datos sobre el proyecto productivo capoeirafiu-ea8ljo.');
  }
  const hasEmulator = Boolean(String(process.env.FIRESTORE_EMULATOR_HOST || '').trim());
  if (!hasEmulator && allowStaging !== projectId) {
    throw new Error(
      `BLOQUEADO: sin FIRESTORE_EMULATOR_HOST debes autorizar explícitamente --allow-staging=${projectId}.`
    );
  }
}

function toFsVal(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFsVal) } };
  if (typeof v === 'object') return { mapValue: { fields: toFsFields(v) } };
  return { stringValue: String(v) };
}

function toFsFields(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined) out[k] = toFsVal(v);
  }
  return out;
}

function fromFsVal(v) {
  if (!v || typeof v !== 'object') return v;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return Boolean(v.booleanValue);
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return ((v.arrayValue && v.arrayValue.values) || []).map(fromFsVal);
  if ('mapValue' in v) return fromFsFields((v.mapValue && v.mapValue.fields) || {});
  return v;
}

function fromFsFields(fields = {}) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) out[k] = fromFsVal(v);
  return out;
}

function createRestBearerStore(projectId, accessToken) {
  function request(method, reqPath, body = null) {
    return new Promise((resolve, reject) => {
      const payload = body ? JSON.stringify(body) : null;
      const req = https.request(
        {
          hostname: 'firestore.googleapis.com',
          port: 443,
          path: reqPath,
          method,
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'x-goog-user-project': projectId,
            'Content-Type': 'application/json',
            ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
          },
        },
        (res) => {
          let data = '';
          res.on('data', (c) => (data += c));
          res.on('end', () => {
            let parsed = null;
            try {
              parsed = data ? JSON.parse(data) : null;
            } catch (_) {
              parsed = data;
            }
            resolve({ status: res.statusCode, body: parsed });
          });
        }
      );
      req.on('error', reject);
      if (payload) req.write(payload);
      req.end();
    });
  }

  const base = `/v1/projects/${projectId}/databases/(default)/documents`;
  return {
    kind: 'REST_BEARER_STAGING',
    async getDoc(collection, docId) {
      const res = await request('GET', `${base}/${collection}/${encodeURIComponent(docId)}`);
      if (res.status === 404) return null;
      if (res.status >= 400) throw new Error(`Firestore REST GET ${collection}/${docId} HTTP ${res.status}: ${JSON.stringify(res.body)}`);
      return fromFsFields(res.body.fields || {});
    },
    async setDoc(collection, docId, payload) {
      const res = await request('PATCH', `${base}/${collection}/${encodeURIComponent(docId)}`, {
        fields: toFsFields(payload),
      });
      if (res.status >= 400) throw new Error(`Firestore REST PATCH ${collection}/${docId} HTTP ${res.status}: ${JSON.stringify(res.body)}`);
    },
    async mergeDocIfExists(collection, docId, partialData) {
      const existing = await this.getDoc(collection, docId);
      if (!existing) return false;
      const keys = Object.keys(partialData).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
      const res = await request('PATCH', `${base}/${collection}/${encodeURIComponent(docId)}?${keys}`, {
        fields: toFsFields(partialData),
      });
      if (res.status >= 400) throw new Error(`Firestore REST MERGE ${collection}/${docId} HTTP ${res.status}: ${JSON.stringify(res.body)}`);
      return true;
    },
  };
}

function createAdminCurriculumStore(db) {
  return {
    kind: 'ADMIN_SDK_STAGING',
    async getDoc(collection, docId) {
      const snap = await db.collection(collection).doc(docId).get();
      return snap.exists ? snap.data() || null : null;
    },
    async setDoc(collection, docId, payload) {
      await db.collection(collection).doc(docId).set(payload);
    },
    async mergeDocIfExists(collection, docId, partialData) {
      const ref = db.collection(collection).doc(docId);
      const snap = await db.collection(collection).doc(docId).get();
      if (!snap.exists) return false;
      await ref.set(partialData, { merge: true });
      return true;
    },
  };
}

function buildSyntheticFixtures() {
  return [
    {
      collection: 'users',
      docId: 'admin_staging',
      data: {
        uid: 'admin_staging',
        rol: 'admin',
        nombre: 'Admin Staging',
        email: 'admin_staging@ginga.test',
        status: 'activo',
        synthetic: true,
      },
    },
    {
      collection: 'users',
      docId: 'prof_staging',
      data: {
        uid: 'prof_staging',
        rol: 'profesor',
        nombre: 'Profesor Staging',
        email: 'prof_staging@ginga.test',
        status: 'activo',
        corda: 'Monitor',
        synthetic: true,
      },
    },
    {
      collection: 'users',
      docId: 'alumno_staging_1',
      data: {
        uid: 'alumno_staging_1',
        rol: 'alumno',
        nombre: 'Alumno Demo Uno',
        email: 'alumno_staging_1@ginga.test',
        status: 'nuevo',
        corda: 'Crua',
        synthetic: true,
      },
    },
    {
      collection: 'users',
      docId: 'alumno_staging_2',
      data: {
        uid: 'alumno_staging_2',
        rol: 'alumno',
        nombre: 'Alumna Demo Dos',
        email: 'alumno_staging_2@ginga.test',
        status: 'activo',
        corda: 'Crua',
        synthetic: true,
      },
    },
    {
      collection: 'clases',
      docId: 'clase_infantil_mj',
      data: {
        nombre: 'Infantil M/J 18:00',
        nivel: 'Infantil',
        dias: 'M, J',
        hora: '18:00',
        sede: 'Cusco (Staging)',
        cupos_disponibles: 8,
        instructor_id: 'prof_staging',
        tipo: 'regular',
        synthetic: true,
      },
    },
    {
      collection: 'clases',
      docId: 'clase_adultos_mj',
      data: {
        nombre: 'Adultos M/J 19:30',
        nivel: 'Adultos',
        dias: 'M, J',
        hora: '19:30',
        sede: 'Cusco (Staging)',
        cupos_disponibles: 10,
        instructor_id: 'prof_staging',
        tipo: 'regular',
        synthetic: true,
      },
    },
    {
      collection: 'sesiones',
      docId: 'sesion_qr_staging_1',
      data: {
        clase_id: 'clase_infantil_mj',
        nivel: 'Infantil',
        hora: '18:00',
        fecha: '2026-11-27',
        activa: true,
        instructor_id: 'prof_staging',
        synthetic: true,
      },
    },
    {
      collection: 'instructor_ideas',
      docId: 'idea_staging_01',
      data: {
        id: 'idea_staging_01',
        instructor_id: 'prof_staging',
        titulo: 'Juego de Palma y Esquiva',
        tipo: 'dinamica',
        categoria: 'Juegos',
        notas: 'Participación simultánea en parejas rotativas con ritmo de palmas y voz.',
        shared: true,
        veces_impartida: 0,
        completado: false,
        synthetic: true,
      },
    },
    {
      collection: 'instructor_ideas',
      docId: 'idea_staging_02',
      data: {
        id: 'idea_staging_02',
        instructor_id: 'prof_staging',
        titulo: 'Cadena Ginga-Armada-Au',
        tipo: 'ejercicio',
        categoria: 'Técnica',
        notas: 'Secuencia básica sin colchonetas y con separación de seguridad.',
        shared: true,
        veces_impartida: 0,
        completado: false,
        synthetic: true,
      },
    },
    {
      collection: 'config',
      docId: 'negocio',
      data: {
        sede: 'Cusco (Staging Sintético)',
        precio_regular: 140,
        synthetic: true,
      },
    },
  ];
}

async function seedSyntheticStagingData({
  apply = false,
  projectId = process.env.GCLOUD_PROJECT || 'demo-ginga-test',
  allowStaging = '',
  includeCurriculum = true,
  db = null,
  accessToken = process.env.GCLOUD_ACCESS_TOKEN || '',
} = {}) {
  assertSafeTarget(projectId, allowStaging);

  const useBearerRest = Boolean(String(accessToken || '').trim()) && !process.env.FIRESTORE_EMULATOR_HOST && !db;
  let store = null;
  if (useBearerRest) {
    store = createRestBearerStore(projectId, String(accessToken).trim());
  } else {
    if (!db) {
      if (!admin.apps.length) {
        admin.initializeApp({ projectId });
      }
      db = admin.firestore();
    }
    store = createAdminCurriculumStore(db);
  }

  const fixtures = buildSyntheticFixtures();
  const report = {
    mode: apply ? 'apply' : 'dry-run',
    project_id: projectId,
    synthetic_created: 0,
    synthetic_updated: 0,
    synthetic_skipped: 0,
    curriculum: null,
  };

  for (const item of fixtures) {
    const contentHash = computeContentHash(item.data);
    const existing = await store.getDoc(item.collection, item.docId);
    if (existing && existing.seed_hash === contentHash) {
      report.synthetic_skipped += 1;
      continue;
    }
    if (existing) {
      report.synthetic_updated += 1;
    } else {
      report.synthetic_created += 1;
    }
    if (apply) {
      const merged = existing ? { ...existing, ...item.data, seed_hash: contentHash } : { ...item.data, seed_hash: contentHash };
      await store.setDoc(item.collection, item.docId, merged);
    }
  }

  if (includeCurriculum) {
    const catalogData = JSON.parse(fs.readFileSync(CATALOG_PATH, 'utf8'));
    report.curriculum = await runImport(catalogData, store, {
      dryRun: !apply,
      syncTutorialRefs: false,
      allowLiveWrite: !process.env.FIRESTORE_EMULATOR_HOST,
      confirmProduction: false,
      emulatorHost: process.env.FIRESTORE_EMULATOR_HOST || '',
    });
  }

  return report;
}

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));
  seedSyntheticStagingData(args)
    .then((res) => {
      console.log(JSON.stringify(res, null, 2));
      process.exit(0);
    })
    .catch((err) => {
      console.error('Error en seed_staging_synthetic_data:', err.message);
      process.exit(1);
    });
}

module.exports = {
  seedSyntheticStagingData,
  buildSyntheticFixtures,
  assertSafeTarget,
};
