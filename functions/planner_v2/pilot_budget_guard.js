'use strict';

const fs = require('fs');
const path = require('path');
const { PlannerV2Error } = require('./errors');
const { estimateCostUsd } = require('./config');

/**
 * Atomic accumulated budget and generation counter guard for local/dev real LLM pilots.
 * Enforces hard ceiling on both USD spend (considering concurrent requests, max output tokens,
 * and max 1 repair attempt) and total successful/attempted pilot generations.
 * Optionally persists settled spend/counts to `stateFilePath` across server restarts.
 */
class AtomicPilotBudgetGuard {
  constructor({ maxBudgetUsd = 0.10, maxGenerations = 4, stateFilePath = '' } = {}) {
    this.maxBudgetUsd = Number(Number(maxBudgetUsd).toFixed(6));
    this.maxGenerations = Number.isInteger(maxGenerations) && maxGenerations > 0 ? maxGenerations : 4;
    this.stateFilePath = stateFilePath ? String(stateFilePath).trim() : '';
    this._spentUsd = 0;
    this._completedGenerations = 0;
    this._totalLlmCalls = 0;
    this._reservations = new Map();
    this._mutex = Promise.resolve();
    this._loadPersistedState();
  }

  _loadPersistedState() {
    if (!this.stateFilePath) return;
    try {
      if (!fs.existsSync(this.stateFilePath)) return;
      const raw = JSON.parse(fs.readFileSync(this.stateFilePath, 'utf8'));
      if (typeof raw.spent_usd === 'number' && raw.spent_usd >= 0) {
        this._spentUsd = Number(raw.spent_usd.toFixed(6));
      }
      if (Number.isInteger(raw.completed_generations) && raw.completed_generations >= 0) {
        this._completedGenerations = raw.completed_generations;
      }
      if (Number.isInteger(raw.total_llm_calls) && raw.total_llm_calls >= 0) {
        this._totalLlmCalls = raw.total_llm_calls;
      }
    } catch (_) {
      // Ignore corrupt/unreadable optional state file
    }
  }

  _persistState() {
    if (!this.stateFilePath) return;
    try {
      const dir = path.dirname(this.stateFilePath);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(
        this.stateFilePath,
        JSON.stringify(
          {
            max_budget_usd: this.maxBudgetUsd,
            spent_usd: Number(this._spentUsd.toFixed(6)),
            completed_generations: this._completedGenerations,
            max_generations: this.maxGenerations,
            total_llm_calls: this._totalLlmCalls,
            updated_at: new Date().toISOString(),
          },
          null,
          2
        )
      );
    } catch (_) {
      // Best-effort persistence in local dev scratch
    }
  }

  async _withLock(fn) {
    const prev = this._mutex;
    let releaseNext;
    const next = new Promise((resolve) => {
      releaseNext = resolve;
    });
    this._mutex = prev.then(() => next, () => next);
    await prev;
    try {
      return await fn();
    } finally {
      releaseNext();
    }
  }

  estimateWorstCaseGenerationUsd({
    model = 'gpt-4o-mini',
    estimatedInputTokens = 3000,
    maxOutputTokens = 4500,
    maxRepairAttempts = 1,
    mode = 'monolithic',
    blocksCount = 4,
    blockMaxOutputTokens = 1600,
  } = {}) {
    if (mode === 'modular') {
      const safeBlocks = Math.max(1, Number(blocksCount || 4));
      const perBlockWorst = estimateCostUsd(model, estimatedInputTokens, blockMaxOutputTokens);
      const repairInputWorst = estimatedInputTokens + blockMaxOutputTokens;
      // Reserve worst-case simultaneous repair across ALL blocks in 1 repair wave
      const repairWorst =
        maxRepairAttempts > 0
          ? maxRepairAttempts * safeBlocks * estimateCostUsd(model, repairInputWorst, blockMaxOutputTokens)
          : 0;
      return Number((safeBlocks * perBlockWorst + repairWorst).toFixed(6));
    }
    const primaryWorst = estimateCostUsd(model, estimatedInputTokens, maxOutputTokens);
    const repairInputWorst = estimatedInputTokens + maxOutputTokens;
    const repairWorst =
      maxRepairAttempts > 0
        ? maxRepairAttempts * estimateCostUsd(model, repairInputWorst, maxOutputTokens)
        : 0;
    return Number((primaryWorst + repairWorst).toFixed(6));
  }

