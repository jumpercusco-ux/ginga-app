# Guía de Reanudación Rápida (HANDOFF)

> **Propósito:** Permite a cualquier agente, chat o desarrollador retomar el trabajo en GINGA de inmediato, con contexto 100% verificado y sin depender del historial de conversación.

---

## 1. Estado Inmediato del Proyecto

- **Proyecto:** `/Users/jumper/ginga_app`
- **Rama Activa:** `feat/ped03-biblioteca-curricular` (derivada de `main` `fd891a7` / `v1.0.0-feedback-v1`; `main` permanece intacta sin merge).
- **Frente Pedagógico Activo (`PED-01..PED-04C2-D`):** **`PED-04C2-D` VALIDADO EN PILOTO REAL LOCAL (`gpt-4o-mini` MODULAR, 1 CLASE INFANTIL COMPLETA EN `scratch/autonomous_pilot_result.json`), LISTO PARA EVALUACIÓN PEDAGÓGICA HUMANA EN EDITOR FLUTTER (`http://127.0.0.1:8097/`) Y SIN DESPLIEGUE A PRODUCCIÓN.**
  - **Estabilización Modular y Piloto Real Controlado (`PED-04C2-D`):**
    - Motor en `functions/planner_v2/` actualizado con esqueleto temporal determinista pre-asignado ([temporal_planner.js](file:///Users/jumper/ginga_app/functions/planner_v2/temporal_planner.js)), esquema OpenAI estricto slim por bloque ([response_schema.js](file:///Users/jumper/ginga_app/functions/planner_v2/response_schema.js), `1,566` chars / 12 campos), ensamblador determinista de IDs/tiempos/orígenes/vínculos ([block_assembler.js](file:///Users/jumper/ginga_app/functions/planner_v2/block_assembler.js)), prompts por bloque sin duplicación (`879–950` tokens/bloque), orquestación por oleadas paralelas y reparación paralela acotada al subconjunto fallido ([plan_repairer.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_repairer.js)), validador de juegos en 3 dimensiones ejecutables ([plan_validator.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_validator.js)), reserva presupuestal multi-bloque persistida ([pilot_budget_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/pilot_budget_guard.js)), fallback controlado de modelo ([llm_adapter.js](file:///Users/jumper/ginga_app/functions/planner_v2/llm_adapter.js)), contrato callable futuro ([callable_handler.js](file:///Users/jumper/ginga_app/functions/planner_v2/callable_handler.js)) y tienda de cuotas transaccional (`FirestoreTransactionQuotaStore`).
    - Cliente Flutter ([planner_v2_engine_client.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_v2_engine_client.dart)) con timeout `120s`, eliminación de reintento automático silencioso ante `504` y recuperación directa desde `/api/planner-v2/last-status` hacia `PlannerHubBody` (`Abrir en Editor`, 0 llamadas pagadas adicionales).
    - **Resultado Real del Piloto (`gpt-4o-mini`, intento `6/8`):** clase `Infantil M/J 18:00 · Técnicas · Juegos · Acrobacias · Musicalidad (60 min)` generada en **`21,494 ms`**, **`4` bloques (`12 + 26 + 11 + 11 = 60 min` exactos)**, **`8` ejercicios**, **`4` llamadas LLM** (`repairs=0`), costo **`$0.002063` USD**, recurso obligatorio `idea_res_02` integrado (`teacher_resource: 1`), `0` movimientos FIU adultos, canción `"Marinheiro só"` con `cantiga_id: null`, validación estructural **`PASS`** (`88/100` heurístico y revalidación posterior contra regla de juegos en 3 dimensiones en **`PASS`**). Presupuesto acumulado del piloto: **`$0.01189 / $0.10` USD (`$0.08811` restantes, `6/8` generaciones, `15` llamadas)**.
  - Integración Flutter + Preview (`lib/features/instructor/planificador/` + `scripts/planner_v2_local_server.js`): `PlannerSpaceContext` configurable en Creación Avanzada y heredado en Rápida sin asumir materiales/piso/colchonetas desconocidos; `HttpLocalPlannerV2Client` conecta al motor real `functions/planner_v2/index.js` (`/api/planner-v2/health`, `/api/planner-v2/last-status`, `/api/planner-v2/generate`, `/flutter_service_worker.js -> 404`, guardia obligatoria `--token <PIN>` en LAN no-loopback); preservación íntegra del formulario y apertura directa en `PlannerClassEditorView` sin marcar recursos como usados; escenarios `Infantil M/J 18:00` y `Adultos M/J 19:00` en [main_planificador_preview.dart](file:///Users/jumper/ginga_app/lib/main_planificador_preview.dart).
  - Documentación y pruebas verificadas tras el cierre técnico: guía [PED04C2D_PREPARATION_AND_TABLET_PREVIEW.md](file:///Users/jumper/ginga_app/docs/PED04C2D_PREPARATION_AND_TABLET_PREVIEW.md), suites en [.github/workflows/ci.yml](file:///Users/jumper/ginga_app/.github/workflows/ci.yml) incluyendo [test_planner_v2_modular_stabilization.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_modular_stabilization.js), [test_planner_v2_pilot_and_budget.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_pilot_and_budget.js), [test_planner_v2_structural_engine.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_structural_engine.js), [test_planner_v2_local_server_e2e.js](file:///Users/jumper/ginga_app/scripts/test_planner_v2_local_server_e2e.js) y [test_planner_v2_quality.js](file:///Users/jumper/ginga_app/real_agent_harness/test_planner_v2_quality.js) (`6/6` Infraestructura + `20/20` Golden `93.9/100`), `flutter analyze --no-fatal-warnings --no-fatal-infos` (exit `0`) y `flutter test` (**`75/75 All tests passed!`** incluyendo [planificador_v2_integration_test.dart](file:///Users/jumper/ginga_app/test/planificador_v2_integration_test.dart)); evaluación pedagógica humana en tatami pendiente.
  - Respaldo en GitHub: commits previos `613cefe`, `74f1fcc`, `93ee84b`, `62bb7f8`, `a966b6c` (`PED-04C1`), `2b68974` (`PED-04C2-B`) y `753d686` (`PED-04C2-C`) en `feat/ped03-biblioteca-curricular` (commit `PED-04C2-D` en curso de cierre).
  - Ejecución de Clases en Vivo V2 (`PED-04C1`): integrada en el Planificador Unificado (`PlannerHubBody` / `InstructorPizarraScreen`) mediante [live_session_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/live_session_models.dart), [live_session_persistence.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/live_session_persistence.dart), [planner_live_class_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_live_class_view.dart) y [planner_live_closure_sheet.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_live_closure_sheet.dart), reutilizando los patrones útiles de `_ClaseEnVivoScreen` V1 sin escrituras en Firestore real ni llamadas IA de pago.
  - Funcionalidades clave de `PED-04C1` + cierre funcional: arranque `Iniciar clase` para planes V1 y V2; temporizador resistente al segundo plano por marcas de reloj de pared (`WidgetsBindingObserver` + reloj inyectable) con pausa, reanudación, reinicio y ajustes `-1 m` / `+1 m`; navegación y estado individual (`pending`/`completed`/`skipped`) con tiempo real por ejercicio y advertencia con confirmación manual al completar en `00:00`; variantes `Principiantes`/`Intermedios`/`Avanzados` con opción **`Ver todos los niveles`** simultánea; materiales y seguridad; consulta de movimientos FIU (`MovimientoDetalleScreen`) y recursos de Pizarra sin perder el estado; recuperación local (`SharedPreferences`); cierre anticipado o completo con campo de continuidad limpio (sin texto residual + sugerencia opcional bajo demanda); actualización exclusiva de `ultimaEjecucion` y `vecesImpartida` en el plan original sin alterar su contenido pedagógico; conservación de instantánea (`planSnapshot`); contabilización idempotente (`_recordedSessionIds`) exclusivamente sobre ejercicios efectivamente impartidos (`completed`); transferencia de contexto pedagógico estructurado (`PedagogicalContinuityContext` + `PlannerContinuityContextCard` expandible) con aislamiento estricto por grupo; y sanitización determinista Zero-PII (`PlannerPiiSanitizer`) sobre texto libre en `toAiSafeRequestMap()` y `toAiSafeMap()`.
  - Suite Flutter completa: `69/69 All tests passed!` (`planificador_v2_test.dart`, `planificador_v2_editor_test.dart`, `planificador_v2_live_test.dart`, etc.); `flutter analyze` limpio sobre los 7 objetivos del frente (`No issues found!`); catálogo FIU `PASS`, importador `6/6 PASS`, agente fechas `8/8 PASS` y evaluaciones `9/9 PASS`; preview web compilado con `--pwa-strategy=none` servido en `http://127.0.0.1:8097/`.
  - Catálogo curricular consolidado [data/curriculum/fiu_adulto_v1.json](file:///Users/jumper/ginga_app/data/curriculum/fiu_adulto_v1.json) (`97` movimientos canónicos Adulto Cordas `1–6`, `94` elegibles IA, `3` pendientes de revisión técnica, `1` bloque compartido `adulto_bloque_05_06`, `12` cordas infantiles en metadata, `21` tutoriales con `5` videos reales y `26` términos de glosario).
  - Biblioteca Curricular unificada (Alumnos + Profesores) en Flutter con soporte adaptable `GingaTheme` claro/oscuro, separación estricta entre rol y graduación personal, preview web aislado en [lib/main_biblioteca_preview.dart](file:///Users/jumper/ginga_app/lib/main_biblioteca_preview.dart) y contrato opt-in `CurriculumSelectionContract` listo para `PED-04`.
  - Bloqueo de **Java 21 resuelto** vía `/opt/homebrew/opt/openjdk@21` sin alterar el JDK global del sistema: Firebase Firestore Emulator (`--project demo-ginga-test`) superado al 100% en reglas curriculares (`7/7 PASS`), reglas generales (`9/9 PASS`) e importador idempotente (`6/6 PASS`, preservando los `21` tutoriales y `5` videos reales).
  - Suite Flutter completa: `35/35 All tests passed!`; `test_reservation_date_semantics.js` (`8/8 PASS` en `TZ=UTC` y `TZ=America/Lima`); `test_agent_evaluations.js` (`9/9 PASS`).
- **Producción Intacta:** `whatsappWebhook v69` (Node.js 22), web `https://www.gingaperu.com` (Vercel desconectado de auto-deploy), proyecto Firebase `capoeirafiu-ea8ljo`. **No se ha escrito en Firestore productivo ni desplegado.**

---

## 2. Qué se Acaba de Terminar

### A. Frente Pedagógico — Biblioteca Curricular FIU (`PED-01` a `PED-03C`)
1. **PED-01 / PED-02:** Auditoría pedagógica e inventario de los `21` tutoriales existentes (`5` videos reales) y extracción visual/estructural desde `scratch/apostila.pdf` hacia [data/curriculum/fiu_adulto_v1.json](file:///Users/jumper/ginga_app/data/curriculum/fiu_adulto_v1.json) y [docs/CURRICULUM_FIU_ADULTO_V1_REVIEW.md](file:///Users/jumper/ginga_app/docs/CURRICULUM_FIU_ADULTO_V1_REVIEW.md).
2. **PED-03A:** Implementación de modelos tipados (`curriculum_models.dart`), repositorio offline/Firestore (`curriculum_repository.dart`), deprecación segura del seed mockup (`TutorialesService.legacyMockSeedEnabled = false`), endurecimiento de [firestore.rules](file:///Users/jumper/ginga_app/firestore.rules) (Custom Claims firmados + bloqueo de borrado y auto-elevación), importador idempotente (`import_curriculum_to_firestore.js`) y contrato IA (`docs/CURRICULUM_AI_PLANNER_CONTRACT.md`).
3. **PED-03B / PED-03B-V / PED-03B-UX / PED-03B-FINAL:** Evolución unificada de [biblioteca_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/biblioteca_screen.dart), [curriculo_biblioteca_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/curriculo_biblioteca_screen.dart), [movimiento_detalle_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/movimiento_detalle_screen.dart) y [biblioteca_user_context.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/widgets/biblioteca_user_context.dart), conservando `GingaTheme` adaptable claro/oscuro, compactando tarjetas con corda de introducción, agregando filtro `Con video`, eliminando alias visualmente duplicados, y preparando `CurriculumSelectionContract` para `PED-04`.
4. **PED-03C:** Desbloqueo de Firestore Emulator con JDK 21 (`demo-ginga-test`), aislamiento de estado entre suites en [test_curriculum_importer.js](file:///Users/jumper/ginga_app/scripts/test_curriculum_importer.js), verificación explícita de los `21` tutoriales y `5` videos reales, actualización documental integral y propuesta de respaldo Git.
6. **PED-04B2 / PED-04B2-UX:** Editor Pedagógico de Clases V2 y refinamiento UX en `lib/features/instructor/planificador/` (`62bb7f8`), validado visualmente en `http://127.0.0.1:8097/`.
7. **PED-04C1 (+ cierre funcional):** Ejecución de Clases en Vivo V2 y continuidad pedagógica estructurada por grupo integradas en `PlannerHubBody` / `InstructorPizarraScreen` ([live_session_models.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/models/live_session_models.dart), [live_session_persistence.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/live_session_persistence.dart), [planner_live_class_view.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_live_class_view.dart), [planner_live_closure_sheet.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/widgets/planner_live_closure_sheet.dart), `PedagogicalContinuityContext` y `PlannerContinuityContextCard`), pruebas deterministas en [planificador_v2_live_test.dart](file:///Users/jumper/ginga_app/test/planificador_v2_live_test.dart) (`68/68` totales en `flutter test`), capturas claro/oscuro en escritorio/tablet/móvil y preview actualizado en `http://127.0.0.1:8097/` (sin commit/push/deploy hasta aprobación).

### B. Histórico Consolidado — Agente WhatsApp y CI/CD (`v1.0.0-feedback-v1`)
1. **Sincronización y CI/CD (`fd891a7`):** Eliminado el trigger masivo de `.github/workflows/deploy.yml`; flujos separados en `ci.yml`, `deploy-web.yml`, `deploy-functions.yml` y `deploy-firestore.yml` con despliegues manuales confirmados.
2. **Implementación y Cierre de Seguridad P1A (Runtime Guard y Telemetría Zero PII):**
   - **Runtime Guard Determinista en `functions/index.js`:**
     - Inspección obligatoria post-generación en `preguntarIA` antes del envío de mensajes a WhatsApp o al cliente.
     - Detección semántica de afirmaciones de mutación (`booking`, `reschedule`, `cancellation`).
     - Validación estricta contra `turnContext.toolRecords`:
       - Correspondencia obligatoria de **persona**: el éxito para un hijo no justifica la confirmación para otro hermano, y el rechazo de un hermano invalida confirmaciones conjuntas ("ambos quedaron agendados").
       - Correspondencia obligatoria de **fecha**: el agendamiento en martes no autoriza afirmar jueves ni viceversa.
       - Correspondencia obligatoria de **tipo de operación**: una reserva no autoriza reprogramación ni cancelación.
       - Detección estricta de contradicciones ante rechazos de tools (`ALREADY_ATTENDED`, `CLASS_FULL`, `NO_SHOW_PREVIOUS`, `INVALID_DATE`, etc.).
       - En recordatorios de reservas previas sin tool, correspondencia con el bloque estructurado del prompt sin afirmar acciones nuevas inmediatas.
     - Intercepción Fail-Safe: sustitución automática por mensaje seguro de contención y actualización inmediata de `whatsapp_leads` con `status: 'requiere_atencion'`, evitando alertamiento duplicado si ya fue escalado (`alreadyEscalated`).
     - Fallback técnico transparente ante fallas de base de datos sin prometer falsas derivaciones completadas.
     - Preservación de `ai_habilitada` (el guard no la desactiva automáticamente).
   - **Estructuración de Salidas de Tools (`TurnContext`):**
     - Todos los handlers de `AVAILABLE_TOOLS` registran metadatos enriquecidos en `turnContext.toolRecords` (`tool_name`, `operation`, `status`, `reason_code`, `mutation_committed`, `persona_slug`, `reservation_ref`, `fecha_confirmada`, `fecha_iso`, `hora`, `sede`).
     - Aislamiento completo de `TurnContext` por turno para evitar filtraciones de estado.
   - **Telemetría Segura Zero PII (ACC / DANEV):**
     - `lead_hash` mediante HMAC-SHA256 con salt secreto (`TELEMETRY_SALT`), mitigando desanonimización de teléfonos por tablas rainbow.
     - Ofuscación de nombres de menores a `persona_ref` (`p_` + HMAC hex) y exclusión de textos de usuarios.
     - Buffer en memoria volátil `TELEMETRY_BUFFER` acotado a 100 eventos.

---

## 3. Comandos Esenciales de Ejecución y Pruebas

```bash
# 1. Validar catálogo curricular FIU
node scripts/validate_curriculum_catalog.js

# 2. Importador idempotente en modo in-memory
node scripts/test_curriculum_importer.js

# 3. Suites reales en Firebase Firestore Emulator con Java 21 (solo demo-ginga-test)
PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH" JAVA_HOME="/opt/homebrew/opt/openjdk@21" firebase emulators:exec --only firestore --project demo-ginga-test "node scripts/test_curriculum_firestore_rules.js && node real_agent_harness/test_firestore_rules.js && node scripts/test_curriculum_importer.js"

# 4. Análisis estático y suite completa Flutter (35 pruebas)
/Users/jumper/development/flutter/bin/flutter analyze lib/core/models/curriculum_models.dart lib/core/services/curriculum_repository.dart lib/core/services/tutoriales_service.dart lib/core/router/app_router.dart lib/features/biblioteca/biblioteca_screen.dart lib/features/biblioteca/curriculo_biblioteca_screen.dart lib/features/biblioteca/movimiento_detalle_screen.dart lib/features/biblioteca/widgets/biblioteca_user_context.dart lib/main_biblioteca_preview.dart test/curriculum_fiu_unit_test.dart test/biblioteca_curriculo_widget_test.dart test/ped03b_screenshot_capture_test.dart
/Users/jumper/development/flutter/bin/flutter test

# 5. Compilar preview web aislado (sin Firebase de producción ni service worker)
/Users/jumper/development/flutter/bin/flutter build web --release --pwa-strategy=none -t lib/main_planificador_preview.dart -o /tmp/ginga_ped04b1_final_8097
rm -f /tmp/ginga_ped04b1_final_8097/flutter_service_worker.js

# 6. Suites del agente WhatsApp (referencia)
node real_agent_harness/test_p1a_runtime_guard.js
node real_agent_harness/test_qa_regressions.js
```

---

## 4. Qué Sigue Exactamente (Siguiente Tarea)

1. **Evaluación pedagógica humana de la clase real generada (`PED-04C2-D`):**
   - El servidor local en `http://127.0.0.1:8097/` conserva la clase infantil generada en memoria/disco (`scratch/last_completed_planner_v2_class.json` y `scratch/autonomous_pilot_result.json`); abrir `PlannerHubBody` en el navegador y usar el banner **«Abrir en Editor»** (0 llamadas pagadas adicionales) para revisar sus 4 bloques y ajustar o guardar para el tatami.
2. **Siguiente paso sujeto a aprobación explícita del propietario:**
   - Decidir si se amplía la validación real al resto de perfiles (Adultos FIU con continuidad, enfoque especializado) dentro del saldo restante (`$0.08811` / `6/8` generaciones), o si se autoriza avanzar al siguiente hito (`PED-04C3` / integración Firestore/Callable `generarPlanClaseV2`). **No iniciar `PED-04C3` ni desplegar sin aprobación.**

---

## 5. Qué NO se Debe Modificar

- **NO escribir en Firestore de producción ni ejecutar despliegues** sin autorización expresa (y mucho menos `--only functions`).
- **NO modificar `functions/index.js` ni lógica de WhatsApp** fuera de un alcance explícitamente autorizado.
- **NO modificar `lib/core/theme/ginga_theme.dart`** ni la paleta global aprobada sin revisión.
- **NO mezclar archivos de `demo/assets/backup/*.mp4` o credenciales** dentro del commit curricular de `PED-03`.

---

## 6. Decisiones Comerciales Pendientes del Usuario

1. **Segunda Clase de Prueba Gratuita:**
   - *Propuesta técnica:* Permitir solo 1 clase gratuita por persona; si ya asistió, ofrecer membresía y derivar con `marcar_seguimiento_humano` si solicita otra clase.
   - *Estado:* Pendiente de decisión comercial formal.
2. **Reagendamiento tras Inasistencia (No-Show):**
   - *Propuesta técnica:* Permitir 1 reprogramación automática ante falta justificada; si reincide, derivar a profesor.
   - *Estado:* Pendiente de decisión comercial formal.

---

## 7. Cómo Recuperar el Contexto sin Depender del Chat

1. Leer este archivo `HANDOFF.md` y el documento maestro `CURRENT-STATE.md`.
2. Revisar las decisiones aprobadas y pendientes en `DECISIONS.md`.
3. Consultar el historial de versiones en `CHANGELOG.md`.
4. Ejecutar `node real_agent_harness/test_p01_recognition.js` para comprobar que el entorno local se encuentra operativo.
