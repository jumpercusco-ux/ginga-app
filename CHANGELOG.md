# Historial de Cambios (CHANGELOG)

Todas las modificaciones notables del proyecto GINGA se documentan cronológicamente en este archivo.

Las entradas se clasifican rigurosamente según su estado de despliegue:
- **[PUBLICADO EN PRODUCCIÓN]:** Desplegado y activo en Google Cloud Functions o Firebase Console.
- **[PROBADO LOCALMENTE]:** Verificado exhaustivamente con suites de pruebas locales aisladas; no desplegado.
- **[IMPLEMENTADO]:** Escrito en código o documentación local pendiente de pruebas o despliegue.

---

## [PED-04C3] — 2026-11-27
### [COPILOTO CONVERSACIONAL PEDAGÓGICO INTEGRADO EN EDITOR V2 Y VERIFICADO OFFLINE EN `feat/ped03-biblioteca-curricular` · CERO LLAMADAS PAGADAS · PRODUCCIÓN INTACTA]
- **Backend Modular del Copiloto y Transporte Local (`functions/planner_v2/` + `scripts/planner_v2_local_server.js`):**
  - Nuevos módulos [copilot_schema.js](file:///Users/jumper/ginga_app/functions/planner_v2/copilot_schema.js) (`OPENAI_STRICT_COPILOT_V1_JSON_SCHEMA`, 10 operaciones tipadas y `computeDraftVersionHash`), [copilot_operations.js](file:///Users/jumper/ginga_app/functions/planner_v2/copilot_operations.js) (`applyCopilotOperationsToPlan`, `redistribute_duration` exacta, guardia FIU infantil/mixto y honestidad de video externo), [copilot_context_and_prompt.js](file:///Users/jumper/ginga_app/functions/planner_v2/copilot_context_and_prompt.js), [copilot_simulated_provider.js](file:///Users/jumper/ginga_app/functions/planner_v2/copilot_simulated_provider.js) y [copilot_engine.js](file:///Users/jumper/ginga_app/functions/planner_v2/copilot_engine.js) (compuerta `validateGeneratedPlan`, detección `409 DRAFT_VERSION_CONFLICT`, cuotas, idempotencia y presupuesto independiente en `scratch/copilot_ped04c3_budget_state.json`), exportados en [functions/planner_v2/index.js](file:///Users/jumper/ginga_app/functions/planner_v2/index.js) y [context_builder.js](file:///Users/jumper/ginga_app/functions/planner_v2/context_builder.js).
  - Endpoint `POST /api/planner-v2/copilot` (offline simulado por defecto salvo `--enable-real-copilot-openai`) y campo `copilot_budget` en `/api/planner-v2/health` dentro de [planner_v2_local_server.js](file:///Users/jumper/ginga_app/scripts/planner_v2_local_server.js), conservando intacto el presupuesto `8/8` (`$0.020187 / $0.10`, `28` llamadas).
- **Integración Flutter en el Editor Pedagógico V2 (`lib/features/instructor/planificador/`):**
  - Modelos, cliente y aplicador determinista en [copilot_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/copilot_models.dart), [copilot_operation_applier.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/copilot_operation_applier.dart) (`computeDraftVersion` 4x32-bit VM/Web) y [planner_copilot_client.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_copilot_client.dart).
  - Panel adaptable [planner_copilot_panel.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_copilot_panel.dart) integrado en [planner_class_editor_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_class_editor_view.dart) y [planner_hub_body.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_hub_body.dart): lateral en escritorio (`>=1024px`) y hoja modal en tablet/móvil sin desbordamientos, comparación antes/después, aprobación explícita (`Aplicar cambios` / `Descartar`), `Deshacer IA` y conservación del texto/borrador ante errores.
  - Escenario demo `Copiloto · Infantil 8/8` (`InMemoryPlannerDataSource.copilotDemoFixtures`) en [planner_data_source.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_data_source.dart) y [main_planificador_preview.dart](file:///Users/jumper/ginga_app/lib/main_planificador_preview.dart), preservando `demoFixtures()` original de 3 planes.
- **Pruebas Automatizadas, Preview y CI:**
  - Nueva suite [test_planner_v2_copilot_ped04c3.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_copilot_ped04c3.js) (**`10/10 PASS`**) integrada en [.github/workflows/ci.yml](file:///Users/jumper/ginga_app/.github/workflows/ci.yml), junto a todas las suites Node existentes en verde, `flutter analyze --no-fatal-warnings --no-fatal-infos` (exit `0`), `flutter test` (**`81/81 All tests passed!`** incluyendo [planificador_v2_copilot_test.dart](file:///Users/jumper/ginga_app/test/planificador_v2_copilot_test.dart)) y compilación web aislada `/tmp/ginga_ped04c2d_8097` para puerto `8097`.

---

## [PED-04C2-E] — 2026-11-26
### [CALIDAD PEDAGÓGICA EN CAPOEIRA CONSOLIDADA Y VALIDADA EN PILOTO REAL `8/8` EN `feat/ped03-biblioteca-curricular` · PRODUCCIÓN INTACTA]
- **Especialización en Capoeira, Participación Simultánea y Reparación Anti-Regresión (`functions/planner_v2/`):**
  - [context_builder.js](file:///Users/jumper/ginga_app/functions/planner_v2/context_builder.js) y [temporal_planner.js](file:///Users/jumper/ginga_app/functions/planner_v2/temporal_planner.js): extracción de movimientos técnicos solicitados y detección de participación simultánea; arquitectura de 5 bloques equilibrados (`10+16+12+11+11=60 min`) reservando `Técnica y progresiones` separado de `Juegos de capoeira` en Infantil; pre-cálculo de `min_internal_stages` / `suggested_stage_minutes`; enrutamiento de `idea_res_02` a `blk_3` (`Juegos de capoeira`).
  - [config.js](file:///Users/jumper/ginga_app/functions/planner_v2/config.js), [response_schema.js](file:///Users/jumper/ginga_app/functions/planner_v2/response_schema.js), [block_assembler.js](file:///Users/jumper/ginga_app/functions/planner_v2/block_assembler.js) y [pilot_budget_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/pilot_budget_guard.js): `blockMaxOutputTokens: 2000`, `ORGANIZATION_MODE_ENUM`, separación `sugerencias_ia` / `observaciones_profesor`, `technical_movement_refs`, etiquetas legibles por bloque y anotaciones descriptivas estrictas (`strict: true`, `1,958` chars).
  - [plan_validator.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_validator.js), [prompt_builder.js](file:///Users/jumper/ginga_app/functions/planner_v2/prompt_builder.js), [plan_repairer.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_repairer.js) y [simulated_provider.js](file:///Users/jumper/ginga_app/functions/planner_v2/simulated_provider.js): reglas deterministas para Capoeira real, simultaneidad, `TRIVIAL_INTERNAL_TIMINGS`, piso/instrumentos y `NON_EXECUTABLE_MUSICALITY` con diagnóstico exacto de dimensión faltante, prompts de reparación dirigidos por error y guarda `preserveValidExercisesOnBlockRepair`.
- **Refinamientos en Editor Flutter V2 y Cliente (`lib/features/instructor/planificador/`):**
  - Edición estructurada de `tiempos_internos`, separación `Sugerencias IA` vs. `Observaciones del profesor`, `technical_movement_refs` editables en Infantil (con Adulto FIU bloqueado) en [class_plan_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/class_plan_models.dart), [class_plan_editor_operations.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/class_plan_editor_operations.dart), [planner_exercise_editor_panel.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_exercise_editor_panel.dart), [planner_class_editor_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_class_editor_view.dart) y [planner_live_class_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_live_class_view.dart); timeout `HttpLocalPlannerV2Client` ampliado a `180s` en [planner_v2_engine_client.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_v2_engine_client.dart).
- **Validación Real (`gpt-4o-mini`, `7/8` -> `8/8`) y Pruebas Completas + CI:**
  - Tras diagnosticar en `7/8` (`$0.004265`) `TRIVIAL_INTERNAL_TIMINGS` + `NON_EXECUTABLE_MUSICALITY`, el intento **`8/8`** (`Infantil M/J 18:00`, Opción B) generó una clase completa aprobada (`PASS`, **`92/100`** heurístico) en **`41,047 ms`**, **`5` bloques (`60 min`)**, **`9` ejercicios**, **`6` llamadas** (`1` reparación en `blk_3`), **`$0.004032` USD**; gasto total del piloto detenido en **`$0.020187 / $0.10` USD** (`8/8`, `28` llamadas, **`$0.079813` restantes**).
  - Nueva suite [test_planner_v2_pedagogical_quality_ped04c2e.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_pedagogical_quality_ped04c2e.js) integrada en [.github/workflows/ci.yml](file:///Users/jumper/ginga_app/.github/workflows/ci.yml), junto a todas las suites Node (`PASS`), `flutter analyze --no-fatal-warnings --no-fatal-infos` (`exit 0`) y `flutter test` (**`76/76 All tests passed!`**).

---

## [PED-04C2-D] — 2026-11-26
### [ESTABILIZACIÓN MODULAR Y PILOTO REAL LOCAL VERIFICADOS EN `feat/ped03-biblioteca-curricular` · PRODUCCIÓN INTACTA]
- **Arquitectura Modular por Bloques y Control Estricto de Presupuesto (`PED-04C2-D`):**
  - **Esqueleto Determinista + Esquema Slim + Ensamblado en Código:** Ampliación de [temporal_planner.js](file:///Users/jumper/ginga_app/functions/planner_v2/temporal_planner.js) y [context_builder.js](file:///Users/jumper/ginga_app/functions/planner_v2/context_builder.js) con pre-asignación determinista de recursos y movimientos por slot; incorporación de `OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA` en [response_schema.js](file:///Users/jumper/ginga_app/functions/planner_v2/response_schema.js) (`1,566` chars vs `3,858` monolíticos) y [block_assembler.js](file:///Users/jumper/ginga_app/functions/planner_v2/block_assembler.js); prompts compactos por bloque en [prompt_builder.js](file:///Users/jumper/ginga_app/functions/planner_v2/prompt_builder.js) (`879–950` tokens est. vs `3,537` monolíticos).
  - **Orquestación en Oleadas, Reparación Acotada y Guardia Atómica:** Actualización de [index.js](file:///Users/jumper/ginga_app/functions/planner_v2/index.js), [config.js](file:///Users/jumper/ginga_app/functions/planner_v2/config.js), [llm_adapter.js](file:///Users/jumper/ginga_app/functions/planner_v2/llm_adapter.js) (probe `GET /v1/models` y fallback ante `MODEL_ACCESS_DENIED`), [plan_repairer.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_repairer.js) (oleadas paralelas, reparación en 1 pase solo de bloques fallidos y corrección de reporte `repair_attempts_used`), [plan_validator.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_validator.js) (regla de juegos en 3 dimensiones ejecutables sin palabras clave solapadas), [pilot_budget_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/pilot_budget_guard.js) (persistencia en disco y reserva multi-bloque), [auth_and_quota_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/auth_and_quota_guard.js) (`FirestoreTransactionQuotaStore`) y [callable_handler.js](file:///Users/jumper/ginga_app/functions/planner_v2/callable_handler.js).
  - **Transporte Flutter, Recuperación Directa y Servidor Local:** Eliminación de reintentos automáticos silenciosos ante `504` y timeout `120s` en [planner_v2_engine_client.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_v2_engine_client.dart); endpoint `/api/planner-v2/last-status` + progreso en [planner_v2_local_server.js](file:///Users/jumper/ginga_app/scripts/planner_v2_local_server.js); banner **«Abrir en Editor»** en [planner_hub_body.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_hub_body.dart) sin nuevas llamadas pagadas.
  - **Resultado del Piloto Real Local (`gpt-4o-mini`, intento `6/8`):** Generada la clase `Infantil M/J 18:00 · Técnicas · Juegos · Acrobacias · Musicalidad (60 min)` en **`21,494 ms`**, **`4` bloques (`12 + 26 + 11 + 11 = 60 min`)**, **`8` ejercicios**, **`4` llamadas** (`repairs=0`), costo **`$0.002063` USD**, recurso obligatorio `idea_res_02` integrado, `0` FIU adultos, `"Marinheiro só"` con `cantiga_id: null`, validación estructural **`PASS`** (`88/100` heurístico + revalidación positiva bajo regla endurecida de 3 dimensiones). Acumulado final detenido en **`$0.01189 / $0.10` USD** (`6/8` generaciones, **`$0.08811` USD restantes**, `15` llamadas). Evaluación humana en tatami pendiente.
  - **Pruebas Completas y CI:** Añadidas al pipeline [.github/workflows/ci.yml](file:///Users/jumper/ginga_app/.github/workflows/ci.yml) las suites [test_planner_v2_modular_stabilization.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_modular_stabilization.js), [test_planner_v2_pilot_and_budget.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_pilot_and_budget.js) y [test_planner_v2_structural_engine.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_structural_engine.js); todas en verde junto a `validate_curriculum_catalog.js`, `verify_planner_v2_catalog_sync.js`, `test_curriculum_importer.js` (`6/6`), `test_planner_v2_quality.js` (`6/6 + 20/20`), `test_planner_v2_local_server_e2e.js`, `test_reservation_date_semantics.js` (`8/8`), `test_agent_evaluations.js` (`9/9`), `flutter analyze --no-fatal-warnings --no-fatal-infos` y `flutter test` (**`75/75 All tests passed!`**).

---

## [PED-04C2-C] — 2026-11-26
### [INTEGRADO Y PROBADO EN MODO SIMULADO OFFLINE EN RAMA `feat/ped03-biblioteca-curricular` · PROVEEDOR REAL DESHABILITADO]
- **Integración Completa del Motor V2 en el Planificador Flutter (`PED-04C2-C`):**
  - **Contratos y Cliente HTTP Aislado:** Ampliación de [class_plan_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/class_plan_models.dart) (`PlannerSpaceContext`, `PlannerSongReference`, `PlannerGenerationMeta`, `sourceOrigins`, `activityAuthoring`, no-suposición de materiales/piso/colchonetas desconocidos y serialización `toPlannerV2RequestMap()`) + creación de [planner_v2_engine_client.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_v2_engine_client.dart) (`HttpLocalPlannerV2Client`, `PlannerV2ResponseAdapter` con reintento automático único sobre fallos transitorios preservando `request_id`).
  - **UI Conectada sin Duplicación ni Regresiones:** Conexión real en [planner_quick_create_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_quick_create_view.dart), [planner_advanced_create_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_advanced_create_view.dart), [planner_hub_body.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_hub_body.dart), [planner_class_editor_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_class_editor_view.dart) e [instructor_pizarra_screen.dart](file:///Users/jumper/ginga_app/lib/features/instructor/instructor_pizarra_screen.dart) conservando estado completo ante errores, abriendo automáticamente el Editor V2 tras generar, mostrando banner honesto de modo simulado y badge de referencias al cancionero (`cantiga_id: null`), sin marcar recursos como usados al generar o guardar borradores.
  - **Servidor Local Seguro + Guía `PED-04C2-D`:** Creación de [planner_v2_local_server.js](file:///Users/jumper/ginga_app/scripts/planner_v2_local_server.js) (`/api/planner-v2/health`, `/api/planner-v2/generate`, `/flutter_service_worker.js -> 404`, bloqueo obligatorio `--token <PIN>` en LAN no-loopback) + [test_planner_v2_local_server_e2e.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_local_server_e2e.js) integrado en [.github/workflows/ci.yml](file:///Users/jumper/ginga_app/.github/workflows/ci.yml), selector de escenarios `Infantil M/J 18:00` y `Adultos M/J 19:00` en [main_planificador_preview.dart](file:///Users/jumper/ginga_app/lib/main_planificador_preview.dart) y guía [PED04C2D_PREPARATION_AND_TABLET_PREVIEW.md](file:///Users/jumper/ginga_app/docs/PED04C2D_PREPARATION_AND_TABLET_PREVIEW.md).
  - **Pruebas y Preview Puerto `8097`:** `flutter analyze` (`No issues found!`), `flutter test` (**`73/73 All tests passed!`** incluyendo [planificador_v2_integration_test.dart](file:///Users/jumper/ginga_app/test/planificador_v2_integration_test.dart)), todas las suites Node incluyendo `test_planner_v2_local_server_e2e.js` en verde y preview vivo en `http://127.0.0.1:8097/`.

---

## [PED-04C2-B] — 2026-11-26
### [IMPLEMENTADO Y PROBADO LOCALMENTE EN RAMA `feat/ped03-biblioteca-curricular` · PROVEEDOR REAL DESHABILITADO]
- **Motor de Inteligencia Pedagógica Offline V2 (`functions/planner_v2/`):**
  - **Catálogo Verificado e Integridad CI:** Empaquetado de `functions/planner_v2/data/fiu_adulto_v1.json` + manifiesto `fiu_adulto_v1.sha256.json` (`0a4b223770e468330b7ba9af74026bca3c6b935b43da2bec969a49f9f0a2c923`) y verificador [verify_planner_v2_catalog_sync.js](file:///Users/jumper/ginga_app/scripts/verify_planner_v2_catalog_sync.js) (`97` movimientos, `94` elegibles IA, `3` excluidos).
  - **Arquitectura Modular (14 módulos en [functions/planner_v2/index.js](file:///Users/jumper/ginga_app/functions/planner_v2/index.js)):** `config.js` (tope escalado `4500` tokens hasta `60 min` / `5600` tokens para `>60 min`), `errors.js`, `curriculum_catalog_loader.js`, `auth_and_quota_guard.js` (Custom Claims + cuota atómica `20/día`, `4/min` e idempotencia por `request_id`), `pii_and_injection_guard.js` (sanitización heurística con disclaimer explícito + zero IDs internos/URLs en `llmPayloadContext`), `context_builder.js` (bloqueo de overrides cliente, rechazo explícito de obligatorios inválidos/ajenos, no-suposición de tatami/colchonetas/materiales, `instructors_available`), `prompt_builder.js` (estructura flexible sin plantilla fija, desglose exacto de sub-tiempos, varios ejercicios breves en Infantil, progresiones técnicas independientes previas a combinar, bloqueo de `Bananeira`/inversiones sin condiciones explícitas, reglas Infantil/Mixto/Adultos y precedencia de orígenes), `response_schema.js` (`v2.1.0` + `cancionero_reference` sin IDs inventados), `llm_adapter.js` (deshabilitado con `REAL_PROVIDER_DISABLED`), `simulated_provider.js`, `plan_validator.js` (validación estructural separada de rúbrica heurística), `plan_repairer.js` (Nivel 1 estrictamente no semántico + Nivel 2 máx. `1` intento) y `telemetry.js` Zero-PII.
  - **Contratos y Benchmark CI:** Documentación en [docs/PLANNER_V2_ENGINE_CONTRACT.md](file:///Users/jumper/ginga_app/docs/PLANNER_V2_ENGINE_CONTRACT.md), suite [test_planner_v2_quality.js](file:///Users/jumper/ginga_app/real_agent_harness/test_planner_v2_quality.js) (**`6/6` Infraestructura + `20/20` Escenarios Golden estructurales + promedio heurístico offline `93.9/100` sobre `17` planes excluyendo `3` errores esperados**), integrada en [.github/workflows/ci.yml](file:///Users/jumper/ginga_app/.github/workflows/ci.yml). Sin cambios en `functions/index.js`, Flutter ni Firestore productivo.

---

## [PED-04C1] — 2026-11-26
### [CERRADO TÉCNICAMENTE Y RESPALDADO EN RAMA `feat/ped03-biblioteca-curricular` · PROBADO LOCALMENTE]
- **Ejecución de Clases en Vivo V2 Integrada (`PED-04C1`):**
  - **Modelos y Recuperación Local:** Creación de [live_session_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/live_session_models.dart) (`LiveSessionState`, `LiveExerciseExecution`, `LiveExerciseStatus`, `LiveSessionClosureInput`) con temporizador por reloj de pared resistente al segundo plano, compatibilidad V1/V2, `planSnapshot` inmutable y [live_session_persistence.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/live_session_persistence.dart) (`SharedPreferencesLiveSessionStorage` + `InMemoryLiveSessionStorage`).
  - **Interfaz en Vivo y Formulario de Cierre:** Implementación de [planner_live_class_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_live_class_view.dart) (`WidgetsBindingObserver`, `PlannerPalette` claro/oscuro, stepper de bloques, reloj grande táctil, `-1 m` / `+1 m` / `Reiniciar`, opción `Ver todos los niveles` para consultar simultáneamente Principiantes/Intermedios/Avanzados, advertencia con confirmación manual al completar en `00:00`, consulta de movimientos FIU vía `MovimientoDetalleScreen` y visor de recursos sin perder estado) y [planner_live_closure_sheet.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_live_closure_sheet.dart) para cierre completo o anticipado con campo de continuidad limpio (sin texto residual + botón opcional de sugerencia).
  - **Historial, Continuidad Estructurada, Sanitización Zero-PII e Idempotencia:** Extensión de `TaughtSessionRecord`, `PedagogicalContinuityContext`, `PlannerPiiSanitizer` (redacción de nombres, teléfonos, correos, fechas e IDs en texto libre en `toAiSafeRequestMap()`/`toAiSafeMap()`) y `PlannerResourceItem.copyWith` en [class_plan_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/class_plan_models.dart), `recordCompletedLiveSession` en [planner_data_source.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_data_source.dart) (solo ejercicios completados, guardia `_recordedSessionIds`, actualización de `ultimaEjecucion`/`vecesImpartida` sin alterar contenido pedagógico, cero escrituras en Firestore productivo), `PlannerContinuityContextCard` expandible en [planner_shared_widgets.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_shared_widgets.dart) integrado con aislamiento estricto por grupo en [planner_hub_body.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_hub_body.dart), [planner_quick_create_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_quick_create_view.dart), [planner_advanced_create_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_advanced_create_view.dart), [planner_class_editor_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_class_editor_view.dart), [instructor_pizarra_screen.dart](file:///Users/jumper/ginga_app/lib/features/instructor/instructor_pizarra_screen.dart) y [main_planificador_preview.dart](file:///Users/jumper/ginga_app/lib/main_planificador_preview.dart).
  - **Validación y Preview Puerto `8097`:** `flutter analyze` limpio (`No issues found!`), `flutter test` (**`69/69 All tests passed!`** con [planificador_v2_live_test.dart](file:///Users/jumper/ginga_app/test/planificador_v2_live_test.dart) y [ped04c1_screenshot_capture_test.dart](file:///Users/jumper/ginga_app/test/ped04c1_screenshot_capture_test.dart)), suites Node en verde (`PASS` catálogo, `6/6` importador, `8/8` fechas, `9/9` evaluaciones), capturas reales claro/oscuro en escritorio/tablet/móvil y preview actualizado en `http://127.0.0.1:8097/`.

---

## [PED-04B2-UX] — 2026-11-26
### [CERRADO TÉCNICAMENTE EN RAMA `feat/ped03-biblioteca-curricular` · PROBADO LOCALMENTE]
- **Refinamiento UX y Cierre Técnico del Editor Pedagógico V2 (`PED-04B2-UX` / `PED-04B2-CLOSE`):**
  - **Distribución y Campos Legibles:** Proporción 60/40 en escritorio (`>=1200px`), tarjetas a ancho completo, tokens `inputFill`/`inputBorder` en [planner_palette.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/theme/planner_palette.dart), `PlannerFieldLabel` + `plannerInputDecoration` en [planner_shared_widgets.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_shared_widgets.dart) evitando etiquetas flotantes recortadas, y tooltips completos en bloques y ejercicios.
  - **Variantes, Organización y Recursos:** Variantes separadas en `Principiantes`, `Intermedios` (`differentiationIntermediate`) y `Avanzados`; 5 opciones de organización pedagógica (`kPlannerOrganizationOptions`); vinculación múltiple de movimientos FIU y recursos de Pizarra abribles con notas de uso particulares (`resourceUsageNotes`) sin sobrescribir el origen del ejercicio ni marcar recursos como usados; y relación explícita bloque vs. suma de ejercicios.
  - **Validación, Aprobación Manual y Preview Puerto `8097`:** Verificado manualmente por el propietario en `http://127.0.0.1:8097/` (conservación de duración `20 min`, organización `Todos simultáneamente`, movimientos FIU y variantes al guardar, volver al Hub y reabrir), `flutter analyze` limpio (`No issues found!`), `flutter test` (**`59/59 All tests passed!`**), suites Node de catálogo/importador/agente en verde, y preview aislado sin service worker (`--pwa-strategy=none`, `Cache-Control: no-store`) activo en `http://127.0.0.1:8097/`.

---

## [PED-04B2] — 2026-11-26
### [CERRADO TÉCNICAMENTE EN RAMA `feat/ped03-biblioteca-curricular` · PROBADO LOCALMENTE]
- **Editor Pedagógico de Clases V2 (`PED-04B2`):**
  - **Modelos y Operaciones Inmutables:** Ampliación de `ClassPlanExercise`, `ClassPlanBlock` y `ClassPlanModel` en [class_plan_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/class_plan_models.dart) (11 campos pedagógicos por ejercicio, compatibilidad V1/V2, `toMap()` libre de PII, `ClassPlanModel.emptyManual`), creación de [class_plan_editor_operations.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/class_plan_editor_operations.dart) (`ClassPlanEditorOperations`, `ClassPlanTimingSummary`) y actualización de [planner_data_source.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_data_source.dart) sin escrituras en producción.
  - **Editor Contextual y Control de Tiempos:** Implementación de [planner_class_editor_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_class_editor_view.dart) y [planner_exercise_editor_panel.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_exercise_editor_panel.dart) con barra permanente de control de tiempos, bloques expandibles, edición lateral en escritorio y modal en tablet/móvil, selector curricular FIU vía `CurriculumSelectionContract` bloqueado para Infantil/Mixto, selector de recursos de Pizarra (`Video`, `Imagen`, `Enlace`, `Nota`) sin marcar uso y conexión con [planner_hub_body.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_hub_body.dart), [planner_shared_widgets.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_shared_widgets.dart), [instructor_pizarra_screen.dart](file:///Users/jumper/ginga_app/lib/features/instructor/instructor_pizarra_screen.dart) y [main_planificador_preview.dart](file:///Users/jumper/ginga_app/lib/main_planificador_preview.dart).
  - **Validación, Capturas y Preview Puerto `8097`:** `flutter analyze` limpio sobre los 15 archivos del frente (`No issues found!`), `flutter test` (**`58/58 All tests passed!`** con [planificador_v2_editor_test.dart](file:///Users/jumper/ginga_app/test/planificador_v2_editor_test.dart) y [ped04b2_screenshot_capture_test.dart](file:///Users/jumper/ginga_app/test/ped04b2_screenshot_capture_test.dart)), validación de catálogo/importador (`6/6 PASS`) y preview aislado compilado sin service worker (`--pwa-strategy=none`) en `http://127.0.0.1:8097/`.

---

## [PED-04B1] — 2026-11-26
### [RESPALDADO EN RAMA `feat/ped03-biblioteca-curricular` · PROBADO LOCALMENTE]
- **Planificador Pedagógico GINGA V2 — Interfaz, Contratos y Preview Aislado (`PED-04A` / `PED-04B1` / `PED-04B1-FINAL` / `PED-04B1-CLOSE`):**
  - **Modelos y Datos Desacoplados:** Implementación de [class_plan_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/class_plan_models.dart), [planner_data_source.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_data_source.dart) y [planner_palette.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/theme/planner_palette.dart) con hidratación retrocompatible de planes V1 (`isLegacyV1`), `kPlannerFocusOptions` (`Técnica`, `Juegos`, `Acrobacias`, `Musicalidad`, `Secuencias`, `Roda`), validación de distribución de experiencia (`isExperienceDistributionValid`), `usageNote` por recurso, `ResourceMediaKind` (`Video`, `Imagen`, `Enlace`, `Nota`), `PlanCopilotRequest`, contrato `toAiSafeRequestMap()` libre de PII y bloqueo automático de fallback Adulto FIU para Infantil/Mixto.
  - **Pantallas Unificadas en `InstructorPizarraScreen`:** Evolución de [instructor_pizarra_screen.dart](file:///Users/jumper/ginga_app/lib/features/instructor/instructor_pizarra_screen.dart) integrando [planner_hub_body.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_hub_body.dart), [planner_quick_create_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_quick_create_view.dart), [planner_advanced_create_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_advanced_create_view.dart) y [planner_shared_widgets.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_shared_widgets.dart) preservando los flujos heredados (`_ModalIdea`, `_GeneradorClaseModal`, `_ClaseEnVivoScreen`) y el tema global [ginga_theme.dart](file:///Users/jumper/ginga_app/lib/core/theme/ginga_theme.dart).
  - **Cierre Visual y Honestidad No-IA (`PED-04B1-FINAL` / `PED-04B1-CLOSE`):** Tarjetas alineadas con última fecha de ejecución, buscador de planes y `Editar plan` (ocultando etiquetas técnicas); múltiples enfoques simultáneos, `¿Qué quieres trabajar hoy?` y conservación rápida↔avanzada; Pizarra con `Añadir recurso`, miniaturas, filtros organizados y planificación sin marcar recursos como usados; Historial con filtros grupo/fecha, detalle de sesión, movimientos practicados, continuidad y disclaimer de fixtures; borradores locales marcados honestamente con `Borrador local sin generación IA` y sin etiqueta `Propuesta IA`.
  - **Validación y Preview Puerto `8097`:** `flutter analyze` (`No issues found!`), `flutter test` (**`47/47 All tests passed!`** con [planificador_v2_test.dart](file:///Users/jumper/ginga_app/test/planificador_v2_test.dart) y [ped04b1_screenshot_capture_test.dart](file:///Users/jumper/ginga_app/test/ped04b1_screenshot_capture_test.dart)) y preview web aislado en [main_planificador_preview.dart](file:///Users/jumper/ginga_app/lib/main_planificador_preview.dart) compilado sin service worker (`--pwa-strategy=none`) activo en `http://127.0.0.1:8097/`.

---

## [PED-03C-CI] — 2026-11-24
### [RESPALDADO EN RAMA `feat/ped03-biblioteca-curricular` · CI VERDE]
- **Cierre técnico y determinismo de CI (`1b9729e` sobre `613cefe`):**
  - Reproducido el fallo temporal preexistente de `real_agent_harness/test_reservation_date_semantics.js` sobre el commit base `fd891a7` (`7/8`, caso `08_validar_fecha_solicitada_preserva_fecha_civil_sin_desfases` con fecha hardcodeada `'2026-11-17'` vencida al `2026-11-24`).
  - Corregido únicamente [test_reservation_date_semantics.js](file:///Users/jumper/ginga_app/real_agent_harness/test_reservation_date_semantics.js) mediante reloj controlado `withFrozenClock` anclado en `America/Lima` (`2026-11-12T15:00:00.000Z` y verificación de cruce de medianoche UTC `2026-11-13T00:30:00.000Z`), preservando las 8 pruebas sin modificar `functions/index.js` ni lógica de reservas/WhatsApp.
  - Verificación completa: `test_reservation_date_semantics.js` (`8/8 PASS` en `default`, `TZ=UTC` y `TZ=America/Lima`), `test_agent_evaluations.js` (`9/9 PASS`), Firestore Emulator JDK 21 (`test_firestore_rules.js` `9/9 PASS` + `test_curriculum_firestore_rules.js` `7/7 PASS`), `flutter test` (`35/35 PASS`) y GitHub Actions [run #45475260519](https://github.com/jumpercusco-ux/ginga-app/actions/runs/45475260519) (`Flutter Web & Unit Tests` = `success`, `Node.js 22 & Agent Quality Benchmark` = `success`).

---

## [PED-01..PED-03C] — 2026-11-24
### [RESPALDADO EN RAMA `feat/ped03-biblioteca-curricular` (`613cefe`, 29 ARCHIVOS)]
- **Base Curricular Oficial FIU (`PED-02` / `PED-03A`):**
  - Consolidación de [data/curriculum/fiu_adulto_v1.json](file:///Users/jumper/ginga_app/data/curriculum/fiu_adulto_v1.json) (`97` movimientos canónicos en Adulto Cordas `1–6`: `94` elegibles IA y `3` excluidos por revisión técnica; `1` bloque compartido `adulto_bloque_05_06`; `12` cordas infantiles en metadata; `21` tutoriales mapeados preservando los `5` videos reales; `26` términos de glosario) y guía de revisión [docs/CURRICULUM_FIU_ADULTO_V1_REVIEW.md](file:///Users/jumper/ginga_app/docs/CURRICULUM_FIU_ADULTO_V1_REVIEW.md).
  - Modelos tipados y repositorio ([curriculum_models.dart](file:///Users/jumper/ginga_app/lib/core/models/curriculum_models.dart), [curriculum_repository.dart](file:///Users/jumper/ginga_app/lib/core/services/curriculum_repository.dart)), deprecación segura de `TutorialesService.inicializarTutorialesMockupSiVacia` (`legacyMockSeedEnabled = false`), índices ([firestore.indexes.json](file:///Users/jumper/ginga_app/firestore.indexes.json)) y endurecimiento de [firestore.rules](file:///Users/jumper/ginga_app/firestore.rules) para exigir Custom Claims firmados en colecciones `curriculum_*` y prohibir borrado.
- **Evolución Unificada de la Biblioteca + UX Final (`PED-03B` / `PED-03B-V` / `PED-03B-UX` / `PED-03B-FINAL`):**
  - Evolución de [biblioteca_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/biblioteca_screen.dart), [curriculo_biblioteca_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/curriculo_biblioteca_screen.dart), [movimiento_detalle_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/movimiento_detalle_screen.dart), [glosario_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/glosario_screen.dart), [biblioteca_user_context.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/widgets/biblioteca_user_context.dart) y rutas en [app_router.dart](file:///Users/jumper/ginga_app/lib/core/router/app_router.dart).
  - Separación estricta entre `rol` y graduación personal; conservación íntegra de `GingaTheme` claro/oscuro; tarjetas compactas con corda de introducción (`Desde Xª · Nombre`); filtro `Con video (N)` con recuperación `Mostrar todos`; navegación/filtros en `Wrap` sin recortes; dimensiones unificadas de botones; deduplicación visual de alias (`MovimientoDetallePanel.visibleAliasesForDisplay`); y contrato opt-in `CurriculumSelectionContract` + `CurriculumMovementSelectionItem` para `PED-04`.
  - Preview web aislado sin Firebase de producción en [main_biblioteca_preview.dart](file:///Users/jumper/ginga_app/lib/main_biblioteca_preview.dart) compilado sin Service Worker (`--pwa-strategy=none`) y validado a `945 × 930` y `1440 × 900` en claro y oscuro.
- **Validación Técnica y Emulator JDK 21 (`PED-03C`):**
  - Desbloqueo de Java 21 vía `/opt/homebrew/opt/openjdk@21` (`21.0.7`) sin alterar el JDK global del sistema.
  - Firebase Firestore Emulator (`--project demo-ginga-test`): `test_curriculum_firestore_rules.js` (`7/7 PASS`), `real_agent_harness/test_firestore_rules.js` (`9/9 PASS`) y `test_curriculum_importer.js` (`6/6 PASS`, verificando idempotencia de `164` documentos e integridad exacta de los `21` tutoriales y `5` videos reales).
  - Offline y Flutter: `validate_curriculum_catalog.js` (`PASS`), `test_curriculum_importer.js` `IN_MEMORY_MOCK` (`6/6 PASS`), `flutter analyze` en los `12` archivos curriculares/preview/test (`No issues found!`) y `flutter test` (**`35/35 All tests passed!`**).
  - Documentación actualizada de contrato (`docs/CURRICULUM_AI_PLANNER_CONTRACT.md` v1.1.0, requisitos Infantil para `PED-04`) y continuidad (`CURRENT-STATE.md`, `HANDOFF.md`, `DECISIONS.md`, `CHANGELOG.md`).

---

## [fd891a7] (`v1.0.0-feedback-v1`) — 2026-11-12
### [PUBLICADO EN PRODUCCIÓN / CI/CD] (Rama `main`)
- **Sincronización y Protección CI/CD ([DEPLOYMENT_AND_CICD.md](file:///Users/jumper/ginga_app/docs/DEPLOYMENT_AND_CICD.md)):**
  - Integración fast-forward a `main` (`fd891a7`) y publicación del tag `v1.0.0-feedback-v1`.
  - Eliminación del despliegue automático monolítico en push a `main` y segregación en `ci.yml`, `deploy-web.yml`, `deploy-functions.yml` y `deploy-firestore.yml` con confirmaciones manuales explícitas.
  - Estado productivo alineado: `whatsappWebhook v69` (Node.js 22), web `https://www.gingaperu.com` con auto-deploy desactivado en Vercel.

---

## [3058ada] — 2026-10-23
### [PUBLICADO EN PRODUCCIÓN] (Cloud Function `whatsappWebhook v67`)
- **Control de Asistencia en Vivo:** Implementación de resolución de leads y asistencia dentro del chat en `clase_detalle_screen.dart` y `functions/index.js`.
- **Integración WhatsApp Webhook:** Verificación de firma Meta, debounce de 5.0s y guardado de leads en `/whatsapp_leads`.
- **Function Calling Básico:** Definición de 4 herramientas iniciales (`consultar_horarios_disponibles`, `guardar_perfil_lead`, `reservar_clase_prueba`, `marcar_seguimiento_humano`).
- **Defectos Conocidos:** Amnesia de reservas en prompt, colisión en reprogramación de martes a jueves, bloqueo por duplicados en reservas canceladas o vencidas.
- **Tag Asociado:** `pre-live-original-2026-10-27` en rama `main`.

---

## [b1c3af6] — 2026-11-11
### [PROBADO LOCALMENTE] (Rama `fix/real-whatsapp-logic`)
- **Creación del Harness de Pruebas Aislado (`real_agent_harness/`):**
  - Implementación de `in_memory_firestore.js`: Emulación pura de colecciones, consultas compuestas, batches y transacciones Firestore.
  - Implementación de `openai_adapter.js`: Interceptor determinista offline de OpenAI y detector de confirmaciones falsas.
  - Implementación de `whatsapp_adapter.js`: Interceptor de salida para Meta Graph API.
  - Implementación de `loader.js`: Ejecución del archivo real `functions/index.js` en memoria mediante Node.js `vm.compileFunction` sin modificar archivos en disco.
  - Servidor interactivo web en `http://127.0.0.1:3333` (`server.js` + `public/index.html`).
- **Suite de Línea Base (`suite_runner.js`):**
  - Automatización de 9 escenarios que documentan formalmente los 7 defectos baseline de la versión `3058ada`.

---

## [9c53417] — 2026-11-11
### [PROBADO LOCALMENTE] (Rama `fix/real-whatsapp-logic`)
- **P0.1: Reconocimiento de Reservas Confirmadas:**
  - `generarSystemPrompt` recibe `leadId` y consulta acotadamente `/reservas` (`limit: 20`) filtrando por `status == 'confirmado'` y fechas vigentes en `America/Lima`.
  - Inyección del bloque `[RESERVAS CONFIRMADAS VIGENTES DE ESTE LEAD]` con reglas que prohíben pedir datos redundantes o volver a ofrecer agendar.
  - **Neutralidad de Género:** Formato descriptivo por nombre y grupo (`Asistente: [nombre]`) sin inferencias arbitrarias.
  - **Fail-Safe de Firestore:** Captura de excepciones con `try/catch` y aviso de seguridad que prohíbe reservas a ciegas si falla la base de datos.
  - **Protección de Reprogramación:** Prohibición explícita de dar confirmaciones de reprogramación de palabra sin ejecución de herramienta.
- **Suite P0.1 (`test_p01_recognition.js`):**
  - 14 de 14 pruebas automatizadas pasaron con éxito (Casos A hasta N).
  - El Caso 2 de la suite de línea base pasó de DEFECTO a FUNCIONA.

---

---

## [Release Readiness & QA Real 12/12] — 2026-11-11
### [PROBADO LOCALMENTE - GATE DE RELEASE APROBADO] (Rama `fix/real-whatsapp-logic`, HEAD `1197225`)
- **Validación Final de QA Conversacional Real OpenAI (`gpt-4o-mini`):**
  - **Evidencia del Cuarto QA Real Auditada:**
    - `runId`: `qa_run_1794446882861_tdvxf6`, modo `LIVE_REAL_OPENAI`.
    - Resultado: **12 de 12 escenarios PASS (100% éxito)**.
    - Llamadas y consumo: 11 turnos conversacionales reales evaluados con OpenAI + 1 escenario (12) de confirmación falsa inducida localmente para auditar la intercepción del Runtime Guard (29ms).
    - Solicitudes HTTP a OpenAI: 19 llamadas registradas (11 turnos + tool-calling loops).
    - Tokens y Costo auditado: 55,332 tokens de prompt, 613 tokens de completion, costo total estimado: **US$0.0087**.
    - Firewall de Red: 1 solicitud a Meta WhatsApp (`graph.facebook.com`) interceptada y bloqueada al 100%. 0 llamadas a Firestore productivo.
    - Base de Datos de Prueba: Firestore Emulator local (`127.0.0.1:8080`, `demo-ginga-test`).
    - Código de salida: 0 (éxito total).
- **Auditoría Remota de Solo Lectura Autorizada (Prompt 49, `capoeirafiu-ea8ljo`):**
  - **Cloud Function Productiva:** `whatsappWebhook`, Gen 1, región `us-central1`, runtime `nodejs20`, estado `ACTIVE`, versión `v67`, última actualización `2026-10-23T04:47:06Z`.
  - **Secrets en GCP:** Verificados en Secret Manager y vinculados a la función (`META_VERIFY_TOKEN` v2, `META_APP_SECRET` v1, `META_WHATSAPP_TOKEN` v2, `META_PHONE_NUMBER_ID` v1, `OPENAI_API_KEY` v1). `TELEMETRY_SALT` ausente en Secret Manager y env vars; opera con fallback efímero a `crypto.randomBytes(32)` por cold start sin interrumpir la ejecución.
  - **Configuración Comercial Firestore:** Sede oficial en Urb. Magisterio, Av. de la Cultura E-4 (Edificio Divergym, 3er piso); clases regulares Kids (Martes y Jueves 18:00–19:00, 5–12 años) y Adultos (Martes y Jueves 19:00–20:00, 13–99 años); mensualidad S/140, Promo 2x S/260. Se aclara que "Calle Hospital 840" y horarios 17:00–18:00 fueron exclusivamente fixtures sintéticos locales del emulador (`qa_openai_runner.js`), no datos de producción.
  - **Documento `config/whatsapp_agent`:** Confirmada existencia en Firestore (actualizado 2026-09-07T01:07:59Z); contenido no descargado ni inspeccionado para preservar integridad.
- **Auditoría de CI/CD y Riesgo de Despliegue Masivo:**
  - Se identificó que `.github/workflows/deploy.yml` despliega automáticamente todas las Cloud Functions (`--only functions`) si se hace push a `main`.
  - Se estableció la prohibición de despliegue masivo y se restringió el target estrictamente a `functions:whatsappWebhook` vía CLI selectivo bajo autorización.
- **Estrategia Realista de Rollback y Smoke Test Verificado:**
  - Identificación de plataforma: `whatsappWebhook` corre sobre Cloud Functions Gen 1, sin soporte nativo de división de tráfico por porcentaje entre revisiones. Rollback requiere re-despliegue (RTO estimado: 2 a 5 minutos).
  - Procedimiento de reversión preparado y aislado vía `git worktree` en `/private/tmp/ginga_rollback_baseline` sobre el tag `pre-live-original-2026-10-27` (commit `3058ada`, sin garantía de equivalencia binaria estricta con `v67`).
  - Smoke test adaptativo derivado de horarios reales de la sede Magisterio (martes y jueves), con contacto interno exclusivo y distinción clara entre intercepción protectora del Runtime Guard y fallas críticas.

---

## [1197225] — 2026-11-11
### [COMMIT LOCAL: 1197225] (Rama `fix/real-whatsapp-logic`)
- **Alineación de Conteos de Suites de Pruebas e Inventario JSDoc:**
  - Corrección de reporte en documentación: P1A (27/27 PASS) y P0.1 (14/14 PASS).
  - Inventario JSDoc completado en `test_p1a_runtime_guard.js` (casos 1 a 27).
  - Total validado: 123 pruebas de backend automatizadas + 12 dry-run = 135 verificaciones (100% PASS).

---

## [d9bb995] — 2026-11-11
### [COMMIT LOCAL: d9bb995] (Rama `fix/real-whatsapp-logic`)
- **Blindaje de Identidad, Reprogramación Inequívoca e Idempotencia Transaccional (Casos 1 y 3 tras Tercer QA Real OpenAI):**
  - **Evidencia del Tercer QA Real Auditada:**
    - `runId`: `qa_run_1794441642639_nog6ff`, modo `LIVE_REAL_OPENAI`.
    - Resultado: 10/12 PASS, 2 FAIL (Casos 1 y 3).
    - Costo real auditado: US$0.0086 (18 peticiones HTTP OpenAI, 11 turnos conversacionales).
    - Caso 4 ("Dos hijos") verificado 100% PASS en QA real con OpenAI tras la corrección anterior.
  - **Diagnóstico y Blindaje de Identidad en Caso 1 ("Reserva nueva"):**
    - *Evidencia:* Camila Rivera (`be2d8c6f5f758128`) solicitó: `"Hola, quiero agendar una clase de prueba de capoeira para mí (Camila Rivera, 22 años) para la próxima fecha disponible."`
    - *Causa:* La tool `guardar_perfil_lead` tenía en su descripción `"Nombre de pila real"`, llevando al modelo a pasar únicamente `"Camila"` en lugar de `"Camila Rivera"`. En consecuencia, la reserva se creó bajo el slug `"camila"` y no `"camila_rivera"`.
    - *Blindaje:* Implementación de `resolverIdentidadPersona(nombrePersona, leadData, perfilPersonas)` y `reconciliarNombrePersona` con resolución unívoca, detección y bloqueo estricto ante colisiones de prefijo entre homónimos (ej. dos Mateos); actualización de la descripción del parámetro para admitir nombre canónico completo sin truncar apellidos; búsqueda de `activaPrevia` por prefijo/slug en `reservarClasePruebaLead`; y aserción rigurosa en `qa_openai_runner.js` verificando `/reservas`, `reservas_activas.camila_rivera`, `nombre_persona === 'Camila Rivera'`, y sincronización de `reserva_id`.
  - **Diagnóstico y Blindaje de Reprogramación en Caso 3 ("Reprogramación martes-jueves"):**
    - *Evidencia:* Carlos Morales (`3bb46f7ea6e7cb78`) solicitó: `"Hola, tuve un inconveniente y no podré ir este jueves. ¿Puedo cambiar mi clase para el próximo martes?"` El lead tenía exactamente 1 reserva confirmada activa. El modelo respondió preguntando: `"¡Hola! Claro, puedo ayudarte con eso. Solo necesito que me digas a nombre de quién es la clase de prueba para poder hacerlo"`, omitiendo llamar a `reprogramar_reserva`.
    - *Causa:* La Regla 5 de prompt indicaba cómo identificar a la persona ante múltiples reservas activas pero no aclaraba el caso unívoco de una sola reserva, provocando que el modelo dudara y repreguntara en violación de la Regla 1. Además, el backend de `reprogramar_reserva` hacía coincidencia exacta de slug (`carlos_morales !== carlos`), lo que habría fallado si el modelo pasaba solo el primer nombre.
    - *Robustecimiento:* Refinamiento de la Regla 5 en `generarSystemPrompt` para declarar que ante 1 sola reserva la persona está 100% identificada y prohibir repreguntas; búsqueda flexible por prefijo de slug en `reprogramar_reserva`; implementación de `detectarSolicitudReprogramacion` distinguiendo el día de inasistencia ("este jueves") del día de destino ("próximo martes") e interceptando disyunciones ambiguas ("martes o jueves"); fallback determinista en `preguntarIA` condicionado a no-ambigüedad, reserva única confirmada plenamente vigente y no asistida; e idempotencia transaccional en `reprogramar_reserva` y `reprogramarClasePruebaLead` que previene duplicación de auditoría ante reintentos.
  - **Suite de Regresiones Expandida (`test_qa_regressions.js`):**
    - Se incorporaron Tests 22 a 33 cubriendo:
      * Tests 22 a 27: Reconciliación de titular, tildes/acentos, reprogramación unívoca, reprogramación ambigua de 2 hijos (exige aclaración), tests negativos informativos y fallback en `preguntarIA`.
      * Tests 28 a 33: Blindaje de identidad ante homónimos (Mateo Gómez vs Mateo Morales), nombres parciales sin correspondencia (Carlos vs Juan Carlos Rivera), autorización estricta sobre reservas ajenas (`UNAUTHORIZED_RESERVATION`), fechas de destino ambiguas (martes o jueves), citas vencidas (`EXPIRED_DATE`) e idempotencia de reintentos (`ALREADY_SCHEDULED_ON_DATE`, `ya_estaba_programada: true`).
    - Resultado: **33 de 33 pruebas PASS (100%)**.
  - **Validación Total Acumulada:**
    - 115 pruebas offline PASS (33 regresiones + 27 P1A + 14 P0.1 + 22 P0.2A + 10 P0.2B + 9 baseline).
    - 8 pruebas de integración con Firestore Emulator (Java 21) PASS.
    - 12 de 12 escenarios de QA verificados en Dry-Run offline con Firestore Emulator.
    - Total: **123 de 123 pruebas superadas (100% PASS)** (135 verificaciones totales).

---

## [a0aa15b] — 2026-11-11
### [COMMIT LOCAL: a0aa15b] (Rama `fix/real-whatsapp-logic`)
- **Diagnóstico y Corrección Focalizada del Caso 4 ("Dos hijos") en Segundo QA Real OpenAI:**
  - **Evidencia del Segundo QA Real Auditada:**
    - `runId`: `qa_run_1794440086896_zpmhfw`, modo `LIVE_REAL_OPENAI`.
    - Resultado: 11/12 PASS, 1 FAIL (Casos 2, 9 y 11 aprobados al 100%; único fallo en Caso 4).
    - Costo real auditado: US$0.0084 (17 peticiones HTTP OpenAI, 11 turnos conversacionales).
  - **Diagnóstico de Causa Raíz en Caso 4:**
    - *Omisión injustificada:* Mamá Patricia solicitó: `"Hola, ya reservé para Mateo pero también quiero agendar a su hermanita Sofia de 5 años para la misma clase de niños."` El modelo respondió: `"¡Hola! Claro, Mateo ya tiene su clase confirmada. ¿Me podrías confirmar el nombre real y la edad de Sofia para poder agendarla?"` omitiendo llamar a `guardar_perfil_lead` y `reservar_clase_prueba`.
    - La información era 100% suficiente: nombre propio real ("Sofia"), edad ("5 años") compatible con `clase_ninos` (4-13 años) y horario/clase unívoco ("la misma clase de niños").
    - Causa: La Regla 2 de `RESERVAS CONFIRMADAS VIGENTES DE ESTE LEAD` prohibía de forma absoluta ofrecer agendamientos a leads con reserva confirmada, inhibiendo al modelo de procesar a un nuevo hermano. Además, faltaba una regla explícita (Regla 7) que instruyera cómo proceder cuando un lead con reserva solicita agendar a un familiar adicional.
    - Detección colateral: `verificarCorrespondenciaFecha` extraía expresiones de hora (ej. `17:00`) como días del mes (`17`), lo cual habría causado una falsa intercepción por discrepancia de fecha si el LLM respondía mencionando la hora.
  - **Correcciones Implementadas en `functions/index.js`:**
    - Refinamiento de Regla 2 en `generarSystemPrompt`: circunscrita a personas ya confirmadas.
    - Incorporación de Regla 7 (a, b, c) en `generarSystemPrompt`: gestión explícita de reservas para otros familiares bajo el mismo lead; agendamiento directo sin repreguntar datos ya provistos; solicitud amable de datos si faltan.
    - Filtrado de horas en `extraerDiaYNumeroFecha`: regex para excluir `\d{1,2}:\d{2}` y `\d{1,2} hrs` previniendo colisión entre horas y días del mes.
    - Sanitización de formato en `Personas ya conocidas`: uso de fallback `p.tipo || 'persona'` evitando cadenas con `undefined`.
  - **Suite de Regresiones Expandida (`test_qa_regressions.js`):**
    - Incorporación de Tests 19, 20 y 21: petición completa (agendamiento directo y preservación de reserva previa), petición incompleta (aclaración obligatoria sin agendar a ciegas) y multi-turn (aclaración en Turno 1 y agendamiento en Turno 2).
    - Resultado: **21 de 21 pruebas PASS (100%)**.
  - **Soporte de Ejecución Focalizada en QA Runner (`qa_openai_runner.js` y `run_live_qa.sh`):**
    - Soporte para filtro opcional vía variable de entorno o argumento (`QA_SCENARIO_FILTER` o `./scratch/run_live_qa.sh 4`), generando un `runId` focalizado específico y reporte estructurado individual sin confundir un PASS 1/1 focalizado con la aprobación 12/12 de la suite completa.
  - **Cobertura Total de Validación:**
    - 103 pruebas offline PASS (21 regresiones + 27 P1A + 14 P0.1 + 22 P0.2A + 10 P0.2B + 9 baseline).
    - 8 pruebas de integración con Firestore Emulator (Java 21) PASS.
    - 12 de 12 escenarios de QA verificados en Dry-Run offline con Firestore Emulator.
    - Total: **111 de 111 pruebas superadas (100% PASS)**.

---

## [eabad06] — 2026-11-11
### [COMMIT LOCAL: eabad06] (Rama `fix/real-whatsapp-logic`)
- **Análisis y Corrección de Defectos del Primer QA OpenAI Real (`gpt-4o-mini`):**
  - **Evidencia del QA Real Auditada:**
    - `runId`: `qa_run_1794437359075_vmx6tf`, modo `LIVE_REAL_OPENAI`.
    - Resultado: 9/12 PASS, 3 FAIL (Escenarios 2, 9 y 11 fallaron; Escenario 12 fue intercepción inducida local).
    - Costo real auditado: US$0.0016 (dentro del límite de seguridad).
    - Reconciliación métrica HTTP vs. turnos: 14 solicitudes HTTP a OpenAI corresponden exactamente a 11 turnos conversacionales (3 turnos con tool-calling requirieron 2 peticiones HTTP cada uno: ronda 1 tool call + ronda 2 síntesis, más 8 turnos de una sola petición = 14 peticiones HTTP).
  - **Corrección Escenario 2 (Recordatorio de Reserva Vigente):**
    - `evaluarRuntimeGuard` ahora valida `primerNombre` (longitud >= 3) y slug de reservas preexistentes, permitiendo saludos cordiales legítimos ("¡Hola Daniela!") sin falsos positivos de intercepción.
    - Se mantuvo protección estricta contra alucinaciones de nuevas acciones ("ya te agendé", "otra clase", "nueva clase") y discrepancias de persona entre hermanos (verificado con Test 26).
  - **Corrección Escenario 9 (Cancelación Definitiva):**
    - Se eliminó la sobreescritura de `config/whatsapp_agent` con prompt dummy en `seedBaseFixtures`, restaurando la regla de negocio 7 de `DEFAULT_SYSTEM_PROMPT`.
    - Se implementó `detectarSolicitudCancelacion(texto)` con distinción clara frente a reprogramaciones, asegurando que `preguntarIA` escale deterministamente a `marcar_seguimiento_humano` si el LLM omite invocar la tool.
  - **Corrección Escenario 11 (Solicitud Explícita de Atención Humana):**
    - Se implementó `detectarSolicitudExplicitaAtencionHumana(texto)` con filtros de exclusión para preguntas informativas ("¿cuántas personas van?"), garantizando escalación determinista a `marcar_seguimiento_humano`.
  - **Corrección de Código de Salida en Runner Shell (`run_live_qa.sh`):**
    - Captura inmediata de `$pipestatus` antes de cualquier evaluación de shell condicional.
    - Verificación cruzada con `"suiteStatus"` en `scratch/qa_report_latest.json` para garantizar que nunca se imprima `[EXITO]` cuando el exit code o el reporte indiquen fallas.
  - **Suite de Regresiones Offline (`test_qa_regressions.js`):**
    - 18 de 18 pruebas PASS cubriendo los defectos de los Casos 2, 9 y 11, verificación de escritura efectiva en Firestore, no-duplicación de alertas a profesores ante reintentos (`alreadyEscalated`), fallback técnico ante fallo de base de datos y tests negativos (distinción de consultas informativas sobre cancelaciones o profesores frente a solicitudes de derivación).
  - **Total de Cobertura:** 108 pruebas automatizadas aprobadas (100 offline + 8 Firestore Emulator) y 12/12 escenarios dry-run PASS.

- **Diagnóstico y Robustecimiento de Resiliencia en QA Runner (`qa_openai_runner.js`):**
  - **Identificación de Causa Comprobada:** En el commit `70a6c2d`, la persistencia del archivo JSON estaba tras el bucle sin `try/catch` envolvente en las aserciones. Cualquier excepción funcional o de API causaba `process.exit(1)` antes de escribir el archivo JSON.
  - **Incertidumbre Documentada:** La falta de redirección de stdout/stderr a archivo en la corrida previa impidió aislar el error específico devuelto por OpenAI o la primera aserción en el intento de las 17:33.
  - **Aislamiento Funcional vs. Crítico:** Las aserciones funcionales de cada escenario se capturan de forma independiente, registrándose como `status: 'FAIL'` y permitiendo continuar con los demás escenarios. Errores críticos de sistema (401 Auth, 403 Permisos, 429 Cuota, límite de presupuesto o desconexión) detienen inmediatamente la suite.
  - **Trazabilidad y Rotación Inequívoca:** Asignación de `runId` y timestamp únicos por corrida. Rotación preventiva automática de `scratch/qa_report_latest.json` a `scratch/qa_report_previous.json` para garantizar que un reporte antiguo jamás se interprete como nuevo.
  - **Sanitización Zero PII:** Ofuscación estricta de teléfonos a `[PHONE]` y truncado de snippets de respuesta a 120 caracteres en los reportes JSON.
  - **Captura Integral de Ejecución (`run_live_qa.sh`):** Registro simultáneo a consola y a `scratch/qa_execution.log` vía `tee`, con captura estricta de `$EXIT_CODE` y compatibilidad dual para lectura silenciosa en shells zsh y bash.

---

## [70a6c2d] — 2026-11-11
### [COMMIT LOCAL: 70a6c2d] (Rama `fix/real-whatsapp-logic`)
- **Pre-Flight de QA Conversacional y Aislamiento de Red:**
  - Verificación estricta de `FIRESTORE_EMULATOR_HOST` y `GCLOUD_PROJECT=demo-ginga-test` antes de importar Firebase Admin SDK.
  - Instalación de Firewall de Red Global en `global.fetch` y `https.request`, con bloqueo determinista de salidas a Meta WhatsApp (`graph.facebook.com`) y GCP remoto.
  - Validación activa de conectividad local al emulador y prueba de intercepción de Meta previas a la ejecución de pruebas.
  - Script temporal interactivo `scratch/run_live_qa.sh` (fuera de Git) con captura sin eco `read -s` y trap de limpieza de credenciales.
  - Generación de reporte estructurado de telemetría y resultados en `scratch/qa_report_latest.json`.
  - Dry-run: 12/12 escenarios PASS en Firestore Emulator. QA en vivo: BLOCKED a la espera de introducción interactiva de clave de pruebas.

---

## [Release Candidate Gate] — 2026-11-11
### [PROBADO LOCALMENTE] (Rama `fix/real-whatsapp-logic`, HEAD `847d3be`)
- **Evaluación de Release Candidate & Security Gate:**
  - **Pruebas en Firestore Emulator Real (Java 21):**
    - Suite de integración `test_emulator_integration.js` ejecutada contra emulador oficial de Firestore (8 de 8 pruebas PASS).
    - Detección y corrección de defecto crítico: Firestore rechaza `FieldValue.serverTimestamp()` dentro de arrays (`reprogramaciones`); se reemplazó por `Timestamp.now()`.
  - **Auditoría Criptográfica y Secretos:**
    - `TELEMETRY_SALT` actualizado a fallback dinámico `crypto.randomBytes(32).toString('hex')` eliminando cualquier secreto estático en el código fuente.
  - **Auditoría CI/CD:**
    - Detección de riesgo crítico en `.github/workflows/deploy.yml`: auto-deploy a producción al mergear a `main`. Prohibido merge sin protección de rama o aprobación manual.
  - **Runner de QA Conversacional Real Preparado (`qa_openai_runner.js`):**
    - Suite de 12 escenarios de conversación real sobre Firestore Emulator (`demo-ginga-test`).
    - Alineación exhaustiva con casos de auditoría: reserva nueva, reserva vigente, reprogramación M-J, 2 hijos, asistencia previa, inasistencia, sin cupos, datos incompletos, cancelación, sede/horarios dinámicos, atención humana y Runtime Guard.
    - Intercepción defensiva de WhatsApp: `enviarMensajeWhatsApp` desacoplado a stub in-memory para evitar cualquier tráfico hacia Meta.
    - Verificación dinámica de sedes desde la colección `/sedes`.
    - Controles de seguridad y presupuesto: Flag `ENABLE_REAL_OPENAI_QA=false` por defecto, límite de $0.25 USD y 30 llamadas máximo, registro Zero PII sin teléfonos ni datos privados.
    - Modo Dry-Run offline verificado al 100% (12 de 12 escenarios PASS).
    - Pre-flight Gate: Ejecución en vivo bloqueada preventivamente por ausencia de `OPENAI_API_KEY` en el entorno.
  - **Veredicto RC:** **CONDITIONAL** (Apto para Staging y QA Real, Bloqueado para Despliegue Directo a Producción).
  - **Total de pruebas verificadas:** **90 de 90 pruebas PASS** (82 offline + 8 emulator).

---

## [847d3be] — 2026-11-11
### [COMMIT LOCAL: 847d3be] (Rama `fix/real-whatsapp-logic`)
- **P1A: Runtime Guard Determinista y Telemetría Segura Zero PII:**
  - **Runtime Guard Determinista en `functions/index.js`:**
    - Inspección post-generación obligatoria en `preguntarIA` antes del envío de texto a WhatsApp o al cliente.
    - Análisis semántico de afirmaciones de mutación (`booking`, `reschedule`, `cancellation`) y validación contra el contexto del turno (`turnContext.toolRecords`).
    - Verificación estricta de correspondencia de **persona**: el éxito para un hijo no justifica la confirmación para otro hermano, y el rechazo de un hermano invalida confirmaciones conjuntas.
    - Verificación estricta de correspondencia de **fecha**: el agendamiento en una fecha no autoriza confirmar otra fecha distinta.
    - Verificación estricta de correspondencia de **operación**: una reserva de prueba no justifica una reprogramación ni cancelación.
    - Detección y bloqueo de contradicciones ante rechazos de tools (`ALREADY_ATTENDED`, `CLASS_FULL`, `NO_SHOW_PREVIOUS`, `INVALID_DATE`, etc.).
    - Fail-Safe con mensaje seguro de contención y marcado automático del lead en Firestore con `status: 'requiere_atencion'`, evitando alertamiento duplicado si ya fue escalado (`alreadyEscalated`).
    - Fallback técnico transparente ante fallas de base de datos sin prometer falsas derivaciones completadas.
    - Preservación de `ai_habilitada` para evitar suspensiones permanentes involuntarias.
  - **Estructuración de Salidas de Tools (`TurnContext`):**
    - Todos los handlers de `AVAILABLE_TOOLS` registran metadatos enriquecidos de ejecución (`tool_name`, `operation`, `status`, `reason_code`, `mutation_committed`, `persona_slug`, `reservation_ref`, `fecha_confirmada`, `fecha_iso`, `hora`, `sede`).
    - Aislamiento completo de `TurnContext` por turno para evitar filtraciones de estado.
  - **Telemetría Segura Zero PII (ACC / DANEV):**
    - `lead_hash` mediante HMAC-SHA256 con salt secreto (`TELEMETRY_SALT`), mitigando desanonimización de teléfonos por tablas rainbow.
    - Ofuscación de nombres de menores a `persona_ref` (`p_` + HMAC hex) y exclusión de textos de usuarios.
    - Buffer en memoria volátil `TELEMETRY_BUFFER` acotado a 100 eventos.
  - **Suites de Pruebas:**
    - `test_p1a_runtime_guard.js`: **27 de 27 pruebas aprobadas (100% PASS)**.
    - `test_p01_recognition.js`: 14 de 14 pruebas aprobadas (100% PASS).
    - `test_p02a_rescheduling.js`: 22 de 22 pruebas aprobadas (100% PASS).
    - `test_p02b_family_identity.js`: 10 de 10 pruebas aprobadas (100% PASS).
    - `suite_runner.js`: **9 de 9 escenarios OK (0 defectos baseline restantes)**.
    - Total acumulado: **82 de 82 pruebas aprobadas (100% PASS)**.

---

## [bd36b9a] — 2026-11-11
### [COMMIT LOCAL: bd36b9a] (Rama `fix/real-whatsapp-logic`)
- **Gate de Integración P0.2A + P0.2B y Decisión 5:**
  - Consolidación de Decisiones 5 (resolución dinámica multisede) y 13 (identidad familiar y reservas múltiples).
  - Trazabilidad y auditoría de commits de P0.2A (`df2650e`) y P0.2B (`ae75ee6`).

---

## [ae75ee6] — 2026-11-11
### [COMMIT LOCAL: ae75ee6] (Rama `fix/real-whatsapp-logic`)
- **P0.2B: Identidad Familiar y Reservas Múltiples:**
  - Resolución no ambigua de identidad y prohibición de adivinanza (`personas[0]`).
  - Preservación y reconciliación de reservas legacy con `reserva_id` escalar.
  - Aislamiento total de estados entre hermanos.
  - 10 de 10 pruebas aprobadas en `test_p02b_family_identity.js`.
  - Caso 5 de la suite de línea base resuelto.

---

## [Unreleased / Siguiente Paso]
### [DISEÑADO - PENDIENTE IMPLEMENTACIÓN]
- **P1B / P2: Agent Control Center e Interfaz de Visualización Staging:**
  - Panel administrativo visual para inspección de telemetría y control de tools.
  - Dashboard para monitorización en tiempo real de intercepciones del Runtime Guard.
