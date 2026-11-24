# Guía de Reanudación Rápida (HANDOFF)

> **Propósito:** Permite a cualquier agente, chat o desarrollador retomar el trabajo en GINGA de inmediato, con contexto 100% verificado y sin depender del historial de conversación.

---

## 1. Estado Inmediato del Proyecto

- **Proyecto:** `/Users/jumper/ginga_app`
- **Rama Activa:** `main` (HEAD `fd891a7`, tag `v1.0.0-feedback-v1`) con trabajo local pendiente de respaldo para **PED-01 a PED-03C** (sin commits ni push todavía).
- **Frente Pedagógico Activo (`PED-01..PED-03C`):** **VALIDADO LOCALMENTE Y CERRADO PARA RESPALDO GIT.**
  - Catálogo curricular consolidado [data/curriculum/fiu_adulto_v1.json](file:///Users/jumper/ginga_app/data/curriculum/fiu_adulto_v1.json) (`97` movimientos canónicos Adulto Cordas `1–6`, `94` elegibles IA, `3` pendientes de revisión técnica, `1` bloque compartido `adulto_bloque_05_06`, `12` cordas infantiles en metadata, `21` tutoriales con `5` videos reales y `26` términos de glosario).
  - Biblioteca Curricular unificada (Alumnos + Profesores) en Flutter con soporte adaptable `GingaTheme` claro/oscuro, separación estricta entre rol y graduación personal, preview web aislado en [lib/main_biblioteca_preview.dart](file:///Users/jumper/ginga_app/lib/main_biblioteca_preview.dart) y contrato opt-in `CurriculumSelectionContract` listo para `PED-04`.
  - Bloqueo de **Java 21 resuelto** vía `/opt/homebrew/opt/openjdk@21` sin alterar el JDK global del sistema: Firebase Firestore Emulator (`--project demo-ginga-test`) superado al 100% en reglas curriculares (`7/7 PASS`), reglas generales (`9/9 PASS`) e importador idempotente (`6/6 PASS`, preservando los `21` tutoriales y `5` videos reales).
  - Suite Flutter completa: `35/35 All tests passed!` y `flutter analyze` limpio (`No issues found!`) en los 12 archivos curriculares/preview/test.
- **Producción Intacta:** `whatsappWebhook v69` (Node.js 22), web `https://www.gingaperu.com` (Vercel desconectado de auto-deploy), proyecto Firebase `capoeirafiu-ea8ljo`. **No se ha escrito en Firestore productivo ni desplegado.**

---

## 2. Qué se Acaba de Terminar

### A. Frente Pedagógico — Biblioteca Curricular FIU (`PED-01` a `PED-03C`)
1. **PED-01 / PED-02:** Auditoría pedagógica e inventario de los `21` tutoriales existentes (`5` videos reales) y extracción visual/estructural desde `scratch/apostila.pdf` hacia [data/curriculum/fiu_adulto_v1.json](file:///Users/jumper/ginga_app/data/curriculum/fiu_adulto_v1.json) y [docs/CURRICULUM_FIU_ADULTO_V1_REVIEW.md](file:///Users/jumper/ginga_app/docs/CURRICULUM_FIU_ADULTO_V1_REVIEW.md).
2. **PED-03A:** Implementación de modelos tipados (`curriculum_models.dart`), repositorio offline/Firestore (`curriculum_repository.dart`), deprecación segura del seed mockup (`TutorialesService.legacyMockSeedEnabled = false`), endurecimiento de [firestore.rules](file:///Users/jumper/ginga_app/firestore.rules) (Custom Claims firmados + bloqueo de borrado y auto-elevación), importador idempotente (`import_curriculum_to_firestore.js`) y contrato IA (`docs/CURRICULUM_AI_PLANNER_CONTRACT.md`).
3. **PED-03B / PED-03B-V / PED-03B-UX / PED-03B-FINAL:** Evolución unificada de [biblioteca_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/biblioteca_screen.dart), [curriculo_biblioteca_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/curriculo_biblioteca_screen.dart), [movimiento_detalle_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/movimiento_detalle_screen.dart) y [biblioteca_user_context.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/widgets/biblioteca_user_context.dart), conservando `GingaTheme` adaptable claro/oscuro, compactando tarjetas con corda de introducción, agregando filtro `Con video`, eliminando alias visualmente duplicados, y preparando `CurriculumSelectionContract` para `PED-04`.
4. **PED-03C:** Desbloqueo de Firestore Emulator con JDK 21 (`demo-ginga-test`), aislamiento de estado entre suites en [test_curriculum_importer.js](file:///Users/jumper/ginga_app/scripts/test_curriculum_importer.js), verificación explícita de los `21` tutoriales y `5` videos reales, actualización documental integral y propuesta de respaldo Git.

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

# 5. Compilar preview web aislado (sin Firebase de producción)
/Users/jumper/development/flutter/bin/flutter build web --release --pwa-strategy=none -t lib/main_biblioteca_preview.dart -o /tmp/ginga_ped03b_preview

# 6. Suites del agente WhatsApp (referencia)
node real_agent_harness/test_p1a_runtime_guard.js
node real_agent_harness/test_qa_regressions.js
```

---

## 4. Qué Sigue Exactamente (Siguiente Tarea)

1. **Aprobación del propietario para respaldo Git (`PED-03C`):**
   - Revisar el inventario de archivos propuesto y aprobar la creación de la rama dedicada (p. ej. `feat/ped03-biblioteca-curricular`) y su commit de respaldo, excluyendo binarios `demo/assets/backup/*.mp4`, `PRE_LIVE_BASELINE.md` y archivos temporales.
2. **Inicio de `PED-04` (Planificador Pedagógico IA y Pizarra):**
   - Evolucionar `generarPlanClaseIA` e `InstructorPizarraScreen` consumiendo `CurriculumRepository.buildAiPlannerCurriculumPayload(...)` y el selector opt-in `CurriculumSelectionContract` documentado en [CURRICULUM_AI_PLANNER_CONTRACT.md](file:///Users/jumper/ginga_app/docs/CURRICULUM_AI_PLANNER_CONTRACT.md).
   - Evaluar autorización explícita previa antes de cualquier importación de `curriculum_*` o despliegue de `firestore.rules` / `firestore.indexes.json` hacia `capoeirafiu-ea8ljo`.

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
