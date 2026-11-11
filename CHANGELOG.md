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

## [b536a0b] — 2026-11-11
### [COMMIT LOCAL: b536a0b] (Rama `fix/real-whatsapp-logic`)
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
