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
const os = require('os');
const { execFileSync } = require('child_process');
const { URL } = require('url');
const {
  generateClassPlanV2,
  runPedagogicalCopilotV1,
  getServerConfig,
  resolveServerOpenAiApiKey,
  hasServerOpenAiCredentials,
  loadVerifiedCatalog,
  listAccessibleOpenAiModels,
  InMemoryAtomicQuotaStore,
  AtomicPilotBudgetGuard,
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
    enableRealOpenAi: process.env.PLANNER_V2_ENABLE_REAL_OPENAI === 'true',
    enableRealCopilotOpenAi: false,
    maxBudgetUsd: 0.10,
    maxRealGenerations: 4,
    copilotBudgetUsd: 0.05,
    copilotMaxGenerations: 6,
    model: '',
    fallbackModel: '',
    budgetStateFile: '',
    copilotBudgetStateFile: '',
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--host' && argv[i + 1]) args.host = argv[++i];
    else if (a === '--port' && argv[i + 1]) args.port = Number(argv[++i]);
    else if ((a === '--static-dir' || a === '--web-dir') && argv[i + 1]) args.staticDir = path.resolve(argv[++i]);
    else if (a === '--token' && argv[i + 1]) args.token = argv[++i];
    else if (a === '--enable-real-openai') args.enableRealOpenAi = true;
    else if (a === '--enable-real-copilot-openai') args.enableRealCopilotOpenAi = true;
    else if (a === '--budget-usd' && argv[i + 1]) args.maxBudgetUsd = Number(argv[++i]);
    else if (a === '--max-real-generations' && argv[i + 1]) args.maxRealGenerations = Number(argv[++i]);
    else if (a === '--copilot-budget-usd' && argv[i + 1]) args.copilotBudgetUsd = Number(argv[++i]);
    else if (a === '--copilot-max-generations' && argv[i + 1]) args.copilotMaxGenerations = Number(argv[++i]);
    else if (a === '--model' && argv[i + 1]) args.model = argv[++i];
    else if (a === '--fallback-model' && argv[i + 1]) args.fallbackModel = argv[++i];
    else if (a === '--budget-state-file' && argv[i + 1]) args.budgetStateFile = path.resolve(argv[++i]);
    else if (a === '--copilot-budget-state-file' && argv[i + 1]) args.copilotBudgetStateFile = path.resolve(argv[++i]);
  }
  return args;
}

function isLoopbackHost(host) {
  const clean = String(host || '').trim().toLowerCase();
  return clean === '127.0.0.1' || clean === 'localhost' || clean === '::1';
}

