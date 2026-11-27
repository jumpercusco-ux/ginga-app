#!/usr/bin/env node
'use strict';

/**
 * scripts/migrate_auth_roles_and_claims.js
 *
 * Script idempotente (solo Firebase Emulator) para:
 *  1. Normalizar `users/{uid}.rol = 'administrador'` -> `'admin'` preservando todos los demás campos.
 *  2. Generar (y en Emulator Auth opcionalmente reportar) el mapa determinista de Custom Claims firmados
 *     para Auth (`admin`, `curriculum_admin`, `profesor`, `instructor`, `rol`), evitando confiar en cambios del cliente.
 *
 * Bloqueado fuera de `FIRESTORE_EMULATOR_HOST` y rechaza `capoeirafiu-ea8ljo`.
 *
 * Uso:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/migrate_auth_roles_and_claims.js --dry-run
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/migrate_auth_roles_and_claims.js --apply
 */

const http = require('http');

function parseArgs(argv) {
  const args = {
    apply: false,
    dryRun: true,
    projectId: process.env.GCLOUD_PROJECT || 'demo-ginga-test',
  };
  for (const raw of argv) {
    if (raw === '--apply') {
      args.apply = true;
      args.dryRun = false;
    } else if (raw === '--dry-run') {
      args.apply = false;
      args.dryRun = true;
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
      'BLOQUEADO: FIRESTORE_EMULATOR_HOST no está definido. Prohibido ejecutar migración fuera de Emulador.'
    );
  }
  if (projectId === 'capoeirafiu-ea8ljo') {
    throw new Error(
      'BLOQUEADO: el proyecto productivo capoeirafiu-ea8ljo está prohibido en este script.'
    );
  }
  const [hostname, portStr] = host.split(':');
  return { hostname, port: Number(portStr || 8080) };
}

function requestEmulator(endpoint, method, path, body = null) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request(
      {
        hostname: endpoint.hostname,
        port: endpoint.port,
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

function normalizeRoleValue(raw) {
  const norm = String(raw || '').trim().toLowerCase();
  if (norm === 'administrador' || norm === 'admin') return 'admin';
  if (norm === 'profesor' || norm === 'instructor' || norm === 'teacher') return 'profesor';
  if (!norm) return 'alumno';
  return norm;
}

function buildExpectedCustomClaims(normalizedRole) {
  switch (normalizedRole) {
    case 'admin':
      return {
        admin: true,
        curriculum_admin: true,
        profesor: true,
        instructor: true,
        rol: 'admin',
      };
    case 'profesor':
      return {
        admin: false,
        curriculum_admin: false,
        profesor: true,
        instructor: true,
        rol: 'profesor',
      };
    default:
      return {
        admin: false,
        curriculum_admin: false,
        profesor: false,
        instructor: false,
        rol: 'alumno',
      };
  }
}

async function runRoleAndClaimsMigration(options = {}) {
  const args = {
    apply: options.apply === true,
    dryRun: options.apply !== true,
    projectId: options.projectId || process.env.GCLOUD_PROJECT || 'demo-ginga-test',
  };
  const endpoint = assertEmulatorOnly(args.projectId);
  const nowIso = new Date().toISOString();

  const users = [];
  let pageToken = '';
  do {
    const tokenQ = pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : '';
    const res = await requestEmulator(
      endpoint,
      'GET',
      `/v1/projects/${args.projectId}/databases/(default)/documents/users?pageSize=200${tokenQ}`
    );
    if (res.status >= 400) {
      throw new Error(`Error listando /users: HTTP ${res.status} ${JSON.stringify(res.body)}`);
    }
    const items = Array.isArray(res.body?.documents) ? res.body.documents : [];
    users.push(...items);
    pageToken = res.body?.nextPageToken || '';
  } while (pageToken);

  const summary = {
    mode: args.apply ? 'apply' : 'dry-run',
    projectId: args.projectId,
    usersScanned: users.length,
    rolesToNormalize: 0,
    rolesNormalized: 0,
    claimsPlan: [],
  };

  for (const doc of users) {
    const uid = String(doc.name || '').split('/').pop();
    const fields = doc.fields || {};
    const rawRol = fields.rol?.stringValue || '';
    const normalizedRol = normalizeRoleValue(rawRol);
    const claims = buildExpectedCustomClaims(normalizedRol);

    summary.claimsPlan.push({
      uid,
      previousRole: rawRol || null,
      normalizedRole: normalizedRol,
      claims,
    });

    if (rawRol !== normalizedRol) {
      summary.rolesToNormalize += 1;
      if (args.apply) {
        const patchRes = await requestEmulator(
          endpoint,
          'PATCH',
          `/v1/${doc.name}?updateMask.fieldPaths=rol&updateMask.fieldPaths=role_normalized_at`,
          {
            fields: {
              rol: { stringValue: normalizedRol },
              role_normalized_at: { stringValue: nowIso },
            },
          }
        );
        if (patchRes.status >= 400) {
          throw new Error(
            `Error normalizando rol de ${uid}: HTTP ${patchRes.status} ${JSON.stringify(patchRes.body)}`
          );
        }
        summary.rolesNormalized += 1;
      }
    }
  }

  return summary;
}

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));
  runRoleAndClaimsMigration(args)
    .then((summary) => {
      console.log(JSON.stringify(summary, null, 2));
    })
    .catch((err) => {
      console.error(err?.message || err);
      process.exit(1);
    });
}

module.exports = {
  runRoleAndClaimsMigration,
  normalizeRoleValue,
  buildExpectedCustomClaims,
  parseArgs,
};
