#!/usr/bin/env node
'use strict';

/**
 * Local isolated HTTP transport for GINGA Planner V2 (`PED-04C2-C`).
 * - Serves compiled Flutter Web preview assets with `Cache-Control: no-store` and disabled SW (`/flutter_service_worker.js` -> 404).
 * - Exposes `GET /api/planner-v2/health` and `POST /api/planner-v2/generate` invoking the real offline Node engine (`functions/planner_v2/index.js`).
 * - Real OpenAI provider stays DISABLED (`realProviderEnabled: false`).
 * - Zero Firestore writes, zero live credentials.
 * - Security guard: binding to non-loopback `--host` REQUIRES `--token <PIN>` (enforced on `/api/planner-v2/*` and preview access).
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const {
  generateClassPlanV2,
  loadVerifiedCatalog,
  InMemoryAtomicQuotaStore,
  PlannerV2Error,
} = require('../functions/planner_v2');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
  '.mp3': 'audio/mpeg',
  '.mp4': 'video/mp4',
};

function parseCliArgs(argv) {
  const args = {
    host: '127.0.0.1',
    port: 8097,
    staticDir: '',
    token: '',
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--host' && argv[i + 1]) args.host = argv[++i];
    else if (a === '--port' && argv[i + 1]) args.port = Number(argv[++i]);
    else if (a === '--static-dir' && argv[i + 1]) args.staticDir = path.resolve(argv[++i]);
    else if (a === '--token' && argv[i + 1]) args.token = argv[++i];
  }
  return args;
}

function isLoopbackHost(host) {
  const clean = String(host || '').trim().toLowerCase();
  return clean === '127.0.0.1' || clean === 'localhost' || clean === '::1';
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, X-Preview-Token',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  });
  res.end(payload);
}

function readJsonBody(req, maxBytes = 256 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        reject(new PlannerV2Error('INVALID_REQUEST', 'El payload excede el tamaño máximo permitido.', { httpStatus: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        const text = Buffer.concat(chunks).toString('utf8');
        resolve(text ? JSON.parse(text) : {});
      } catch (e) {
        reject(new PlannerV2Error('INVALID_REQUEST', `JSON inválido: ${e.message}`, { httpStatus: 400 }));
      }
    });
    req.on('error', (err) => reject(err));
  });
}

function buildEphemeralResourceRepo(previewCatalog) {
  const map = new Map();
  if (Array.isArray(previewCatalog)) {
    for (const r of previewCatalog) {
      const id = String(r?.resource_id || '').trim();
      if (!id) continue;
      map.set(id, {
        resourceId: id,
        ownerId: 'local_dev_simulated_instructor',
        shared: true,
        title: String(r.title || 'Recurso de Pizarra'),
        type: String(r.type || 'nota'),
        mediaKind: String(r.media_kind || r.type || 'nota'),
        category: String(r.category || 'General'),
        notes: String(r.notes || ''),
        url: r.has_external_video === true ? 'https://local-preview-video.invalid' : '',
      });
    }
  }
  return {
    async getResourcesByIds(ids) {
      const out = new Map();
      for (const id of ids) {
        if (map.has(id)) out.set(id, map.get(id));
      }
      return out;
    },
  };
}

function createPlannerV2LocalServer({
  staticDir = '',
  host = '127.0.0.1',
  token = '',
} = {}) {
  const nonLoopback = !isLoopbackHost(host);
  if (nonLoopback && (!token || token.trim().length < 4)) {
    throw new Error(
      'Seguridad LAN: para exponer en una IP de red local (--host != 127.0.0.1) debes especificar --token <PIN_MIN_4_CHARS>.'
    );
  }

  const catalog = loadVerifiedCatalog();
  const quotaStore = new InMemoryAtomicQuotaStore();

  return http.createServer(async (req, res) => {
    const parsedUrl = new URL(req.url || '/', `http://${req.headers.host || '127.0.0.1'}`);
    const pathname = decodeURIComponent(parsedUrl.pathname);

    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, X-Preview-Token',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      });
      res.end();
      return;
    }

    if (nonLoopback) {
      const headerToken = String(req.headers['x-preview-token'] || '').trim();
      const queryToken = String(parsedUrl.searchParams.get('token') || '').trim();
      if (headerToken !== token && queryToken !== token) {
        sendJson(res, 401, {
          status: 'error',
          error: {
            code: 'PREVIEW_TOKEN_REQUIRED',
            message: 'Acceso restringido a red local con token/PIN válido.',
          },
        });
        return;
      }
    }

    if (pathname === '/flutter_service_worker.js') {
      res.writeHead(404, { 'Cache-Control': 'no-store' });
      res.end('Service worker disabled in isolated preview.');
      return;
    }

    if (req.method === 'GET' && pathname === '/api/planner-v2/health') {
      sendJson(res, 200, {
        status: 'ok',
        mode: 'simulated_offline',
        real_provider_enabled: false,
        engine_version: 'planner_v2.1.0',
        catalog_sha256: catalog.sha256,
        catalog_movements_count: catalog.movementsCount,
        loopback_only: !nonLoopback,
      });
      return;
    }

    if (req.method === 'POST' && pathname === '/api/planner-v2/generate') {
      try {
        const body = await readJsonBody(req);
        const rawRequest = body.request || body;
        const previewCatalog = body.preview_resources_catalog || rawRequest.preview_resources_catalog || [];

        const cleanRequest = { ...rawRequest };
        delete cleanRequest.preview_resources_catalog;

        const resourceRepository = buildEphemeralResourceRepo(previewCatalog);

        const response = await generateClassPlanV2({
          request: cleanRequest,
          authContext: {},
          deps: {
            catalog,
            quotaStore,
            resourceRepository,
          },
          serverOverrides: {
            providerMode: 'simulated',
            realProviderEnabled: false,
            allowLocalDevSimulatedBypass: true,
          },
        });

        sendJson(res, 200, response);
      } catch (err) {
        if (err instanceof PlannerV2Error) {
          sendJson(res, err.httpStatus || 400, err.toSafeResponse());
        } else {
          sendJson(res, 500, {
            status: 'error',
            error: {
              code: 'INTERNAL_ERROR',
              message: err?.message || 'Error inesperado en el servidor local del motor V2.',
              retryable: true,
            },
          });
        }
      }
      return;
    }

    if (staticDir && fs.existsSync(staticDir)) {
      let filePath = path.join(staticDir, pathname === '/' ? 'index.html' : pathname);
      if (!filePath.startsWith(staticDir)) {
        res.writeHead(403);
        res.end('Forbidden');
        return;
      }
      if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
        filePath = path.join(staticDir, 'index.html');
      }
      const ext = path.extname(filePath).toLowerCase();
      res.writeHead(200, {
        'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
        'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
        Pragma: 'no-cache',
        Expires: '0',
      });
      fs.createReadStream(filePath).pipe(res);
      return;
    }

    res.writeHead(404);
    res.end('Not found');
  });
}

if (require.main === module) {
  const args = parseCliArgs(process.argv.slice(2));
  const server = createPlannerV2LocalServer(args);
  server.listen(args.port, args.host, () => {
    console.log(
      `GINGA Planner V2 Local Preview Server active at http://${args.host}:${args.port}/ (mode=simulated_offline, staticDir=${args.staticDir || 'API-only'})`
    );
  });
}

module.exports = {
  createPlannerV2LocalServer,
  parseCliArgs,
};
