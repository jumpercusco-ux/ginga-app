# Guía de Reanudación Rápida (HANDOFF)

> **Propósito:** Permite a cualquier agente, chat o desarrollador retomar el trabajo en GINGA de inmediato, con contexto 100% verificado y sin depender del historial de conversación.

---

## 1. Estado Inmediato del Proyecto

- **Proyecto:** `/Users/jumper/ginga_app`
- **Rama Activa:** `feat/ped03-biblioteca-curricular` (derivada de `main` `fd891a7` / `v1.0.0-feedback-v1`; `main` permanece intacta sin merge).
- **Frente Pedagógico Activo (`PED-01..PED-04C2-B`):** **`PED-04C2-B` IMPLEMENTADO Y PROBADO OFFLINE EN `feat/ped03-biblioteca-curricular` (SIN CAMBIOS EN `functions/index.js` NI FLUTTER; PROVEEDOR IA REAL DESHABILITADO; PREVIEW ACTIVO EN `8097`) — PENDIENTE REVISIÓN Y AUTORIZACIÓN PARA `PED-04C2-C`.**
  - Motor Offline V2 (`functions/planner_v2/*`, 14 módulos + catálogo FIU verificado por SHA-256 `0a4b2237...`): implementa autorización por Custom Claims, bloqueo de sobrescrituras de política desde cliente, cuota atómica e idempotencia por `request_id` (`20/día`, `4/min`), presupuesto de salida escalado (`4500`/`5600` tokens para 60/90 min), Zero-PII heurístico con disclaimer explícito y verificación determinista de cero IDs internos/URLs en payload LLM, precedencia de orígenes FIU/Pizarra/IA, validación estricta de obligatorios/espacio/supervisión/inversiones, desglose exacto de sub-tiempos, ejercicios breves infantiles, progresiones independientes previas, referencias reales al cancionero (`cantiga_id: null`), `SimulatedPlannerProvider`, validador estructural + rúbrica heurística y reparador acotado. Suite [test_planner_v2_quality.js](file:///Users/jumper/ginga_app/real_agent_harness/test_planner_v2_quality.js): **`6/6` Infraestructura + `20/20` Escenarios Golden (`93.9/100` heurístico offline sobre `17` planes excluyendo `3` errores esperados)**; evaluación humana en tatami y LLM real explícitamente pendientes.
  - Respaldo en GitHub: commits `613cefe` (`29` archivos curriculares), `74f1fcc` (`PED-03C-CI`), `93ee84b` (`PED-04B1`), `62bb7f8` (`PED-04B2` + `PED-04B2-UX`) y commit de cierre `PED-04C1` en `feat/ped03-biblioteca-curricular`.
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

1. **Esperar revisión y autorización explícita de `PED-04C2-B`:**
   - El motor offline `functions/planner_v2/*`, el contrato [PLANNER_V2_ENGINE_CONTRACT.md](file:///Users/jumper/ginga_app/docs/PLANNER_V2_ENGINE_CONTRACT.md) y los 20 escenarios Golden en CI están listos en `feat/ped03-biblioteca-curricular` (sin commit/push ni modificación de `functions/index.js` ni Flutter; preview `http://127.0.0.1:8097/` activo).
2. **Alcance futuro (`PED-04C2-C` y `PED-04C2-D` cuando se autoricen):**
   - `PED-04C2-C`: conectar contratos `PlannerSpaceContext` / `instructors_available` y flujo simulado en la UI Flutter sin llamadas pagadas.
   - `PED-04C2-D`: exportar `generarPlanClaseV2` en `functions/index.js`, verificar Custom Claims y ejecutar piloto controlado con LLM real + evaluación humana.

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