  _reservedSumUsd() {
    let total = 0;
    for (const r of this._reservations.values()) {
      total += r.reservedUsd;
    }
    return Number(total.toFixed(6));
  }

  getSnapshot() {
    const reservedUsd = this._reservedSumUsd();
    const committedPlusReserved = Number((this._spentUsd + reservedUsd).toFixed(6));
    const remainingUsd = Number(Math.max(0, this.maxBudgetUsd - committedPlusReserved).toFixed(6));
    return {
      max_budget_usd: this.maxBudgetUsd,
      spent_usd: Number(this._spentUsd.toFixed(6)),
      reserved_usd: reservedUsd,
      remaining_usd: remainingUsd,
      completed_generations: this._completedGenerations,
      in_flight_generations: this._reservations.size,
      max_generations: this.maxGenerations,
      total_llm_calls: this._totalLlmCalls,
    };
  }

  async reserveGeneration({
    requestId,
    model = 'gpt-4o-mini',
    estimatedInputTokens = 3000,
    maxOutputTokens = 4500,
    maxRepairAttempts = 1,
    mode = 'monolithic',
    blocksCount = 4,
    blockMaxOutputTokens = 1600,
  }) {
    const cleanId = String(requestId || '').trim();
    if (!cleanId) {
      throw new PlannerV2Error(
        'INVALID_REQUEST',
        'El identificador request_id es obligatorio para reservar presupuesto.',
        { httpStatus: 400 }
      );
    }

    return this._withLock(() => {
      if (this._reservations.has(cleanId)) {
        throw new PlannerV2Error(
          'CONCURRENT_REQUEST_IN_PROGRESS',
          'Ya existe una reserva de presupuesto en curso para este request_id.',
          { httpStatus: 409, retryable: true }
        );
      }

      if (this._completedGenerations + this._reservations.size >= this.maxGenerations) {
        const snapshot = this.getSnapshot();
        throw new PlannerV2Error(
          'PILOT_BUDGET_EXCEEDED',
          `Se alcanzó el máximo autorizado de ${this.maxGenerations} generaciones del piloto.`,
          { httpStatus: 429, retryable: false, details: { pilot_budget: snapshot } }
        );
      }

      const worstCaseUsd = this.estimateWorstCaseGenerationUsd({
        model,
        estimatedInputTokens,
        maxOutputTokens,
        maxRepairAttempts,
        mode,
        blocksCount,
        blockMaxOutputTokens,
      });

      const currentReserved = this._reservedSumUsd();
      const projectedTotal = Number((this._spentUsd + currentReserved + worstCaseUsd).toFixed(6));
      if (projectedTotal > this.maxBudgetUsd + 1e-9) {
        const snapshot = this.getSnapshot();
        throw new PlannerV2Error(
          'PILOT_BUDGET_EXCEEDED',
          `El presupuesto acumulado máximo de USD ${this.maxBudgetUsd.toFixed(2)} impide iniciar otra generación (proyectado: USD ${projectedTotal.toFixed(4)}).`,
          {
            httpStatus: 429,
            retryable: false,
            details: {
              worst_case_request_usd: worstCaseUsd,
              projected_total_usd: projectedTotal,
              pilot_budget: snapshot,
            },
          }
        );
      }

      this._reservations.set(cleanId, {
        reservedUsd: worstCaseUsd,
        startedAtMs: Date.now(),
      });

      return {
        reservedUsd: worstCaseUsd,
        snapshot: this.getSnapshot(),
      };
    });
  }

  async settleGeneration({
    requestId,
    actualCostUsd = 0,
    actualCalls = 1,
    succeeded = true,
  }) {
    const cleanId = String(requestId || '').trim();
    return this._withLock(() => {
      const hadReservation = this._reservations.delete(cleanId);
      if (!hadReservation && actualCostUsd <= 0 && actualCalls <= 0) {
        return this.getSnapshot();
      }

      const safeCost = Math.max(0, Number(actualCostUsd || 0));
      const safeCalls = Math.max(0, Number(actualCalls || 0));

      this._spentUsd = Number((this._spentUsd + safeCost).toFixed(6));
      this._totalLlmCalls += safeCalls;

      if (succeeded || safeCalls > 0) {
        this._completedGenerations += 1;
      }

      this._persistState();
      return this.getSnapshot();
    });
  }
}

module.exports = {
  AtomicPilotBudgetGuard,
};
