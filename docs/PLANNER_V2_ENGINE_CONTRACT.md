# Contrato Definitivo del Motor Pedagógico GINGA V2 (`v2.1.0`)

> **Estado en `PED-04C2-B`:** Implementado y verificado offline en `functions/planner_v2/`. Proveedor LLM real estrictamente deshabilitado; sin exportación todavía en `functions/index.js`.

---

## 1. Principios de Autoridad, Seguridad y Privacidad

1. **Control exclusivo de políticas en servidor:** El cliente **no puede** enviar ni sobrescribir `provider`, `provider_mode`, `model`, `fallback_model`, `max_repair_attempts`, `max_tokens`, `budget`, `quota`, `permissions`, `roles`, `custom_claims`, `bypass_auth` ni `generation_options.*`. Cualquier intento es rechazado con `FORBIDDEN_CLIENT_POLICY_OVERRIDE` (`HTTP 403`).
2. **Autorización por Custom Claims firmados:** Se requiere `context.auth.uid` + claim firmado `instructor`, `teacher`, `admin` o `curriculum_admin`. Nunca se confía en `users/{uid}.rol`. El bypass local sin autenticación únicamente opera cuando `NODE_ENV !== 'production'`, fuera de Cloud Functions y con bandera de servidor explícita en entorno aislado.
3. **Zero IDs internos y URLs hacia el LLM:** El `llmPayloadContext` excluye `uid`, `user_id`, `instructor_id`, `clase_id`, `group_id`, `request_id`, `source_session_id`, `plan_id` y cualquier URL cruda (`http://`, `https://`), verificado deterministamente antes de invocar cualquier proveedor.
4. **Límite de la sanitización heurística:** `pii_and_injection_guard.js` redacta correos, teléfonos, handles, documentos, fechas, nombres y apodos mediante heurísticas, pero el contrato declara explícitamente en `privacy_notice.heuristic_disclaimer` que **la sanitización heurística no garantiza ausencia absoluta de PII en texto libre**.
5. **Validación estricta de obligatorios y espacio:**
   - Todo movimiento o recurso `required` inválido, no elegible o no autorizado produce rechazo explícito (`INVALID_REQUIRED_MOVEMENT`, `INVALID_OR_UNAUTHORIZED_REQUIRED_RESOURCE`, `UNAUTHORIZED_RESOURCE`), **nunca** exclusión silenciosa.
   - Si no se declaran `floor_type`, `available_mats` o `materials`, el servidor los marca como desconocidos (`floor_type: "desconocido"`, `available_mats: null`, `materials_known: false`) sin asumir tatami, colchonetas ni materiales.
   - `instructors_available` es opcional (entero `1..10`); si se omite, el servidor usa `1` conservador (`instructors_available_source: "conservative_default"`).

---

## 2. Precedencia de Orígenes y Autoría Pedagógica

Todo ejercicio del plan emite:
- `content_origin` (`official_fiu_curriculum | teacher_resource | ai_complementary_proposal`) — compatibilidad directa con Flutter V2.
- `source_origins` (arreglo de orígenes reales participantes).
- `activity_authoring` — distingue explícitamente entre movimiento FIU y actividad diseñada por IA:

| Condición de vínculos del ejercicio | `content_origin` | `source_origins` | `activity_authoring` |
|---|---|---|---|
| Recurso Pizarra + Movimiento FIU | `teacher_resource` | `["teacher_resource", "official_fiu_curriculum"]` | `teacher_resource_with_official_fiu_movements` |
| Solo Recurso Pizarra | `teacher_resource` | `["teacher_resource"]` | `teacher_resource` |
| Solo Movimiento FIU (`combinacao_solo`) | `official_fiu_curriculum` | `["official_fiu_curriculum"]` | `official_fiu_sequence` |
| Solo Movimiento FIU (diseñado por IA) | `official_fiu_curriculum` | `["official_fiu_curriculum", "ai_designed_activity"]` | `ai_exercise_from_official_fiu` |
| Sin vínculo FIU ni Pizarra | `ai_complementary_proposal` | `["ai_complementary_proposal"]` | `ai_complementary_proposal` |

- Cuando `session_config.allow_ai_complementary_proposals === false`, ningún ejercicio puede tener `content_origin === "ai_complementary_proposal"`, y la rúbrica heurística **no penaliza** la falta de diversidad de orígenes.

---

## 3. Contrato JSON de Entrada (`GenerateClassPlanV2Request`)