function hydrateOpenAiKeyFromMacKeychainIfNeeded() {
  if (hasServerOpenAiCredentials()) return true;
  if (process.platform !== 'darwin' || process.env.PLANNER_V2_DISABLE_KEYCHAIN === '1') {
    return false;
  }
  try {
    const account = os.userInfo().username;
    const key = execFileSync(
      'security',
      ['find-generic-password', '-a', account, '-s', 'ginga-dev-openai-api-key', '-w'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }
    ).trim();
    if (key) {
      process.env.OPENAI_API_KEY = key;
      return true;
    }
  } catch (_) {
    // Keychain item absent or inaccessible
  }
  return false;
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
  enableRealOpenAi = false,
  enableRealCopilotOpenAi = false,
  maxBudgetUsd = 0.10,
  maxRealGenerations = 4,
  copilotBudgetUsd = 0.05,
  copilotMaxGenerations = 6,
  model = '',
  fallbackModel = '',
  budgetStateFile = '',
  copilotBudgetStateFile = '',
} = {}) {
  const nonLoopback = !isLoopbackHost(host);
  if (nonLoopback && (!token || token.trim().length < 4)) {
    throw new Error(
      'Seguridad LAN: para exponer en una IP de red local (--host != 127.0.0.1) debes especificar --token <PIN_MIN_4_CHARS>.'
    );
  }

  if (enableRealOpenAi === true || enableRealCopilotOpenAi === true) {
    hydrateOpenAiKeyFromMacKeychainIfNeeded();
  }
  const credentialsPresent = hasServerOpenAiCredentials();
  if ((enableRealOpenAi === true || enableRealCopilotOpenAi === true) && !credentialsPresent) {
    throw new Error(
      'Faltan credenciales de OpenAI en memoria o macOS Keychain (ginga-dev-openai-api-key). Ejecuta ./scripts/setup_local_openai_keychain.sh para iniciar con proveedor real.'
    );
  }

  const effectiveReal = enableRealOpenAi === true && credentialsPresent;
  const effectiveCopilotReal = enableRealCopilotOpenAi === true && credentialsPresent;
  const safeBudgetUsd = Math.min(0.10, Math.max(0.01, Number(maxBudgetUsd || 0.10)));
  const safeMaxGens = Math.max(1, Math.min(12, Number(maxRealGenerations || 4)));
  const resolvedBudgetStateFile =
    budgetStateFile ||
    (effectiveReal ? path.join(__dirname, '..', 'scratch', 'pilot_ped04c2d_budget_state.json') : '');
  const resolvedCopilotBudgetStateFile =
    copilotBudgetStateFile ||
    (effectiveCopilotReal ? path.join(__dirname, '..', 'scratch', 'copilot_ped04c3_budget_state.json') : '');

  const baseConfig = getServerConfig({
    primaryModel: model || undefined,
    fallbackModel: fallbackModel || undefined,
  });
  const catalog = loadVerifiedCatalog();
  const quotaStore = new InMemoryAtomicQuotaStore();
  const copilotQuotaStore = new InMemoryAtomicQuotaStore();
  const budgetGuard = new AtomicPilotBudgetGuard({
    maxBudgetUsd: safeBudgetUsd,
    maxGenerations: safeMaxGens,
    stateFilePath: resolvedBudgetStateFile,
  });
  const copilotBudgetGuard = new AtomicPilotBudgetGuard({
    maxBudgetUsd: Math.min(0.10, Math.max(0.01, Number(copilotBudgetUsd || 0.05))),
    maxGenerations: Math.max(1, Math.min(12, Number(copilotMaxGenerations || 6))),
    stateFilePath: resolvedCopilotBudgetStateFile,
  });
  const runtimeModelState = {
    primaryModel: baseConfig.primaryModel,
    fallbackModel: baseConfig.fallbackModel,
    accessibleModels: [],
    modelProbeChecked: false,
    modelProbeError: null,
  };
  let generationProgress = {
    status: 'idle',
    stage: 'idle',
    completed_blocks: 0,
    total_blocks: 0,
    current_block_ids: [],
    updated_at: new Date().toISOString(),
  };
  const lastCompletedClassFile = effectiveReal
    ? path.join(__dirname, '..', 'scratch', 'last_completed_planner_v2_class.json')
    : '';
  let lastCompletedResult = null;
  if (lastCompletedClassFile && fs.existsSync(lastCompletedClassFile)) {
    try {
      const parsedLast = JSON.parse(fs.readFileSync(lastCompletedClassFile, 'utf8'));
      if (parsedLast && parsedLast.status === 'ok' && parsedLast.plan) {
        lastCompletedResult = parsedLast;
      }
    } catch (_) {
      // ignore corrupt optional recovery file
    }
  }
  let lastErrorSummary = null;

  async function probeOpenAiModels(fetchImpl = null) {
    if (!effectiveReal && !effectiveCopilotReal) return runtimeModelState;
    const probe = await listAccessibleOpenAiModels({
      apiKey: resolveServerOpenAiApiKey(),
      fetchImpl,
    });
    runtimeModelState.modelProbeChecked = probe.checked;
    runtimeModelState.modelProbeError = probe.error;
    runtimeModelState.accessibleModels = probe.accessibleCandidates;
    if (!model && probe.checked && probe.accessibleCandidates.length > 0) {
      runtimeModelState.primaryModel = probe.recommendedPrimary;
      runtimeModelState.fallbackModel = probe.recommendedFallback;
    }
    return runtimeModelState;
  }

  const server = http.createServer(async (req, res) => {
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
        mode: effectiveReal ? 'openai_real_local_dev' : 'simulated_offline',
        real_provider_enabled: effectiveReal,
        real_provider_credentials_present: hasServerOpenAiCredentials(),
        primary_model: runtimeModelState.primaryModel,
        fallback_model: runtimeModelState.fallbackModel,
        accessible_models: runtimeModelState.accessibleModels,
        model_probe_checked: runtimeModelState.modelProbeChecked,
        model_probe_error: runtimeModelState.modelProbeError,
        engine_version: baseConfig.engineVersion,
        catalog_sha256: catalog.sha256,
        catalog_movements_count: catalog.movementsCount,
        loopback_only: !nonLoopback,
        pilot_budget: budgetGuard.getSnapshot(),
        copilot_budget: copilotBudgetGuard.getSnapshot(),
        copilot_real_provider_enabled: effectiveCopilotReal,
        generation_progress: generationProgress,
      });
      return;
    }

    if (req.method === 'GET' && pathname === '/api/planner-v2/copilot/last-session') {
      const sessionPath = path.join(__dirname, '..', 'scratch', 'copilot_ped04c3_last_session.json');
      let sessionData = null;
      if (fs.existsSync(sessionPath)) {
        try {
          sessionData = JSON.parse(fs.readFileSync(sessionPath, 'utf8'));
        } catch (_) {
          sessionData = null;
        }
      }
      sendJson(res, 200, {
        status: 'ok',
        has_session: Boolean(sessionData && Array.isArray(sessionData.turns) && sessionData.turns.length > 0),
        session: sessionData,
      });
      return;
    }

    if (req.method === 'POST' && pathname === '/api/planner-v2/copilot') {
      try {
        const body = await readJsonBody(req);
        const forceSimulated = body.force_simulated === true || !effectiveCopilotReal;
        const previewCatalog = body.preview_resources_catalog || body.available_resources || [];
        const resourceRepository = buildEphemeralResourceRepo(previewCatalog);
        const response = await runPedagogicalCopilotV1({
          request: {
            ...body,
            available_resources: previewCatalog,
          },
          authContext: {},
          deps: {
            catalog,
            quotaStore: copilotQuotaStore,
            budgetGuard: !forceSimulated ? copilotBudgetGuard : null,
            resourceRepository,
          },
          serverOverrides: {
            providerMode: !forceSimulated ? 'openai' : 'simulated',
            realProviderEnabled: !forceSimulated,
            allowLocalDevSimulatedBypass: true,
            primaryModel: runtimeModelState.primaryModel,
            fallbackModel: runtimeModelState.fallbackModel,
          },
        });
        const gm = response.generation_meta || {};
        const ct = response.cost_telemetry || {};
        const cb = ct.copilot_budget || copilotBudgetGuard.getSnapshot();
        console.log(
          `[copilot-v1] provider=${gm.provider || 'unknown'} model=${gm.model || 'unknown'} op_mode=${response.mode} latency=${ct.latency_ms ?? 0}ms tokens=${ct.input_tokens ?? 0}/${ct.output_tokens ?? 0} cost=$${Number(ct.estimated_cost_usd ?? 0).toFixed(6)} spent=$${Number(cb.spent_usd ?? 0).toFixed(6)}/$${Number(cb.max_budget_usd ?? 0.05).toFixed(2)} turns=${cb.completed_generations ?? 0}/${cb.max_generations ?? 6}`
        );
        sendJson(res, 200, response);
      } catch (err) {
        const cb = copilotBudgetGuard.getSnapshot();
        console.error(
          `[copilot-v1] ERROR code=${err?.code || 'INTERNAL_ERROR'} http=${err?.httpStatus || 500} msg=${err?.message || ''} spent=$${Number(cb.spent_usd ?? 0).toFixed(6)}/$${Number(cb.max_budget_usd ?? 0.05).toFixed(2)} turns=${cb.completed_generations ?? 0}/${cb.max_generations ?? 6}`
        );
        if (err instanceof PlannerV2Error) {
          sendJson(res, err.httpStatus || 400, err.toSafeResponse());
        } else {
          sendJson(res, 500, {
            status: 'error',
            error: {
              code: 'INTERNAL_ERROR',
              message: err?.message || 'Error inesperado en Copiloto GINGA.',
              retryable: true,
            },
          });
        }
      }
      return;
    }

    if (req.method === 'GET' && pathname === '/api/planner-v2/last-status') {
      sendJson(res, 200, {
        status: 'ok',
        pilot_budget: budgetGuard.getSnapshot(),
        generation_progress: generationProgress,
        has_last_completed_result: Boolean(lastCompletedResult),
        last_completed_result: lastCompletedResult,
        last_error_summary: lastErrorSummary,
      });
      return;
    }

    if (req.method === 'POST' && pathname === '/api/planner-v2/generate') {
      try {
        const body = await readJsonBody(req);
        const forceSimulated = body.force_simulated === true;
        const rawRequest = body.request || body;
        const previewCatalog = body.preview_resources_catalog || rawRequest.preview_resources_catalog || [];

        const cleanRequest = { ...rawRequest };
        delete cleanRequest.preview_resources_catalog;
        delete cleanRequest.force_simulated;

        const resourceRepository = buildEphemeralResourceRepo(previewCatalog);
        const useRealForCall = effectiveReal && !forceSimulated;
        generationProgress = {
          status: 'running',
          stage: 'preparing',
          completed_blocks: 0,
          total_blocks: 0,
          current_block_ids: [],
          updated_at: new Date().toISOString(),
        };

        const response = await generateClassPlanV2({
          request: cleanRequest,
          authContext: {},
          deps: {
            catalog,
            quotaStore,
            budgetGuard: useRealForCall ? budgetGuard : null,
            resourceRepository,
            onProgress: (ev) => {
              generationProgress = ev;
            },
          },
          serverOverrides: {
            providerMode: useRealForCall ? 'openai' : 'simulated',
            realProviderEnabled: useRealForCall,
            allowLocalDevSimulatedBypass: true,
            primaryModel: runtimeModelState.primaryModel,
            fallbackModel: runtimeModelState.fallbackModel,
          },
        });

        generationProgress = {
          status: 'completed',
          stage: 'completed',
          completed_blocks: response.plan?.bloques?.length || 0,
          total_blocks: response.plan?.bloques?.length || 0,
          current_block_ids: [],
          updated_at: new Date().toISOString(),
        };
        lastCompletedResult = response;
        lastErrorSummary = null;
        if (useRealForCall && lastCompletedClassFile) {
          try {
            fs.mkdirSync(path.dirname(lastCompletedClassFile), { recursive: true });
            fs.writeFileSync(lastCompletedClassFile, JSON.stringify(response, null, 2));
          } catch (_) {
            // ignore optional recovery file write error
          }
        }

        const gm = response.generation_meta || {};
        const ct = response.cost_telemetry || {};
        const pb = ct.pilot_budget || budgetGuard.getSnapshot();
        console.log(
          `[planner-v2] mode=${gm.provider || 'unknown'} strategy=${gm.generation_strategy || 'monolithic'} model=${gm.model || 'unknown'} repairs=${gm.repair_attempts_used ?? 0} calls=${ct.calls_made ?? 1} tokens=${ct.input_tokens ?? 0}/${ct.output_tokens ?? 0} cost=$${Number(ct.estimated_cost_usd ?? 0).toFixed(4)} spent=$${Number(pb.spent_usd ?? 0).toFixed(4)}/$${Number(pb.max_budget_usd ?? 0.1).toFixed(2)} gens=${pb.completed_generations ?? 0}/${pb.max_generations ?? 4}`
        );

        sendJson(res, 200, response);
      } catch (err) {
        const pb = budgetGuard.getSnapshot();
        const ruleCodes = Array.isArray(err?.details?.errors)
          ? err.details.errors.map((e) => e.code).join(',')
          : '';
        generationProgress = {
          status: 'error',
          stage: err?.code || 'INTERNAL_ERROR',
          completed_blocks: generationProgress.completed_blocks || 0,
          total_blocks: generationProgress.total_blocks || 0,
          current_block_ids: [],
          updated_at: new Date().toISOString(),
        };
        lastErrorSummary = {
          timestamp: new Date().toISOString(),
          code: err?.code || 'INTERNAL_ERROR',
          message: err?.message || '',
          repair_attempts_used: err?.details?.repair_attempts_used ?? 0,
          validation_errors: Array.isArray(err?.details?.errors) ? err.details.errors : [],
        };
        console.error(
          `[planner-v2] ERROR code=${err?.code || 'INTERNAL_ERROR'} repairs=${err?.details?.repair_attempts_used ?? 0}${ruleCodes ? ` rules=[${ruleCodes}]` : ''} spent=$${Number(pb.spent_usd ?? 0).toFixed(4)}/$${Number(pb.max_budget_usd ?? 0.1).toFixed(2)} gens=${pb.completed_generations ?? 0}/${pb.max_generations ?? 4} calls=${pb.total_llm_calls ?? 0}`
        );
        if (effectiveReal) {
          try {
            const diagPath = path.join(__dirname, '..', 'scratch', 'last_planner_v2_failure.json');
            const diagDir = path.dirname(diagPath);
            if (!fs.existsSync(diagDir)) fs.mkdirSync(diagDir, { recursive: true });
            fs.writeFileSync(
              diagPath,
              JSON.stringify(
                {
                  timestamp: new Date().toISOString(),
                  code: err?.code || 'INTERNAL_ERROR',
                  message: err?.message || '',
                  repair_attempts_used: err?.details?.repair_attempts_used ?? 0,
                  validation_errors: Array.isArray(err?.details?.errors) ? err.details.errors : [],
                  initial_summary: err?.details?.initial_summary || null,
                  repaired_summary: err?.details?.repaired_summary || null,
                  deterministic_fixes_applied: err?.details?.deterministic_fixes_applied || [],
                  pilot_budget: pb,
                },
                null,
                2
              )
            );
          } catch (_) {
            // ignore diagnostic write error
          }
        }

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

  server.plannerV2Meta = {
    effectiveReal,
    effectiveCopilotReal,
    budgetGuard,
    copilotBudgetGuard,
    runtimeModelState,
    probeOpenAiModels,
  };
  return server;
}

if (require.main === module) {
  (async () => {
    const args = parseCliArgs(process.argv.slice(2));
    const server = createPlannerV2LocalServer(args);
    const modeLabel = server.plannerV2Meta.effectiveCopilotReal
      ? 'copilot_openai_real_local_dev'
      : server.plannerV2Meta.effectiveReal
        ? 'openai_real_local_dev'
        : 'simulated_offline';
    if (server.plannerV2Meta.effectiveReal || server.plannerV2Meta.effectiveCopilotReal) {
      const state = await server.plannerV2Meta.probeOpenAiModels();
      const pb = server.plannerV2Meta.budgetGuard.getSnapshot();
      const cb = server.plannerV2Meta.copilotBudgetGuard.getSnapshot();
      const availStr =
        state.accessibleModels.length > 0
          ? state.accessibleModels.join(', ')
          : `prioridad por defecto (probe=${state.modelProbeError || 'omitido'})`;
      console.log(
        `[planner-v2] Modelos: ${availStr} | Activo: ${state.primaryModel} | Piloto generador (intacto): $${pb.spent_usd.toFixed(6)}/$${pb.max_budget_usd.toFixed(2)} (${pb.completed_generations}/${pb.max_generations}) | Copiloto: $${cb.spent_usd.toFixed(6)}/$${cb.max_budget_usd.toFixed(2)} (${cb.completed_generations}/${cb.max_generations})`
      );
    }
    server.listen(args.port, args.host, () => {
      const tokenHint = !isLoopbackHost(args.host) && args.token ? `/?token=${args.token}` : '/';
      console.log(
        `GINGA Planner V2 Local Preview Server active at http://${args.host}:${args.port}${tokenHint} (mode=${modeLabel}, model=${server.plannerV2Meta.runtimeModelState.primaryModel}, staticDir=${args.staticDir || 'API-only'}, copilotBudgetUsd=${server.plannerV2Meta.copilotBudgetGuard.maxBudgetUsd})`
      );
    });
  })().catch((err) => {
    console.error('[planner-v2] Error al iniciar servidor local:', err.message);
    process.exitCode = 1;
  });
}

module.exports = {
  createPlannerV2LocalServer,
  parseCliArgs,
};
