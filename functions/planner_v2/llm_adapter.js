'use strict';

const { PlannerV2Error } = require('./errors');
const { estimateCostUsd } = require('./config');
const {
  CLASS_PLAN_V2_JSON_SCHEMA,
  OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA,
  OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA,
  normalizeOpenAiWirePlan,
  normalizeOpenAiWireBlock,
} = require('./response_schema');

/**
 * Adapter for OpenAI Structured Outputs (`response_format: { type: 'json_schema', strict: true }`).
 * Strictly disabled in PED-04C2-B unless serverConfig.realProviderEnabled === true AND apiKey is provided.
 * Supports fetchImpl injection for deterministic timeout / truncation / HTTP rejection tests without network calls.
 */
class OpenAiStructuredProvider {
  constructor({ apiKey = '', fetchImpl = null } = {}) {
    this.apiKey = apiKey;
    this.fetchImpl = fetchImpl;
  }

  get name() {
    return 'openai';
  }

  get supportsBlockGeneration() {
    return true;
  }

  async generateStructured({
    promptBundle,
    schema,
    model,
    timeoutMs,
    maxOutputTokens,
    temperature = 0.45,
    serverConfig,
  }) {
    if (!serverConfig || serverConfig.realProviderEnabled !== true) {
      throw new PlannerV2Error(
        'REAL_PROVIDER_DISABLED',
        'El proveedor LLM real está deshabilitado por defecto. Usa el proveedor simulado offline o habilítalo explícitamente en servidor local.',
        { httpStatus: 503 }
      );
    }

    if (!this.apiKey || String(this.apiKey).trim().length === 0) {
      throw new PlannerV2Error(
        'REAL_PROVIDER_DISABLED',
        'Falta credencial de OpenAI en servidor para invocar el proveedor real.',
        { httpStatus: 503 }
      );
    }

    const fetchFn = this.fetchImpl || global.fetch;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    const wireSchema =
      schema === CLASS_PLAN_V2_JSON_SCHEMA
        ? OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA
        : schema;
    const isBlockSchema = wireSchema === OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA;
    const isCopilotSchema = wireSchema?.name === 'ginga_pedagogical_copilot_v1';

    const started = Date.now();
    try {
      const resp = await fetchFn('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        signal: controller.signal,
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          temperature,
          max_tokens: maxOutputTokens,
          response_format: {
            type: 'json_schema',
            json_schema: wireSchema,
          },
          messages: [
            { role: 'system', content: promptBundle.systemPrompt },
            { role: 'user', content: promptBundle.userPrompt },
          ],
        }),
      });

      if (!resp.ok) {
        let errMsg = `HTTP ${resp.status}`;
        let errCode = '';
        try {
          const errBody = await resp.json();
          errMsg = errBody?.error?.message || errMsg;
          errCode = String(errBody?.error?.code || '');
        } catch (_) {
          // ignore parse error
        }
        const isModelAccessDenied =
          resp.status === 403 ||
          resp.status === 404 ||
          errCode === 'model_not_found' ||
          /does not have access to model|model.*not.*found|unsupported.*model/i.test(errMsg);
        if (isModelAccessDenied) {
          throw new PlannerV2Error(
            'MODEL_ACCESS_DENIED',
            `El proyecto asociado a tu API Key no tiene acceso al modelo '${model}': ${errMsg}`,
            {
              httpStatus: resp.status,
              retryable: false,
              details: { status: resp.status, model, provider_error_code: errCode || null },
            }
          );
        }
        throw new PlannerV2Error('PROVIDER_REJECTED', `El proveedor LLM rechazó la solicitud: ${errMsg}`, {
          httpStatus: 502,
          retryable: resp.status >= 500 || resp.status === 429,
          details: { status: resp.status },
        });
      }

      const body = await resp.json();
      const choice = body?.choices?.[0];
      if (!choice) {
        throw new PlannerV2Error('PROVIDER_REJECTED', 'El proveedor LLM no devolvió ninguna opción.', {
          httpStatus: 502,
        });
      }

      if (choice.finish_reason === 'length') {
        throw new PlannerV2Error(
          'PROVIDER_TRUNCATED_OUTPUT',
          'La respuesta del proveedor LLM fue truncada por límite de tokens antes de completar el JSON.',
          { httpStatus: 502, retryable: true }
        );
      }

      if (choice.message?.refusal) {
        throw new PlannerV2Error(
          'PROVIDER_REJECTED',
          `El proveedor LLM rechazó generar el plan: ${choice.message.refusal}`,
          { httpStatus: 422 }
        );
      }

      let parsedPlan;
      try {
        const decoded = JSON.parse(choice.message?.content || '');
        parsedPlan = isCopilotSchema
          ? decoded
          : isBlockSchema
            ? normalizeOpenAiWireBlock(decoded)
            : normalizeOpenAiWirePlan(decoded);
      } catch (parseErr) {
        throw new PlannerV2Error(
          'PROVIDER_TRUNCATED_OUTPUT',
          `Respuesta JSON incompleta o malformada del proveedor: ${parseErr.message}`,
          { httpStatus: 502, retryable: true }
        );
      }

      const inputTokens = Number(body?.usage?.prompt_tokens || promptBundle.estimatedInputTokens || 0);
      const outputTokens = Number(body?.usage?.completion_tokens || 0);

      return {
        provider: 'openai',
        model,
        isSimulated: false,
        rawPlan: parsedPlan,
        usage: {
          inputTokens,
          outputTokens,
          estimatedCostUsd: estimateCostUsd(model, inputTokens, outputTokens),
          latencyMs: Date.now() - started,
        },
      };
    } catch (err) {
      if (err instanceof PlannerV2Error) throw err;
      if (err && (err.name === 'AbortError' || /abort|timeout/i.test(err.message || ''))) {
        throw new PlannerV2Error(
          'PROVIDER_TIMEOUT',
          `La llamada al proveedor LLM excedió el tiempo límite de ${timeoutMs} ms.`,
          { httpStatus: 504, retryable: true }
        );
      }
      throw new PlannerV2Error('PROVIDER_REJECTED', `Error comunicando con proveedor LLM: ${err.message}`, {
        httpStatus: 502,
        retryable: true,
      });
    } finally {
      clearTimeout(timer);
    }
  }
}