```json
{
  "contract_version": "2.1.0",
  "request_id": "req_uuid_idempotente",
  "creation_mode": "rápida | avanzada",
  "group_context": {
    "source": "real_class | manual",
    "clase_id": "opcional_solo_metadata_no_enviada_al_llm",
    "group_label": "string",
    "audience_type": "adultos | infantil | mixto",
    "age_min": 18,
    "age_max": 42,
    "estimated_participants": 14,
    "observed_cordas_summary": { "Corda Crua": 4, "Corda Crua e Verde": 6 },
    "experience_distribution": {
      "principiantes": 5,
      "intermedios": 6,
      "avanzados": 3,
      "manually_confirmed": true
    }
  },
  "curriculum_context": {
    "scope": "adulto_fiu | infantil_fiu_pending | mixed_no_official_track | none_manual",
    "target_corda_index": 2
  },
  "space_context": {
    "space_size": "amplio | mediano | reducido | desconocido",
    "floor_type": "tatami | madera | cemento | exterior | pasto | desconocido",
    "available_mats": true,
    "instructors_available": 1,
    "space_notes": "string opcional"
  },
  "session_config": {
    "duration_min": 60,
    "focuses": ["Técnica", "Musicalidad"],
    "objectives": ["string"],
    "materials": ["Berimbau", "Pandeiro"],
    "include_musicality_roda": true,
    "allow_ai_complementary_proposals": true,
    "free_instructions": "string opcional"
  },
  "selected_movements": [
    { "movement_id": "queixada", "priority": "required | optional" }
  ],
  "selected_resources": [
    {
      "resource_id": "res_pizarra_014",
      "priority": "required | optional",
      "usage_note": "string opcional"
    }
  ],
  "continuity_context": {
    "audience_type": "adultos | infantil | mixto",
    "completed_exercises": ["string"],
    "skipped_exercises": ["string"],
    "pending_exercises": ["string"],
    "worked_movements": ["string"],
    "group_response": "string",
    "difficulties": "string",
    "teacher_observations": "string",
    "reinforce_content": "string",
    "continuity_proposal": "string"
  },
  "recent_history_summary": [
    {
      "session_recency": "hace_7_dias",
      "worked_movements": ["ginga", "cocorinha"],
      "focuses": ["Técnica"]
    }
  ]
}
```

---

## 4. Contrato JSON de Salida (`GenerateClassPlanV2Response`)

```json
{
  "contract_version": "2.1.0",
  "status": "ok",
  "plan": {
    "titulo": "string",
    "duracion_total": 60,
    "nivel": "Adultos | Infantil | Mixto",
    "audience_type": "adultos | infantil | mixto",
    "curriculum_scope": "adulto_fiu | infantil_fiu_pending | mixed_no_official_track | none_manual",
    "enfoque": "string",
    "objetivo": "string",
    "objetivos": ["string"],
    "group_snapshot": { "...": "sin PII" },
    "space_snapshot": {
      "space_size": "mediano",
      "floor_type": "tatami",
      "available_mats": true,
      "instructors_available": 1
    },
    "bloques": [
      {
        "block_id": "string",
        "fase": "string",
        "fase_tipo": "calentamiento | tecnica | juegos | acrobacias_suelo | musicalidad | angola | roda_musicalidad | vuelta_calma | recurso_profesor",
        "duracion_min": 15,
        "ejercicios": [
          {
            "exercise_id": "string",
            "nombre": "string",
            "tipo_actividad": "ejercicio_tecnico | juego_dinamico | drill_parejas | progresion_suelo | musicalidad_roda | angola_dialogo | cierre",
            "detalle": "string",
            "duracion_min": 15,
            "organizacion": "string",
            "supervision_instructors_needed": 1,
            "materiales": ["string"],
            "seguridad": "string",
            "diferenciacion_principiantes": "string",
            "diferenciacion_intermedios": "string",
            "diferenciacion_avanzados": "string",
            "observaciones_profesor": "string",
            "content_origin": "official_fiu_curriculum | teacher_resource | ai_complementary_proposal",
            "source_origins": ["string"],
            "activity_authoring": "string",
            "curriculum_movement_ids": ["string"],
            "linked_resource_ids": ["string"],
            "resource_usage_notes": { "<resource_id>": "string" },
            "cancionero_reference": {
              "song_title": "string",
              "rhythm": "string",
              "audience_fit": "infantil | adultos | todos",
              "cantiga_id": null,
              "lookup_hint": "string"
            },
            "video_reference_note": "string | null"
          }
        ]
      }
    ],
    "consejos_instructor": "string",
    "continuity_applied_note": "string"
  },
  "generation_meta": {
    "engine_version": "planner_v2.1.0",
    "provider": "simulated | openai",
    "model": "simulated-planner-v2 | gpt-4.1-mini | gpt-4o-mini",
    "is_simulated": true,
    "idempotent_replay": false,
    "actor_mode": "custom_claims | local_dev_simulated_unauthenticated",
    "generated_at": "ISO-8601",
    "repair_attempts_used": 0,
    "deterministic_fixes_applied": ["string"],
    "origin_breakdown": {
      "official_fiu_curriculum": 0,
      "teacher_resource": 0,
      "ai_complementary_proposal": 0
    },
    "excluded_or_unlinked_inputs": [],
    "transparency_notices": ["string"]
  },
  "validation_report": {
    "infrastructure": {
      "passed": true,
      "catalog_sha256_verified": "0a4b2237...",
      "custom_claims_verified": true,
      "client_policy_overrides_blocked": true,
      "atomic_quota_slot_reserved": true,
      "llm_payload_zero_internal_ids": true
    },
    "structural": {
      "passed": true,
      "errors": [],
      "warnings": [],
      "duration_sum_exact": true,
      "required_movements_covered": true,
      "required_resources_covered": true,
      "curriculum_track_respected": true,
      "pii_heuristic_clean": true
    },
    "pedagogical_heuristic": {
      "evaluation_kind": "heuristic_offline_not_human_or_real_llm",
      "score_total": 96,
      "threshold_suggested": 80,
      "dimensions": {}
    },
    "human_evaluation_status": "pending",
    "real_llm_quality_status": "pending_real_provider_disabled"
  },
  "cost_telemetry": {
    "input_tokens": 0,
    "output_tokens": 0,
    "estimated_cost_usd": 0,
    "latency_ms": 0,
    "quota_usage": {
      "dayBucket": "YYYY-MM-DD",
      "dailyUsed": 1,
      "dailyLimit": 20,
      "minuteUsed": 1,
      "perMinuteLimit": 4
    }
  },
  "privacy_notice": {
    "pii_redactions_applied": 0,
    "redaction_categories": [],
    "injection_signals_detected": [],
    "heuristic_disclaimer": "La sanitización heurística reduce el riesgo de exposición de datos personales, pero NO garantiza ausencia absoluta de PII en texto libre."
  }
}
```

