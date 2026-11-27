#!/usr/bin/env node
'use strict';

/**
 * scripts/migrate_planner_v2_firestore.js
 *
 * Idempotent migration script for PED-05 (V1 -> V2 metadata backfill) on Firestore Emulator ONLY.
 * - Preserves ALL existing V1 class blocks, exercises, stats (`veces_impartida`, `ultima_ejecucion`),
 *   Pizarra ideas (`instructor_ideas`), `clases`, `users`, `asistencias`, `sesiones`, and `tutoriales`.
 * - Refuses to run without `FIRESTORE_EMULATOR_HOST` so production (`capoeirafiu-ea8ljo`) is never touched.
 *
 * Usage:
 *   node scripts/migrate_planner_v2_firestore.js --dry-run [--default-instructor-uid=prof_1]
 *   node scripts/migrate_planner_v2_firestore.js --apply   [--default-instructor-uid=prof_1]
 */

const http = require('http');

function parseArgs(argv) {
  const args = {
    apply: false,
    dryRun: true,
    defaultInstructorUid: 'prof_1',
    projectId: process.env.GCLOUD_PROJECT || 'demo-ginga-test',
  };
  for (const raw of argv) {
    if (raw === '--apply') {
      args.apply = true;
      args.dryRun = false;
    } else if (raw === '--dry-run') {
      args.apply = false;
      args.dryRun = true;
    } else if (raw.startsWith('--default-instructor-uid=')) {
      args.defaultInstructorUid = raw.split('=')[1].trim() || 'prof_1';
    } else if (raw.startsWith('--project=')) {
      args.projectId = raw.split('=')[1].trim() || args.projectId;
    }
  }
  return args;
}

function assertEmulatorOnly(projectId) {
  const host = String(process.env.FIRESTORE_EMULATOR_HOST || '').trim();
  if (!host) {
    throw new Error(
      'BLOQUEADO: FIRESTORE_EMULATOR_HOST no está definido. Esta migración solo puede ejecutarse contra el Emulador de Firestore.'
    );
  }
  if (projectId === 'capoeirafiu-ea8ljo') {
    throw new Error(
      'BLOQUEADO: el proyecto capoeirafiu-ea8ljo (producción) está estrictamente prohibido en este script.'
    );
  }
  const [hostname, portStr] = host.split(':');
  return { hostname, port: Number(portStr || 8080) };
}

function requestEmulator({ hostname, port }, method, path, body = null) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request(
      {
        hostname,
        port,
        path,
        method,
        headers: {
          Authorization: 'Bearer owner',
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

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    return Number.isInteger(val) ? { integerValue: String(val) } : { doubleValue: val };
  }
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map((item) => toFirestoreValue(item)) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      if (v !== undefined) fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

async function listCollectionDocs(endpoint, projectId, collectionName) {
  const docs = [];
  let pageToken = '';
  do {
    const tokenQuery = pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : '';
    const res = await requestEmulator(
      endpoint,
      'GET',
      `/v1/projects/${projectId}/databases/(default)/documents/${collectionName}?pageSize=200${tokenQuery}`
    );
    if (res.status >= 400) {
      throw new Error(`Error listando ${collectionName}: HTTP ${res.status} ${JSON.stringify(res.body)}`);
    }
    const items = Array.isArray(res.body?.documents) ? res.body.documents : [];
    docs.push(...items);
    pageToken = res.body?.nextPageToken || '';
  } while (pageToken);
  return docs;
}

async function runMigration(options = {}) {
  const args = {
    apply: options.apply === true,
    dryRun: options.apply !== true,
    defaultInstructorUid: options.defaultInstructorUid || 'prof_1',
    projectId: options.projectId || process.env.GCLOUD_PROJECT || 'demo-ginga-test',
  };
  const endpoint = assertEmulatorOnly(args.projectId);
  const nowIso = new Date().toISOString();

  const summary = {
    mode: args.apply ? 'apply' : 'dry-run',
    projectId: args.projectId,
    plansScanned: 0,
    plansToMigrate: 0,
    plansUpdated: 0,
    ideasScanned: 0,
    ideasToMigrate: 0,
    ideasUpdated: 0,
    unchanged: 0,
  };

  // 1. Migrate legacy `instructor_planes_clase` without mutating pedagogical content
  const planDocs = await listCollectionDocs(endpoint, args.projectId, 'instructor_planes_clase');
  summary.plansScanned = planDocs.length;

  for (const doc of planDocs) {
    const fields = doc.fields || {};
    const patch = {};
    if (!fields.schema_version) {
      patch.schema_version = 1;
    }
    if (!fields.plan_status) {
      patch.plan_status = 'saved';
    }
    if (!fields.revision) {
      patch.revision = 1;
    }
    if (!fields.instructor_id) {
      patch.instructor_id = args.defaultInstructorUid;
    }
    if (Object.keys(patch).length === 0) {
      summary.unchanged += 1;
      continue;
    }
    summary.plansToMigrate += 1;
    patch.migrated_metadata_at = nowIso;

    if (args.apply) {
      const updateKeys = Object.keys(patch)
        .map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`)
        .join('&');
      const firestoreFields = {};
      for (const [k, v] of Object.entries(patch)) {
        firestoreFields[k] = toFirestoreValue(v);
      }
      const res = await requestEmulator(
        endpoint,
        'PATCH',
        `/v1/${doc.name}?${updateKeys}`,
        { fields: firestoreFields }
      );
      if (res.status >= 400) {
        throw new Error(`Error migrando plan ${doc.name}: HTTP ${res.status} ${JSON.stringify(res.body)}`);
      }
      summary.plansUpdated += 1;
    }
  }

  // 2. Migrate legacy `instructor_ideas` without mutating title, url, notes, or completion counters
  const ideaDocs = await listCollectionDocs(endpoint, args.projectId, 'instructor_ideas');
  summary.ideasScanned = ideaDocs.length;

  for (const doc of ideaDocs) {
    const fields = doc.fields || {};
    const patch = {};
    if (!fields.instructor_id) {
      patch.instructor_id = args.defaultInstructorUid;
    }
    if (!fields.shared) {
      patch.shared = true;
    }
    if (Object.keys(patch).length === 0) {
      summary.unchanged += 1;
      continue;
    }
    summary.ideasToMigrate += 1;
    patch.migrated_metadata_at = nowIso;

    if (args.apply) {
      const updateKeys = Object.keys(patch)
        .map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`)
        .join('&');
      const firestoreFields = {};
      for (const [k, v] of Object.entries(patch)) {
        firestoreFields[k] = toFirestoreValue(v);
      }
      const res = await requestEmulator(
        endpoint,
        'PATCH',
        `/v1/${doc.name}?${updateKeys}`,
        { fields: firestoreFields }
      );
      if (res.status >= 400) {
        throw new Error(`Error migrando idea ${doc.name}: HTTP ${res.status} ${JSON.stringify(res.body)}`);
      }
      summary.ideasUpdated += 1;
    }
  }

  return summary;
}

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));
  runMigration(args)
    .then((summary) => {
      console.log(JSON.stringify(summary, null, 2));
    })
    .catch((err) => {
      console.error(err?.message || err);
      process.exit(1);
    });
}

module.exports = {
  runMigration,
  parseArgs,
};
