'use strict';

const crypto = require('crypto');

const COPILOT_CONTRACT_VERSION = '1.0.0';

const COPILOT_MODES = Object.freeze(['consult', 'propose_changes', 'conflict']);

const COPILOT_OPERATION_TYPES = Object.freeze([
  'update_exercise',
  'add_exercise',
  'remove_exercise',
  'replace_exercise',
  'update_block',
  'add_block',
  'remove_block',
  'redistribute_duration',
  'link_resource',
  'update_internal_timings',
]);

/**
 * Deterministic SHA-256 hash of a ClassPlanModel / V2 plan JSON used for
 * optimistic concurrency checks (prevents stale IA proposals overwriting
 * manual edits made in the editor after requesting the copilot turn).
 */
function computeDraftVersionHash(plan) {
  if (!plan || typeof plan !== 'object') return '';
  const bloques = Array.isArray(plan.bloques) ? plan.bloques : [];
  const canonical = {
    titulo: String(plan.titulo || '').trim(),
    duracion_total: Number(plan.duracion_total || 0),
    audience_type: String(plan.audience_type || 'adultos'),
    curriculum_scope: String(plan.curriculum_scope || ''),
    enfoque: String(plan.enfoque || '').trim(),
    objetivos: Array.isArray(plan.objetivos) ? plan.objetivos.map((o) => String(o || '').trim()) : [],
    consejos_instructor: String(plan.consejos_instructor || '').trim(),
    bloques: bloques.map((b) => ({
      block_id: String(b?.block_id || ''),
      fase: String(b?.fase || '').trim(),
      fase_tipo: String(b?.fase_tipo || ''),
      duracion_min: Number(b?.duracion_min || 0),
      ejercicios: (Array.isArray(b?.ejercicios) ? b.ejercicios : []).map((e) => ({
        exercise_id: String(e?.exercise_id || ''),
        nombre: String(e?.nombre || '').trim(),
        tipo_actividad: String(e?.tipo_actividad || ''),
        detalle: String(e?.detalle || '').trim(),
        duracion_min: Number(e?.duracion_min || 0),
        organizacion: String(e?.organizacion || '').trim(),
        materiales: Array.isArray(e?.materiales) ? e.materiales.map((m) => String(m || '').trim()) : [],
        seguridad: String(e?.seguridad || '').trim(),
        diferenciacion_principiantes: String(e?.diferenciacion_principiantes || '').trim(),
        diferenciacion_intermedios: String(e?.diferenciacion_intermedios || '').trim(),
        diferenciacion_avanzados: String(e?.diferenciacion_avanzados || '').trim(),
        sugerencias_ia: String(e?.sugerencias_ia || '').trim(),
        observaciones_profesor: String(e?.observaciones_profesor || '').trim(),
        technical_movement_refs: Array.isArray(e?.technical_movement_refs) ? e.technical_movement_refs : [],
        curriculum_movement_ids: Array.isArray(e?.curriculum_movement_ids) ? e.curriculum_movement_ids : [],
        linked_resource_ids: Array.isArray(e?.linked_resource_ids) ? e.linked_resource_ids : [],
        tiempos_internos: Array.isArray(e?.tiempos_internos)
          ? e.tiempos_internos.map((t) => ({
              etapa: String(t?.etapa || '').trim(),
              minutos: Number(t?.minutos || 0),
            }))
          : [],
      })),
    })),
  };
  return crypto.createHash('sha256').update(JSON.stringify(canonical)).digest('hex').slice(0, 16);
}

const OPENAI_STRICT_COPILOT_V1_JSON_SCHEMA = Object.freeze({
  name: 'ginga_pedagogical_copilot_v1',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['mode', 'assistant_message', 'pedagogical_notes', 'conflict_reason', 'safe_alternative', 'operations'],
    properties: {
      mode: { type: 'string', enum: COPILOT_MODES },
      assistant_message: { type: 'string' },
      pedagogical_notes: { type: 'array', items: { type: 'string' } },
      conflict_reason: { type: ['string', 'null'] },
      safe_alternative: { type: ['string', 'null'] },
      operations: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          required: [
            'type',
            'block_id',
            'exercise_id',
            'target_duration_min',
            'resource_id',
            'resource_usage_note',
            'fase',
            'fase_tipo',
            'duracion_min',
            'nombre',
            'tipo_actividad',
            'detalle',
            'organizacion',
            'seguridad',
            'diferenciacion_principiantes',
            'diferenciacion_intermedios',
            'diferenciacion_avanzados',
            'sugerencias_ia',
            'technical_movement_refs',
            'curriculum_movement_ids',
            'materiales',
            'tiempos_internos',
          ],
          properties: {
            type: { type: 'string', enum: COPILOT_OPERATION_TYPES },
            block_id: { type: ['string', 'null'] },
            exercise_id: { type: ['string', 'null'] },
            target_duration_min: { type: ['integer', 'null'] },
            resource_id: { type: ['string', 'null'] },
            resource_usage_note: { type: ['string', 'null'] },
            fase: { type: ['string', 'null'] },
            fase_tipo: { type: ['string', 'null'] },
            duracion_min: { type: ['integer', 'null'] },
            nombre: { type: ['string', 'null'] },
            tipo_actividad: { type: ['string', 'null'] },
            detalle: { type: ['string', 'null'] },
            organizacion: { type: ['string', 'null'] },
            seguridad: { type: ['string', 'null'] },
            diferenciacion_principiantes: { type: ['string', 'null'] },
            diferenciacion_intermedios: { type: ['string', 'null'] },
            diferenciacion_avanzados: { type: ['string', 'null'] },
            sugerencias_ia: { type: ['string', 'null'] },
            technical_movement_refs: {
              anyOf: [{ type: 'array', items: { type: 'string' } }, { type: 'null' }],
            },
            curriculum_movement_ids: {
              anyOf: [{ type: 'array', items: { type: 'string' } }, { type: 'null' }],
            },
            materiales: {
              anyOf: [{ type: 'array', items: { type: 'string' } }, { type: 'null' }],
            },
            tiempos_internos: {
              anyOf: [
                {
                  type: 'array',
                  items: {
                    type: 'object',
                    additionalProperties: false,
                    required: ['etapa', 'minutos'],
                    properties: {
                      etapa: { type: 'string' },
                      minutos: { type: 'integer' },
                    },
                  },
                },
                { type: 'null' },
              ],
            },
          },
        },
      },
    },
  },
});

module.exports = {
  COPILOT_CONTRACT_VERSION,
  COPILOT_MODES,
  COPILOT_OPERATION_TYPES,
  OPENAI_STRICT_COPILOT_V1_JSON_SCHEMA,
  computeDraftVersionHash,
};
