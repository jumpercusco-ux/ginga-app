# Historial de Cambios (CHANGELOG)

Todas las modificaciones notables del proyecto GINGA se documentan cronológicamente en este archivo.

Las entradas se clasifican rigurosamente según su estado de despliegue:
- **[PUBLICADO EN PRODUCCIÓN]:** Desplegado y activo en Google Cloud Functions o Firebase Console.
- **[PROBADO LOCALMENTE]:** Verificado exhaustivamente con suites de pruebas locales aisladas; no desplegado.
- **[IMPLEMENTADO]:** Escrito en código o documentación local pendiente de pruebas o despliegue.

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
    - Verificación dinámica de sedes desde la colección `/sedes`.
    - Controles de seguridad y presupuesto: Flag `ENABLE_REAL_OPENAI_QA=false` por defecto, límite de $0.25 USD y 30 llamadas máximo, registro Zero PII sin teléfonos ni datos privados.
    - Modo Dry-Run offline verificado al 100% (12 de 12 escenarios PASS).
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
