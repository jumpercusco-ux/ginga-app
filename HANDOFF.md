# Guía de Reanudación Rápida (HANDOFF)

> **Propósito:** Permite a cualquier agente, chat o desarrollador retomar el trabajo en GINGA de inmediato, con contexto 100% verificado y sin depender del historial de conversación.

---

## 1. Estado Inmediato del Proyecto

- **Proyecto:** `/Users/jumper/ginga_app`
- **Rama Activa:** `fix/real-whatsapp-logic`
- **Commit Base:** `b536a0b` (`fix(agent): deterministic human/cancel escalation, runtime guard refinement and qa regressions`)
- **Estado de Trabajo:** **Release Candidate (RC) Gate Evaluado — Estado CONDITIONAL**.
  - Primer QA OpenAI real ejecutado (`qa_run_1794437359075_vmx6tf`): 9/12 PASS, 3 FAIL (Casos 2, 9 y 11), US$0.0016 de costo.
  - Correcciones funcionales aplicadas en `functions/index.js`, `real_agent_harness/qa_openai_runner.js` y `scratch/run_live_qa.sh`.
  - Nueva suite de regresiones: `test_qa_regressions.js` (18/18 PASS).
  - 100/100 pruebas offline PASS (14 P0.1 + 22 P0.2A + 10 P0.2B + 27 P1A + 9 baseline + 18 regresiones).
  - 8/8 pruebas reales en Firestore Emulator (Java 21) PASS.
  - Total: **108 de 108 pruebas superadas (100% PASS)** y 12/12 escenarios dry-run verificados.
  - Bloqueo para producción: Mantener CONDITIONAL hasta validar 12/12 PASS en reintento real de QA con OpenAI.
- **Producción:** Google Cloud Function `whatsappWebhook v67` (asociada a `main` en commit `3058ada`). **Producción NO ha sido tocada.**

---

## 2. Qué se Acaba de Terminar

1. **Implementación y Cierre de Seguridad P1A (Runtime Guard y Telemetría Zero PII):**
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
   - **Resultados de Suites de Pruebas:**
     - `test_p1a_runtime_guard.js`: **27 de 27 pruebas aprobadas (100% PASS)**.
     - `test_p01_recognition.js`: 14 de 14 pruebas aprobadas (100% PASS).
     - `test_p02a_rescheduling.js`: 22 de 22 pruebas aprobadas (100% PASS).
     - `test_p02b_family_identity.js`: 10 de 10 pruebas aprobadas (100% PASS).
     - `suite_runner.js`: **9 de 9 escenarios OK (0 defectos baseline restantes)**. Caso 8 de falsa confirmación quedó definitivamente resuelto.
     - **Total acumulado:** **82 de 82 pruebas aprobadas (100% PASS)**.

---

## 3. Comandos Esenciales de Ejecución y Pruebas

```bash
# 1. Iniciar o reiniciar el servidor visual de pruebas en segundo plano (puerto 3333)
node real_agent_harness/server.js

# 2. Ejecutar la suite de Runtime Guard y Telemetría P1A (16 pruebas)
node real_agent_harness/test_p1a_runtime_guard.js

# 3. Ejecutar la suite de identidad familiar P0.2B (10 pruebas)
node real_agent_harness/test_p02b_family_identity.js

# 4. Ejecutar la suite de reprogramación P0.2A (22 pruebas)
node real_agent_harness/test_p02a_rescheduling.js

# 5. Ejecutar la suite de reconocimiento P0.1 (14 pruebas)
node real_agent_harness/test_p01_recognition.js

# 6. Ejecutar la suite de línea base (9 escenarios de auditoría)
node real_agent_harness/suite_runner.js

# 7. Ejecutar la suite de regresiones QA (18 pruebas Casos 2, 9 y 11, persistencia y tests negativos)
node real_agent_harness/test_qa_regressions.js

# 8. Ejecutar la suite real de Firestore Emulator (Java 21, puerto 8080)
PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH" JAVA_HOME="/opt/homebrew/opt/openjdk@21" firebase emulators:exec --only firestore "node real_agent_harness/test_emulator_integration.js" --project demo-ginga-test

# 9. Ejecutar el QA Runner aislado (Dry-Run offline con Firestore Emulator)
PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH" JAVA_HOME="/opt/homebrew/opt/openjdk@21" firebase emulators:exec --only firestore "node real_agent_harness/qa_openai_runner.js" --project demo-ginga-test

# 10. Verificar integridad de git
git status
git diff functions/index.js
```

---

## 4. Qué Sigue Exactamente (Siguiente Tarea)

1. **Reintento Seguro del QA Conversacional Real (Acción Mínima del Usuario):**
   Ejecutar en la terminal interactiva de macOS el script robustecido con diagnóstico:
   ```bash
   ./scratch/run_live_qa.sh
   ```
   *El script solicita la clave `ginga-qa-local` mediante `read -s` (compatible zsh/bash, sin eco), ejecuta la suite de 12 escenarios en el emulador, canaliza logs en vivo a `scratch/qa_execution.log`, limpia la memoria con trap y exporta el reporte auditado a `scratch/qa_report_latest.json` con `runId` único y distinción clara de fallos.*
2. **Auditar métricas reales en el reporte generado:** Leer `scratch/qa_report_latest.json` y verificar `runId`, `mode: "LIVE_REAL_OPENAI"`, latencia por turno, tools ejecutadas, tokens y costo real consumido (< $0.25 USD).
3. **Decisión de Gate:** Con los resultados de OpenAI real verificados, evaluar transición de CONDITIONAL a READY para staging/despliegue quirúrgico.

---

## 5. Qué NO se Debe Modificar

- **NO modificar `main` ni `stabilization/pre-live-2026-10-28`:** Son ramas de referencia congeladas.
- **NO modificar la carpeta `demo/`:** Pertenece exclusivamente a la demo visual de TikTok LIVE.
- **NO eliminar `PRE_LIVE_BASELINE.md`:** Archivo de auditoría pre-LIVE preservado como untracked.
- **NO hacer push ni deploy a Firebase/GCP:** Todo el trabajo se mantiene 100% local en `fix/real-whatsapp-logic` hasta la aprobación final.
- **NO llamar a APIs reales con costo:** Usar siempre los adaptadores del harness local.

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
