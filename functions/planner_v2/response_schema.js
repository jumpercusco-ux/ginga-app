'use strict';

const CONTENT_ORIGIN_ENUM = [
  'official_fiu_curriculum',
  'teacher_resource',
  'ai_complementary_proposal',
];

const SOURCE_ORIGIN_ITEM_ENUM = [
  'official_fiu_curriculum',
  'teacher_resource',
  'ai_designed_activity',
  'ai_complementary_proposal',
];

const ACTIVITY_AUTHORING_ENUM = [
  'official_fiu_sequence',
  'ai_exercise_from_official_fiu',
  'teacher_resource',
  'teacher_resource_with_official_fiu_movements',
  'ai_complementary_proposal',
];

const FASE_TIPO_ENUM = [
  'calentamiento',
  'tecnica',
  'juegos',
  'acrobacias_suelo',
  'musicalidad',
  'angola',
  'roda_musicalidad',
  'vuelta_calma',
  'recurso_profesor',
];

const ORGANIZATION_MODE_ENUM = [
  'Todos simultáneamente',
  'Rotación por parejas',
  'Estaciones simultáneas',
  'Turnos',
];

const CLASS_PLAN_V2_JSON_SCHEMA = Object.freeze({
  name: 'ginga_class_plan_v2',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: [
      'titulo',
      'duracion_total',
      'nivel',
      'audience_type',
      'curriculum_scope',
      'enfoque',
      'objetivo',
      'objetivos',
      'bloques',
      'consejos_instructor',
      'continuity_applied_note',
    ],
    properties: {
      titulo: { type: 'string', minLength: 5, maxLength: 140 },
      duracion_total: { type: 'integer', minimum: 20, maximum: 180 },
      nivel: { type: 'string', enum: ['Adultos', 'Infantil', 'Mixto'] },
      audience_type: { type: 'string', enum: ['adultos', 'infantil', 'mixto'] },
      curriculum_scope: {
        type: 'string',
        enum: ['adulto_fiu', 'infantil_fiu_pending', 'mixed_no_official_track', 'none_manual'],
      },
      enfoque: { type: 'string', minLength: 3, maxLength: 120 },
      objetivo: { type: 'string', minLength: 5, maxLength: 300 },
      objetivos: {
        type: 'array',
        minItems: 1,
        maxItems: 6,
        items: { type: 'string', minLength: 4, maxLength: 220 },
      },
      bloques: {
        type: 'array',
        minItems: 2,
        maxItems: 7,
        items: {
          type: 'object',
          additionalProperties: false,
          required: ['block_id', 'fase', 'fase_tipo', 'duracion_min', 'ejercicios'],
          properties: {
            block_id: { type: 'string', minLength: 3, maxLength: 60 },
            fase: { type: 'string', minLength: 3, maxLength: 100 },
            fase_tipo: { type: 'string', enum: FASE_TIPO_ENUM },
            duracion_min: { type: 'integer', minimum: 2, maximum: 120 },
            ejercicios: {
              type: 'array',
              minItems: 1,
              maxItems: 5,
              items: {
                type: 'object',
                additionalProperties: false,
                required: [
                  'exercise_id',
                  'nombre',
                  'tipo_actividad',
                  'detalle',
                  'duracion_min',
                  'organizacion',
                  'supervision_instructors_needed',
                  'materiales',
                  'seguridad',
                  'diferenciacion_principiantes',
                  'diferenciacion_intermedios',
                  'diferenciacion_avanzados',
                  'observaciones_profesor',
                  'content_origin',
                  'source_origins',
                  'activity_authoring',
                  'curriculum_movement_ids',
                  'linked_resource_ids',
                  'resource_usage_notes',
                  'tiempos_internos',
                  'cancionero_reference',
                  'video_reference_note',
                ],
                properties: {
                  exercise_id: { type: 'string', minLength: 3, maxLength: 60 },
                  nombre: { type: 'string', minLength: 3, maxLength: 120 },
                  tipo_actividad: {
                    type: 'string',
                    enum: [
                      'ejercicio_tecnico',
                      'juego_dinamico',
                      'drill_parejas',
                      'progresion_suelo',
                      'musicalidad_roda',
                      'angola_dialogo',
                      'cierre',
                    ],
                  },
                  detalle: { type: 'string', minLength: 20, maxLength: 1600 },
                  duracion_min: { type: 'integer', minimum: 1, maximum: 90 },
                  organizacion: { type: 'string', minLength: 3, maxLength: 80 },
                  supervision_instructors_needed: { type: 'integer', minimum: 1, maximum: 5 },
                  materiales: { type: 'array', items: { type: 'string' } },
                  seguridad: { type: 'string', minLength: 5, maxLength: 400 },
                  diferenciacion_principiantes: { type: 'string', minLength: 0, maxLength: 400 },
                  diferenciacion_intermedios: { type: 'string', minLength: 0, maxLength: 400 },
                  diferenciacion_avanzados: { type: 'string', minLength: 0, maxLength: 400 },
                  observaciones_profesor: { type: 'string', minLength: 0, maxLength: 400 },
                  content_origin: { type: 'string', enum: CONTENT_ORIGIN_ENUM },
                  source_origins: {
                    type: 'array',
                    minItems: 1,
                    items: { type: 'string', enum: SOURCE_ORIGIN_ITEM_ENUM },
                  },
                  activity_authoring: { type: 'string', enum: ACTIVITY_AUTHORING_ENUM },
                  curriculum_movement_ids: { type: 'array', items: { type: 'string' } },
                  linked_resource_ids: { type: 'array', items: { type: 'string' } },
                  resource_usage_notes: {
                    type: 'object',
                    additionalProperties: { type: 'string' },
                  },
                  tiempos_internos: {
                    type: 'array',
                    items: {
                      type: 'object',
                      additionalProperties: false,
                      required: ['etapa', 'minutos'],
                      properties: {
                        etapa: { type: 'string', minLength: 2, maxLength: 100 },
                        minutos: { type: 'integer', minimum: 1, maximum: 90 },
                      },
                    },
                  },
                  cancionero_reference: {
                    type: ['object', 'null'],
                    additionalProperties: false,
                    required: ['song_title', 'rhythm', 'audience_fit', 'cantiga_id', 'lookup_hint'],
                    properties: {
                      song_title: { type: 'string', minLength: 2, maxLength: 100 },
                      rhythm: { type: 'string', minLength: 2, maxLength: 50 },
                      audience_fit: { type: 'string', enum: ['infantil', 'adultos', 'todos'] },
                      cantiga_id: { type: ['string', 'null'] },
                      lookup_hint: { type: 'string', minLength: 4, maxLength: 200 },
                    },
                  },
                  video_reference_note: { type: ['string', 'null'] },
                },
              },
            },
          },
        },
      },
      consejos_instructor: { type: 'string', minLength: 5, maxLength: 600 },
      continuity_applied_note: { type: 'string', minLength: 0, maxLength: 400 },
    },
  },
});

const OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA = Object.freeze({
  name: 'ginga_class_plan_v2',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: [
      'titulo',
      'duracion_total',
      'nivel',
      'audience_type',
      'curriculum_scope',
      'enfoque',
      'objetivo',
      'objetivos',
      'bloques',
      'consejos_instructor',
      'continuity_applied_note',
    ],
    properties: {
      titulo: { type: 'string' },
      duracion_total: { type: 'integer' },
      nivel: { type: 'string', enum: ['Adultos', 'Infantil', 'Mixto'] },
      audience_type: { type: 'string', enum: ['adultos', 'infantil', 'mixto'] },
      curriculum_scope: {
        type: 'string',
        enum: ['adulto_fiu', 'infantil_fiu_pending', 'mixed_no_official_track', 'none_manual'],
      },
      enfoque: { type: 'string' },
      objetivo: { type: 'string' },
      objetivos: {
        type: 'array',
        items: { type: 'string' },
      },
      bloques: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          required: ['block_id', 'fase', 'fase_tipo', 'duracion_min', 'ejercicios'],
          properties: {
            block_id: { type: 'string' },
            fase: { type: 'string' },
            fase_tipo: { type: 'string', enum: FASE_TIPO_ENUM },
            duracion_min: { type: 'integer' },
            ejercicios: {
              type: 'array',
              items: {
                type: 'object',
                additionalProperties: false,
                required: [
                  'exercise_id',
                  'nombre',
                  'tipo_actividad',
                  'detalle',
                  'duracion_min',
                  'organizacion',
                  'supervision_instructors_needed',
                  'materiales',
                  'seguridad',
                  'diferenciacion_principiantes',
                  'diferenciacion_intermedios',
                  'diferenciacion_avanzados',
                  'observaciones_profesor',
                  'content_origin',
                  'source_origins',
                  'activity_authoring',
                  'curriculum_movement_ids',
                  'linked_resource_ids',
                  'resource_usage_notes',
                  'tiempos_internos',
                  'cancionero_reference',
                  'video_reference_note',
                ],
                properties: {
                  exercise_id: { type: 'string' },
                  nombre: { type: 'string' },
                  tipo_actividad: {
                    type: 'string',
                    enum: [
                      'ejercicio_tecnico',
                      'juego_dinamico',
                      'drill_parejas',
                      'progresion_suelo',
                      'musicalidad_roda',
                      'angola_dialogo',
                      'cierre',
                    ],
                  },
                  detalle: {
              type: 'string',
              description: 'Pasos ejecutables (Preparación, Reglas/señales, Rondas/rotación; bloques musicales: canto, palmas y roda).',
            },
                  duracion_min: { type: 'integer' },
                  organizacion: { type: 'string' },
                  supervision_instructors_needed: { type: 'integer' },
                  materiales: { type: 'array', items: { type: 'string' } },
                  seguridad: { type: 'string' },
                  diferenciacion_principiantes: { type: 'string' },
                  diferenciacion_intermedios: { type: 'string' },
                  diferenciacion_avanzados: { type: 'string' },
                  observaciones_profesor: { type: 'string' },
                  content_origin: { type: 'string', enum: CONTENT_ORIGIN_ENUM },
                  source_origins: {
                    type: 'array',
                    items: { type: 'string', enum: SOURCE_ORIGIN_ITEM_ENUM },
                  },
                  activity_authoring: { type: 'string', enum: ACTIVITY_AUTHORING_ENUM },
                  curriculum_movement_ids: { type: 'array', items: { type: 'string' } },
                  linked_resource_ids: { type: 'array', items: { type: 'string' } },
                  resource_usage_notes: {
                    type: 'array',
                    items: {
                      type: 'object',
                      additionalProperties: false,
                      required: ['resource_id', 'note'],
                      properties: {
                        resource_id: { type: 'string' },
                        note: { type: 'string' },
                      },
                    },
                  },
                  tiempos_internos: {
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
                  cancionero_reference: {
                    anyOf: [
                      {
                        type: 'object',
                        additionalProperties: false,
                        required: ['song_title', 'rhythm', 'audience_fit', 'cantiga_id', 'lookup_hint'],
                        properties: {
                          song_title: { type: 'string' },
                          rhythm: { type: 'string' },
                          audience_fit: { type: 'string', enum: ['infantil', 'adultos', 'todos'] },
                          cantiga_id: { type: 'null' },
                          lookup_hint: { type: 'string' },
                        },
                      },
                      { type: 'null' },
                    ],
                  },
                  video_reference_note: { type: ['string', 'null'] },
                },
              },
            },
          },
        },
      },
      consejos_instructor: { type: 'string' },
      continuity_applied_note: { type: 'string' },
    },
  },
});

const OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA = Object.freeze({
  name: 'ginga_class_block_v2',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['fase', 'ejercicios'],
    properties: {
      fase: { type: 'string' },
      ejercicios: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          required: [
            'nombre',
            'tipo_actividad',
            'detalle',
            'organizacion',
            'materiales',
            'seguridad',
            'diferenciacion_principiantes',
            'diferenciacion_intermedios',
            'diferenciacion_avanzados',
            'sugerencias_ia',
            'technical_movement_refs',
            'tiempos_internos',
            'cancionero_reference',
          ],
          properties: {
            nombre: { type: 'string' },
            tipo_actividad: {
              type: 'string',
              enum: [
                'ejercicio_tecnico',
                'juego_dinamico',
                'drill_parejas',
                'progresion_suelo',
                'musicalidad_roda',
                'angola_dialogo',
                'cierre',
              ],
            },
            detalle: {
              type: 'string',
              description: 'Pasos ejecutables (Preparación, Reglas/señales, Rondas/rotación; bloques musicales: canto, palmas y roda).',
            },
            organizacion: { type: 'string', enum: ORGANIZATION_MODE_ENUM },
            materiales: { type: 'array', items: { type: 'string' } },
            seguridad: { type: 'string' },
            diferenciacion_principiantes: { type: 'string' },
            diferenciacion_intermedios: { type: 'string' },
            diferenciacion_avanzados: { type: 'string' },
            sugerencias_ia: { type: 'string' },
            technical_movement_refs: { type: 'array', items: { type: 'string' } },
            tiempos_internos: {
              type: 'array',
              description: 'Si duracion_min >= 4: obligatorio >= 2 etapas reales cuya suma iguale duracion_min.',
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
            cancionero_reference: {
              anyOf: [
                {
                  type: 'object',
                  additionalProperties: false,
                  required: ['song_title', 'rhythm', 'audience_fit', 'lookup_hint'],
                  properties: {
                    song_title: { type: 'string' },
                    rhythm: { type: 'string' },
                    audience_fit: { type: 'string', enum: ['infantil', 'adultos', 'todos'] },
                    lookup_hint: { type: 'string' },
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

function syncInternalTimingsIntoDetalle(ex) {
  if (!ex || typeof ex !== 'object') return;
  const items = Array.isArray(ex.tiempos_internos)
    ? ex.tiempos_internos
        .map((t) => ({
          etapa: String(t?.etapa || '').trim(),
          minutos: Number(t?.minutos),
        }))
        .filter((t) => t.etapa.length > 0 && Number.isInteger(t.minutos) && t.minutos >= 1)
    : [];

  ex.tiempos_internos = items;
  if (items.length === 0) return;

  const total = items.reduce((acc, t) => acc + t.minutos, 0);
  const parts = items.map((t) => `${t.etapa} ${t.minutos} min`);
  const summaryLine = `Tiempos internos (${parts.join(' + ')} = total: ${total} min).`;

  const rawDet = String(ex.detalle || '').trim();
  const stripped = rawDet
    .replace(/\s*Tiempos internos\s*\([^)]*\)\.?/gi, '')
    .trim();
  ex.detalle = stripped ? `${stripped} ${summaryLine}` : summaryLine;
}

function normalizeOpenAiWireBlock(rawBlock) {
  if (!rawBlock || typeof rawBlock !== 'object') return rawBlock;
  const copy = JSON.parse(JSON.stringify(rawBlock));
  const exs = Array.isArray(copy.ejercicios) ? copy.ejercicios : [];
  for (const ex of exs) {
    if (!ex || typeof ex !== 'object') continue;
    if (ex.cancionero_reference && typeof ex.cancionero_reference === 'object') {
      ex.cancionero_reference = {
        ...ex.cancionero_reference,
        cantiga_id: null,
      };
    }
    syncInternalTimingsIntoDetalle(ex);
  }
  return copy;
}

function normalizeOpenAiWirePlan(plan) {
  if (!plan || typeof plan !== 'object') return plan;
  const copy = JSON.parse(JSON.stringify(plan));
  if (!Array.isArray(copy.bloques)) return copy;

  for (const blk of copy.bloques) {
    if (!blk || !Array.isArray(blk.ejercicios)) continue;
    for (const ex of blk.ejercicios) {
      if (!ex || typeof ex !== 'object') continue;
      if (Array.isArray(ex.resource_usage_notes)) {
        const mapped = {};
        for (const item of ex.resource_usage_notes) {
          const rId = String(item?.resource_id || '').trim();
          const note = String(item?.note || '').trim();
          if (rId && note) mapped[rId] = note;
        }
        ex.resource_usage_notes = mapped;
      } else if (!ex.resource_usage_notes || typeof ex.resource_usage_notes !== 'object') {
        ex.resource_usage_notes = {};
      }
      syncInternalTimingsIntoDetalle(ex);
    }
  }
  return copy;
}

module.exports = {
  CONTENT_ORIGIN_ENUM,
  SOURCE_ORIGIN_ITEM_ENUM,
  ACTIVITY_AUTHORING_ENUM,
  FASE_TIPO_ENUM,
  ORGANIZATION_MODE_ENUM,
  CLASS_PLAN_V2_JSON_SCHEMA,
  OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA,
  OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA,
  normalizeOpenAiWirePlan,
  normalizeOpenAiWireBlock,
  syncInternalTimingsIntoDetalle,
};
