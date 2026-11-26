'use strict';

const { PlannerV2Error } = require('./errors');
const { estimateCostUsd } = require('./config');

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
        'El proveedor LLM real está deshabilitado en PED-04C2-B. Usa el proveedor simulado offline.',
        { httpStatus: 503 }
      );
    }

    if (!this.apiKey) {
      throw new PlannerV2Error(
        'REAL_PROVIDER_DISABLED',
        'Falta credencial OPENAI_API_KEY en el servidor para invocar el proveedor real.',
        { httpStatus: 503 }
      );
    }

    const fetchFn = this.fetchImpl || global.fetch;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

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
            json_schema: schema,
          },
          messages: [
            { role: 'system', content: promptBundle.systemPrompt },
            { role: 'user', content: promptBundle.userPrompt },
          ],
        }),
      });

      if (!resp.ok) {
        let errMsg = `HTTP ${resp.status}`;
        try {
          const errBody = await resp.json();
          errMsg = errBody?.error?.message || errMsg;
        } catch (_) {
          // ignore parse error
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
        parsedPlan = JSON.parse(choice.message?.content || '');
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

module.exports = {
  OpenAiStructuredProvider,
};
