#!/usr/bin/env node
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { validateCatalogData, CATALOG_PATH } = require('./validate_curriculum_catalog');

function stableStringify(value) {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return '[' + value.map(stableStringify).join(',') + ']';
  }
  const keys = Object.keys(value).sort();
  return '{' + keys.map((k) => `${JSON.stringify(k)}:${stableStringify(value[k])}`).join(',') + '}';
}

function computeContentHash(payload) {
  return crypto.createHash('sha256').update(stableStringify(payload)).digest('hex');
}

function slugifyTerm(term) {
  return String(term || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

/**
 * Construye el plan determinista e idempotente de documentos curriculares a importar.
 * No modifica /tutoriales por defecto.
 */
function buildImportPlan(catalogData) {
  const errors = validateCatalogData(catalogData);
  if (errors.length > 0) {
    throw new Error(`Catálogo inválido (${errors.length} errores):\n- ${errors.join('\n- ')}`);
  }

  const operations = [];
  const pushDoc = (collection, docId, rawPayload) => {
    const cleanPayload = JSON.parse(JSON.stringify(rawPayload));
    const contentHash = computeContentHash(cleanPayload);
    operations.push({
      collection,
      docId,
      data: {
        ...cleanPayload,
        content_hash: contentHash,
      },
    });
  };

  // 1. Metadata raíz (1 doc)
  pushDoc('curriculum_meta', catalogData.catalog_id, {
    catalog_id: catalogData.catalog_id,
    schema_version: catalogData.schema_version,
    status: catalogData.status,
    generated_at: catalogData.generated_at,
    pedagogical_decisions_applied: catalogData.pedagogical_decisions_applied,
    pending_technical_review_movement_ids: catalogData.pending_technical_review_movement_ids,
    source: catalogData.source,
    category_taxonomy: catalogData.category_taxonomy,
    adulto_cordas_index_summary: catalogData.tracks.adulto.cordas_index_summary,
    infantil_track_summary: {
      track_id: catalogData.tracks.infantil.track_id,
      display_name: catalogData.tracks.infantil.display_name,
      total_cordas: catalogData.tracks.infantil.total_cordas,
      age_rules: catalogData.tracks.infantil.age_rules,
      evaluation_dimensions: catalogData.tracks.infantil.evaluation_dimensions,
    },
    review_flags: catalogData.review_flags,
  });

  // 2. Movimientos canónicos únicos (97 docs)
  for (const mov of catalogData.movements) {
    pushDoc('curriculum_movements', mov.movement_id, mov);
  }

  // 3. Bloques compartidos (1 doc: adulto_bloque_05_06)
  for (const block of catalogData.curriculum_blocks) {
    pushDoc('curriculum_blocks', block.block_id, block);
  }

  // 4. Cordas Adulto extraídas (6 docs) + Cordas Infantil estructurales (12 docs)
  for (const corda of catalogData.cordas) {
    pushDoc('curriculum_cordas', corda.corda_id, {
      ...corda,
      content_status: 'extracted_v1',
    });
  }
  for (const inf of catalogData.tracks.infantil.cordas) {
    pushDoc('curriculum_cordas', inf.corda_id, {
      corda_id: inf.corda_id,
      track_id: 'infantil',
      index: inf.index,
      nombre_manual: inf.nombre_manual,
      nombre_app: inf.nombre_manual,
      nombre_treinamento: inf.nombre_treinamento,
      edad_referencia: inf.edad_referencia,
      shared_block_id: null,
      inherits_from_corda_ids: [],
      source_pages: {
        printed_pages: inf.printed_pages,
        pdf_pages: inf.pdf_pages,
      },
      content_status: 'structure_only_pending_extraction',
    });
  }

  // 5. Vínculos de tutoriales (21 docs)
  for (const tut of catalogData.tutorial_mapping) {
    pushDoc('curriculum_tutorial_links', tut.tutorial_doc_id, tut);
  }

  // 6. Cruce de glosario (26 docs)
  for (const entry of catalogData.glossary_crosswalk) {
    const slug = slugifyTerm(entry.termino_glosario);
    pushDoc('curriculum_glossary_links', slug, {
      glossary_id: slug,
      ...entry,
    });
  }

  // 7. Actualizaciones aditivas opcionales sobre /tutoriales (solo si --sync-tutorial-refs)
  const tutorialAdditiveRefs = catalogData.tutorial_mapping.map((tut) => ({
    collection: 'tutoriales',
    docId: tut.tutorial_doc_id,
    additiveFields: {
      movement_ids: tut.movement_ids,
      primary_movement_id: tut.primary_movement_id,
      pending_movement_ids: tut.pending_movement_ids || [],
      curriculum_corda_ids: tut.curriculum_corda_ids,
      curriculum_sync_version: catalogData.catalog_id,
    },
  }));

  return { operations, tutorialAdditiveRefs };
}

/**
 * Store en memoria para pruebas unitarias e integración sin red.
 */
function createInMemoryStore(initialCollections = {}) {
  const db = new Map();
  for (const [col, docs] of Object.entries(initialCollections)) {
    const colMap = new Map();
    for (const [id, data] of Object.entries(docs)) {
      colMap.set(id, JSON.parse(JSON.stringify(data)));
    }
    db.set(col, colMap);
  }

  const ensureCol = (col) => {
    if (!db.has(col)) db.set(col, new Map());
    return db.get(col);
  };

  return {
    type: 'in_memory',
    db,
    async getDoc(col, id) {
      const val = ensureCol(col).get(id);
      return val ? JSON.parse(JSON.stringify(val)) : null;
    },
    async setDoc(col, id, data) {
      ensureCol(col).set(id, JSON.parse(JSON.stringify(data)));
    },
    async mergeDocIfExists(col, id, partialData) {
      const colMap = ensureCol(col);
      if (!colMap.has(id)) return false;
      const current = colMap.get(id);
      colMap.set(id, {
        ...current,
        ...JSON.parse(JSON.stringify(partialData)),
      });
      return true;
    },
  };
}

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    return Number.isInteger(val)
      ? { integerValue: String(val) }
      : { doubleValue: val };
  }
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function fromFirestoreValue(v) {
  if (!v || typeof v !== 'object') return null;
  if ('nullValue' in v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('arrayValue' in v) {
    return ((v.arrayValue && v.arrayValue.values) || []).map(fromFirestoreValue);
  }
  if ('mapValue' in v) {
    return fromFirestoreFields((v.mapValue && v.mapValue.fields) || {});
  }
  return null;
}

function fromFirestoreFields(fields = {}) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) {
    out[k] = fromFirestoreValue(v);
  }
  return out;
}

