'use strict';

const crypto = require('crypto');
const { PlannerV2Error } = require('./errors');

/**
 * Generates Zero-PII structured telemetry events for Planner V2.
 * Never logs raw teacher instructions, observations, notes, student names, or unhashed IDs.
 */
class PlannerTelemetryLogger {
  constructor({ salt = null, maxBuffer = 100 } = {}) {
    this._salt = salt || process.env.TELEMETRY_SALT || crypto.randomBytes(32).toString('hex');
    this._maxBuffer = maxBuffer;
    this.events = [];
  }

  _hmac(value) {
    return crypto
      .createHmac('sha256', this._salt)
      .update(String(value || 'anonymous'))
      .digest('hex')
      .slice(0, 16);
  }

  record(payload) {
    const event = {
      timestamp: new Date().toISOString(),
      actor_hash: this._hmac(payload.actorId),
      request_id_hash: payload.requestId ? this._hmac(payload.requestId) : null,
      audience_type: payload.audienceType || null,
      curriculum_scope: payload.curriculumScope || null,
      provider: payload.provider || null,
      model: payload.model || null,
      is_simulated: payload.isSimulated === true,
      status: payload.status || 'ok',
      error_code: payload.errorCode || null,
      idempotent_replay: payload.idempotentReplay === true,
      repair_attempts_used: Number(payload.repairAttemptsUsed || 0),
      input_tokens: Number(payload.inputTokens || 0),
      output_tokens: Number(payload.outputTokens || 0),
      estimated_cost_usd: Number(payload.estimatedCostUsd || 0),
      latency_ms: Number(payload.latencyMs || 0),
      pii_redactions_count: Number(payload.piiRedactionsCount || 0),
      injection_signals_count: Number(payload.injectionSignalsCount || 0),
      heuristic_score: payload.heuristicScore ?? null,
    };

    // Defensive check against accidental free-text keys
    for (const forbidden of ['free_instructions', 'observations', 'notes', 'title', 'plan']) {
      if (Object.prototype.hasOwnProperty.call(event, forbidden)) {
        throw new PlannerV2Error('INVALID_REQUEST', `Telemetría intentó registrar clave prohibida: ${forbidden}`);
      }
    }

    this.events.push(event);
    if (this.events.length > this._maxBuffer) {
      this.events.shift();
    }
    return event;
  }
}

module.exports = {
  PlannerTelemetryLogger,
};
