'use strict';

const MODEL_PRICING_USD_PER_1M = Object.freeze({
  'gpt-4.1-mini': Object.freeze({ input: 0.40, output: 1.60 }),
  'gpt-4o-mini': Object.freeze({ input: 0.15, output: 0.60 }),
  'gpt-4o': Object.freeze({ input: 2.50, output: 10.00 }),
  'simulated-planner-v2': Object.freeze({ input: 0, output: 0 }),
});

/**
 * Resolves authoritative server configuration for Planner V2.
 * Client payloads can NEVER override provider, model, budget, quota, repair count, or auth bypass.
 * Server-side overrides are allowed strictly for isolated harnesses/tests.
 */
function getServerConfig(serverOverrides = {}) {
  const isCloudFunctionRuntime = Boolean(
    process.env.FUNCTION_TARGET || process.env.K_SERVICE || process.env.FUNCTIONS_EMULATOR === 'false'
  );
  const isProductionEnv = process.env.NODE_ENV === 'production' || isCloudFunctionRuntime;

  const allowLocalDevSimulatedBypass =
    !isProductionEnv && serverOverrides.allowLocalDevSimulatedBypass === true;

  const overridePrimary =
    typeof serverOverrides.primaryModel === 'string' && serverOverrides.primaryModel.trim()
      ? serverOverrides.primaryModel.trim()
      : '';
  const overrideFallback =
    typeof serverOverrides.fallbackModel === 'string'
      ? serverOverrides.fallbackModel.trim()
      : null;

  return Object.freeze({
    engineVersion: 'planner_v2.1.0',
    contractVersion: '2.1.0',
    primaryModel: overridePrimary || process.env.PLANNER_V2_MODEL || 'gpt-4o-mini',
    fallbackModel:
      overrideFallback !== null
        ? overrideFallback
        : (process.env.PLANNER_V2_FALLBACK_MODEL || 'gpt-4.1-mini'),
    // Real LLM provider stays strictly disabled in PED-04C2-B unless explicitly enabled on server in PED-04C2-D.
    realProviderEnabled: serverOverrides.realProviderEnabled === true && !isProductionEnv ? true : false,
    providerMode: serverOverrides.providerMode === 'openai' ? 'openai' : 'simulated',
    allowLocalDevSimulatedBypass,
    isProductionEnv,
    quota: Object.freeze({
      dailyLimit: Number.isInteger(serverOverrides.dailyLimit) ? serverOverrides.dailyLimit : 20,
      perMinuteLimit: Number.isInteger(serverOverrides.perMinuteLimit) ? serverOverrides.perMinuteLimit : 4,
    }),
    budget: Object.freeze({
      maxOutputTokensDefault: 4500,
      maxOutputTokensExtended: 5600,
      maxOutputTokens: Number.isInteger(serverOverrides.maxOutputTokens) ? serverOverrides.maxOutputTokens : 4500,
      primaryTimeoutMs: Number.isInteger(serverOverrides.primaryTimeoutMs) ? serverOverrides.primaryTimeoutMs : 55000,
      repairTimeoutMs: Number.isInteger(serverOverrides.repairTimeoutMs) ? serverOverrides.repairTimeoutMs : 35000,
      maxRepairAttempts: 1,
      blockMaxOutputTokens: Number.isInteger(serverOverrides.blockMaxOutputTokens)
        ? serverOverrides.blockMaxOutputTokens
        : 1600,
      blockTimeoutMs: Number.isInteger(serverOverrides.blockTimeoutMs) ? serverOverrides.blockTimeoutMs : 30000,
      blockRepairTimeoutMs: Number.isInteger(serverOverrides.blockRepairTimeoutMs)
        ? serverOverrides.blockRepairTimeoutMs
        : 30000,
      blockConcurrency: Number.isInteger(serverOverrides.blockConcurrency) ? serverOverrides.blockConcurrency : 2,
    }),
  });
}

function resolveMaxOutputTokens(durationMin, serverConfig) {
  if (serverConfig?.budget?.maxOutputTokens && serverConfig.budget.maxOutputTokens !== 4500) {
    return serverConfig.budget.maxOutputTokens;
  }
  return Number(durationMin || 60) > 60 ? 5600 : 4500;
}

function estimateCostUsd(model, inputTokens, outputTokens) {
  const pricing = MODEL_PRICING_USD_PER_1M[model] || MODEL_PRICING_USD_PER_1M['gpt-4o-mini'];
  const inCost = ((inputTokens || 0) / 1000000) * pricing.input;
  const outCost = ((outputTokens || 0) / 1000000) * pricing.output;
  return Number((inCost + outCost).toFixed(6));
}

function estimateTokensFromText(text) {
  const s = String(text || '');
  if (!s) return 0;
  // Conservative Spanish/JSON token estimate (~3.5 chars/token)
  return Math.ceil(s.length / 3.5);
}

function resolveServerOpenAiApiKey() {
  return String(
    process.env.PLANNER_V2_OPENAI_API_KEY || process.env.OPENAI_API_KEY || ''
  ).trim();
}

function hasServerOpenAiCredentials() {
  return resolveServerOpenAiApiKey().length > 0;
}

module.exports = {
  MODEL_PRICING_USD_PER_1M,
  getServerConfig,
  resolveMaxOutputTokens,
  estimateCostUsd,
  estimateTokensFromText,
  resolveServerOpenAiApiKey,
  hasServerOpenAiCredentials,
};