function emulatorRequest(host, port, method, reqPath, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request({
      hostname: host,
      port: Number(port),
      path: reqPath,
      method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer owner',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
      },
    }, (res) => {
      let raw = '';
      res.on('data', (chunk) => { raw += chunk; });
      res.on('end', () => {
        let parsed = null;
        try { parsed = JSON.parse(raw); } catch (_) { parsed = raw; }
        resolve({ status: res.statusCode, body: parsed });
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

/**
 * Adaptador REST directo para Firebase Firestore Emulator (sin dependencia externa).
 */
function createEmulatorRestStore(emulatorHost, projectId = 'demo-ginga-test') {
  const [host, port] = emulatorHost.split(':');
  const base = `/v1/projects/${projectId}/databases/(default)/documents`;

  return {
    type: 'firestore_emulator_rest',
    async getDoc(col, id) {
      const res = await emulatorRequest(host, port, 'GET', `${base}/${col}/${id}`, null);
      if (res.status === 404) return null;
      if (res.status !== 200) {
        throw new Error(`GET ${col}/${id} falló (${res.status}): ${JSON.stringify(res.body)}`);
      }
      return fromFirestoreFields(res.body.fields || {});
    },
    async setDoc(col, id, data) {
      const fields = {};
      for (const [k, v] of Object.entries(data)) {
        fields[k] = toFirestoreValue(v);
      }
      const res = await emulatorRequest(host, port, 'PATCH', `${base}/${col}/${id}`, { fields });
      if (res.status !== 200) {
        throw new Error(`PATCH ${col}/${id} falló (${res.status}): ${JSON.stringify(res.body)}`);
      }
    },
    async mergeDocIfExists(col, id, partialData) {
      const existing = await this.getDoc(col, id);
      if (!existing) return false;
      const merged = { ...existing, ...partialData };
      await this.setDoc(col, id, merged);
      return true;
    },
  };
}

function arrayEquals(a, b) {
  return stableStringify(a) === stableStringify(b);
}

/**
 * Ejecuta la importación idempotente.
 * Por defecto dryRun=true (0 escrituras).
 */
async function runImport(catalogData, store, options = {}) {
  const {
    dryRun = true,
    syncTutorialRefs = false,
    allowLiveWrite = false,
    confirmProduction = false,
    emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '',
  } = options;

  // Guardia estricta anti-escritura accidental a producción
  if (!dryRun && store && store.type === 'firestore_admin' && !emulatorHost) {
    if (!allowLiveWrite || !confirmProduction) {
      throw new Error(
        'BLOQUEADO: Escritura en Firestore real rechazada. Se requiere --allow-live-write --confirm-production o usar FIRESTORE_EMULATOR_HOST.'
      );
    }
  }

  const { operations, tutorialAdditiveRefs } = buildImportPlan(catalogData);
  const summary = {
    dryRun,
    totalPlannedCurriculumDocs: operations.length,
    created: 0,
    updated: 0,
    skipped: 0,
    tutorialRefsUpdated: 0,
    tutorialRefsSkipped: 0,
    tutorialRefsMissing: 0,
    byCollection: {},
  };

  for (const op of operations) {
    summary.byCollection[op.collection] = (summary.byCollection[op.collection] || 0) + 1;

    const existing = store ? await store.getDoc(op.collection, op.docId) : null;
    if (!existing) {
      summary.created++;
      if (!dryRun && store) {
        await store.setDoc(op.collection, op.docId, op.data);
      }
    } else if (existing.content_hash === op.data.content_hash) {
      summary.skipped++;
    } else {
      summary.updated++;
      if (!dryRun && store) {
        await store.setDoc(op.collection, op.docId, op.data);
      }
    }
  }

  if (syncTutorialRefs) {
    for (const ref of tutorialAdditiveRefs) {
      const existing = store ? await store.getDoc(ref.collection, ref.docId) : null;
      if (!existing) {
        summary.tutorialRefsMissing++;
        continue;
      }
      const alreadySynced = Object.entries(ref.additiveFields).every(([k, v]) =>
        arrayEquals(existing[k], v)
      );
      if (alreadySynced) {
        summary.tutorialRefsSkipped++;
      } else {
        summary.tutorialRefsUpdated++;
        if (!dryRun && store) {
          await store.mergeDocIfExists(ref.collection, ref.docId, ref.additiveFields);
        }
      }
    }
  }

  return summary;
}

function parseArgs(argv) {
  const args = {
    apply: false,
    syncTutorialRefs: false,
    allowLiveWrite: false,
    confirmProduction: false,
    catalogPath: CATALOG_PATH,
    projectId: process.env.GCLOUD_PROJECT || 'demo-ginga-test',
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--apply') args.apply = true;
    else if (a === '--sync-tutorial-refs') args.syncTutorialRefs = true;
    else if (a === '--allow-live-write') args.allowLiveWrite = true;
    else if (a === '--confirm-production') args.confirmProduction = true;
    else if (a === '--catalog' && argv[i + 1]) args.catalogPath = path.resolve(argv[++i]);
    else if (a === '--project' && argv[i + 1]) args.projectId = argv[++i];
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const catalogData = JSON.parse(fs.readFileSync(args.catalogPath, 'utf8'));
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
  const dryRun = !args.apply;

  let store = null;
  if (!dryRun) {
    if (emulatorHost) {
      store = createEmulatorRestStore(emulatorHost, args.projectId);
    } else if (!args.allowLiveWrite || !args.confirmProduction) {
      console.error(
        'ERROR DE SEGURIDAD: --apply sin FIRESTORE_EMULATOR_HOST está bloqueado para proteger Firestore de producción.'
      );
      process.exit(1);
    } else {
      // Lazy load firebase-admin solo si el usuario autorizó explícitamente producción
      let admin;
      try {
        admin = require(path.resolve(__dirname, '../functions/node_modules/firebase-admin'));
      } catch (err) {
        console.error('No se encontró firebase-admin en functions/node_modules:', err.message);
        process.exit(1);
      }
      if (!admin.apps.length) {
        admin.initializeApp({ projectId: args.projectId });
      }
      const firestore = admin.firestore();
      store = {
        type: 'firestore_admin',
        async getDoc(col, id) {
          const snap = await firestore.collection(col).doc(id).get();
          return snap.exists ? snap.data() : null;
        },
        async setDoc(col, id, data) {
          await firestore.collection(col).doc(id).set(data);
        },
        async mergeDocIfExists(col, id, partialData) {
          const ref = firestore.collection(col).doc(id);
          const snap = await ref.get();
          if (!snap.exists) return false;
          await ref.set(partialData, { merge: true });
          return true;
        },
      };
    }
  } else if (emulatorHost) {
    store = createEmulatorRestStore(emulatorHost, args.projectId);
  }

  const result = await runImport(catalogData, store, {
    dryRun,
    syncTutorialRefs: args.syncTutorialRefs,
    allowLiveWrite: args.allowLiveWrite,
    confirmProduction: args.confirmProduction,
    emulatorHost,
  });

  console.log(dryRun ? '=== DRY-RUN CURRICULUM IMPORT ===' : '=== APPLY CURRICULUM IMPORT ===');
  console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Importador falló:', err.message);
    process.exit(1);
  });
}

module.exports = {
  buildImportPlan,
  runImport,
  createInMemoryStore,
  createEmulatorRestStore,
  computeContentHash,
  slugifyTerm,
};