/**
 * Metadata-only probe (`GET /v1/models`, zero token cost) to discover which
 * candidate models are permitted for the configured server API key.
 */
async function listAccessibleOpenAiModels({
  apiKey = '',
  fetchImpl = null,
  timeoutMs = 8000,
  candidateModels = ['gpt-4o-mini', 'gpt-4.1-mini', 'gpt-4o'],
} = {}) {
  const cleanKey = String(apiKey || '').trim();
  if (!cleanKey) {
    return {
      checked: false,
      accessibleCandidates: [],
      allAccessibleCount: 0,
      recommendedPrimary: candidateModels[0] || 'gpt-4o-mini',
      recommendedFallback: '',
      error: 'MISSING_API_KEY',
    };
  }

  const fetchFn = fetchImpl || global.fetch;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetchFn('https://api.openai.com/v1/models', {
      method: 'GET',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${cleanKey}`,
      },
    });
    if (!resp.ok) {
      return {
        checked: false,
        accessibleCandidates: [],
        allAccessibleCount: 0,
        recommendedPrimary: candidateModels[0] || 'gpt-4o-mini',
        recommendedFallback: '',
        error: `HTTP_${resp.status}`,
      };
    }
    const body = await resp.json();
    const allIds = new Set(
      Array.isArray(body?.data) ? body.data.map((m) => String(m?.id || '').trim()).filter(Boolean) : []
    );
    const accessibleCandidates = candidateModels.filter((id) => allIds.has(id));
    return {
      checked: true,
      accessibleCandidates,
      allAccessibleCount: allIds.size,
      recommendedPrimary: accessibleCandidates[0] || candidateModels[0] || 'gpt-4o-mini',
      recommendedFallback: accessibleCandidates[1] || '',
      error: null,
    };
  } catch (err) {
    return {
      checked: false,
      accessibleCandidates: [],
      allAccessibleCount: 0,
      recommendedPrimary: candidateModels[0] || 'gpt-4o-mini',
      recommendedFallback: '',
      error: err?.message || 'PROBE_ERROR',
    };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = {
  OpenAiStructuredProvider,
  listAccessibleOpenAiModels,
};