---

## 5. Catálogo de Códigos de Error Deterministas

| Código | HTTP | Causa |
|---|---:|---|
| `UNAUTHENTICATED` | 401 | Falta sesión autenticada en entorno real o bypass no habilitado |
| `FORBIDDEN_ROLE` | 403 | Token sin Custom Claims firmados de instructor/admin |
| `FORBIDDEN_CLIENT_POLICY_OVERRIDE` | 403 | El payload intentó fijar proveedor, modelo, cuota, presupuesto o permisos |
| `INVALID_REQUEST` | 400 | Parámetros inválidos o intento de aplicar `adulto_fiu` a Infantil/Mixto |
| `INVALID_REQUIRED_MOVEMENT` | 400 | Movimiento FIU obligatorio inexistente, excluido (`ai_planner_eligible=false`) o fuera de scope |
| `INVALID_OR_UNAUTHORIZED_REQUIRED_RESOURCE` | 404 | Recurso Pizarra obligatorio inexistente o inaccesible |
| `UNAUTHORIZED_RESOURCE` | 403 | Recurso Pizarra perteneciente a otro instructor no compartido |
| `QUOTA_EXCEEDED` | 429 | Límite diario (`20`) o por minuto (`4`) alcanzado |
| `CONCURRENT_REQUEST_IN_PROGRESS` | 409 | Solicitud concurrente en vuelo con el mismo `request_id` |
| `REAL_PROVIDER_DISABLED` | 503 | Proveedor OpenAI real deshabilitado (`PED-04C2-B`) |
| `PROVIDER_TIMEOUT` | 504 | Timeout de llamada al proveedor LLM |
| `PROVIDER_TRUNCATED_OUTPUT` | 502 | JSON truncado o malformado (`finish_reason=length`) |
| `PROVIDER_REJECTED` | 502/422 | Error HTTP o rechazo del modelo proveedor |
| `VALIDATION_FAILED_AFTER_REPAIR` | 422 | Fallo estructural persistente tras `<= 1` intento de reparación |
| `CATALOG_INTEGRITY_ERROR` | 500 | Error de lectura o divergencia de hash SHA-256 del catálogo FIU |

---

## 6. Referencia de Cordas Oficiales Adulto FIU (Verificadas en `data/curriculum/fiu_adulto_v1.json`)

| Índice | `corda_id` | Nombre oficial en manual (`nombre_manual`) | Extraída V1 |
|---:|---|---|---|
| 1 | `adulto_corda_01` | `Corda Crua` | Sí (19 movs) |
| 2 | `adulto_corda_02` | `Corda Crua e Verde` | Sí (+12 movs) |
| 3 | `adulto_corda_03` | `Corda Verde` | Sí (+17 movs) |
| 4 | `adulto_corda_04` | `Corda Verde e Laranja` | Sí (+24 movs) |
| 5 | `adulto_corda_05` | `Corda Laranja` *(bloque `adulto_bloque_05_06`)* | Sí (+25 movs) |
| 6 | `adulto_corda_06` | `Corda Laranja e Amarelo` *(bloque `adulto_bloque_05_06`)* | Sí *(evaluación y musicalidad diferenciadas)* |
