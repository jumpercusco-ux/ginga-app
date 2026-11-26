'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { PlannerV2Error } = require('./errors');

const DATA_DIR = path.join(__dirname, 'data');
const DEFAULT_CATALOG_PATH = path.join(DATA_DIR, 'fiu_adulto_v1.json');
const DEFAULT_MANIFEST_PATH = path.join(DATA_DIR, 'fiu_adulto_v1.sha256.json');

let _cachedCatalog = null;

function loadVerifiedCatalog({
  catalogPath = DEFAULT_CATALOG_PATH,
  manifestPath = DEFAULT_MANIFEST_PATH,
  forceReload = false,
} = {}) {
  if (_cachedCatalog && !forceReload && catalogPath === DEFAULT_CATALOG_PATH) {
    return _cachedCatalog;
  }

  if (!fs.existsSync(catalogPath) || !fs.existsSync(manifestPath)) {
    throw new PlannerV2Error(
      'CATALOG_INTEGRITY_ERROR',
      'Falta el catálogo FIU empaquetado o su manifiesto SHA-256 en backend.',
      { httpStatus: 500 }
    );
  }

  const rawBuf = fs.readFileSync(catalogPath);
  const actualHash = crypto.createHash('sha256').update(rawBuf).digest('hex');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

  if (actualHash !== manifest.sha256) {
    throw new PlannerV2Error(
      'CATALOG_INTEGRITY_ERROR',
      'El hash SHA-256 del catálogo FIU empaquetado no coincide con el manifiesto verificado.',
      { httpStatus: 500, details: { expected: manifest.sha256, actual: actualHash } }
    );
  }

  const raw = JSON.parse(rawBuf.toString('utf8'));
  const movementsById = new Map();
  const eligibleMovements = [];
  const excludedIds = [];

  for (const mov of raw.movements || []) {
    movementsById.set(mov.movement_id, mov);
    if (mov.ai_planner_eligible === true && mov.review_status === 'approved' && mov.is_ambiguous === false) {
      eligibleMovements.push(mov);
    } else {
      excludedIds.push(mov.movement_id);
    }
  }

  const adultCordasSummary = raw.tracks?.adulto?.cordas_index_summary || [];
  const adultCordasExtracted = raw.cordas || [];
  const cordasById = new Map();
  const cordasByIndex = new Map();

  for (const c of adultCordasSummary) {
    cordasById.set(c.corda_id, c);
    cordasByIndex.set(c.index, c);
  }

  const loaded = {
    sha256: actualHash,
    catalogId: raw.catalog_id,
    schemaVersion: raw.schema_version,
    movementsCount: (raw.movements || []).length,
    eligibleCount: eligibleMovements.length,
    excludedIds,
    movementsById,
    eligibleMovements,
    cordasById,
    cordasByIndex,
    adultCordasExtracted,
    curriculumBlocks: raw.curriculum_blocks || [],
    infantilTrackMeta: raw.tracks?.infantil || {},
  };

  if (catalogPath === DEFAULT_CATALOG_PATH) {
    _cachedCatalog = loaded;
  }
  return loaded;
}

function getMovement(catalog, movementId) {
  return catalog.movementsById.get(String(movementId || '').trim()) || null;
}

function isEligibleAdultoMovement(catalog, movementId) {
  const mov = getMovement(catalog, movementId);
  if (!mov) return false;
  return mov.ai_planner_eligible === true && mov.review_status === 'approved' && mov.is_ambiguous === false;
}

function getCordaMeta(catalog, indexOrId) {
  if (typeof indexOrId === 'number') {
    return catalog.cordasByIndex.get(indexOrId) || null;
  }
  return catalog.cordasById.get(String(indexOrId || '').trim()) || null;
}

function getCompactCatalogSlice(catalog, targetCordaIndex = 2, maxItems = 24) {
  const boundedIndex = Math.max(1, Math.min(6, Number(targetCordaIndex) || 1));
  const allowedCordaIds = new Set();
  for (let i = 1; i <= boundedIndex; i++) {
    allowedCordaIds.add(`adulto_corda_0${i}`);
  }

  const preferred = [];
  const earlier = [];
  for (const mov of catalog.eligibleMovements) {
    if (!allowedCordaIds.has(mov.first_introduced_adulto)) continue;
    const item = {
      movement_id: mov.movement_id,
      canonical_name: mov.canonical_name,
      category_id: mov.category_id,
      entry_kind: mov.entry_kind,
      first_introduced_adulto: mov.first_introduced_adulto,
    };
    if (mov.first_introduced_adulto === `adulto_corda_0${boundedIndex}`) {
      preferred.push(item);
    } else {
      earlier.push(item);
    }
  }

  // Always include fundamental Ginga and core beginner safety/defense items first if space permits.
  const ordered = [...preferred, ...earlier];
  return ordered.slice(0, maxItems);
}

module.exports = {
  loadVerifiedCatalog,
  getMovement,
  isEligibleAdultoMovement,
  getCordaMeta,
  getCompactCatalogSlice,
};
