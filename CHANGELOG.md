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

## [P0.2A Local] — 2026-11-11
### [PROBADO LOCALMENTE] (Rama `fix/real-whatsapp-logic` — Pendiente de Commit por Usuario)
- **P0.2A: Reprogramación Segura e Integridad de Reservas:**
  - **Herramienta `reprogramar_reserva`:**
    - Creada en `AVAILABLE_TOOLS` de `functions/index.js`.
    - Modifica la fecha de una reserva confirmada de forma atómica con `runTransaction`.
    - Mantiene trazabilidad histórica completa en el arreglo `reprogramaciones` (`fecha_anterior`, `nueva_fecha`, `motivo`, `fecha_reprogramacion`).
    - Valida contra el patrón de días de clase (`M, J`), cupos disponibles (`cupos_disponibles > 0`) y vigencia temporal en `America/Lima`.
    - Emite notificaciones in-app al instructor correspondiente (`users/{instId}/notificaciones`).
  - **Corrección de Duplicados en `reservar_clase_prueba`:**
    - Reservas canceladas (`status == 'cancelado'`) o pasadas ya no bloquean una nueva reserva de clase de prueba.
    - Detección de reservas confirmadas activas sugiere el uso de `reprogramar_reserva` en lugar de duplicar o bloquear a ciegas.
  - **Política Comercial:**
    - Leads o asistentes con historial `asistio` o `no_asistio` no reciben segundas clases gratuitas automáticas.
    - Se interceptan tanto en agendamiento como en reprogramación y se derivan con `marcar_seguimiento_humano`.
  - **Concurrencia e Idempotencia Transaccional:**
    - Lock optimista dentro de `runTransaction` usando `reservas_activas: { [slug]: ... }` en el documento `whatsapp_leads/{leadId}`.
    - Previene inserciones dobles por mensajes concurrentes o reintentos rápidos de webhook.
  - **Soporte Multi-Hijo No Destructivo:**
    - `guardar_perfil_lead` actualiza perfiles mediante fusión por slug (`slugifyPersona`), evitando la sobreescritura de hijos registrados previamente.
  - **Retrocompatibilidad Multi-Sede:**
    - Soporte completo y seguro para documentos y clases legacy que no cuenten con el atributo `sede_id`.
  - **Suites de Pruebas:**
    - `test_p02a_rescheduling.js`: 22 de 22 pruebas aprobadas (100% PASS).
    - `test_p01_recognition.js`: 14 de 14 pruebas aprobadas (100% PASS).
    - `suite_runner.js`: Defectos de línea base reducidos de 6 a 2 (Casos 3, 4, 6 y 7 resueltos).

---

## [Unreleased / Siguiente Paso]
### [DISEÑADO - PENDIENTE IMPLEMENTACIÓN]
- **P0.2B / P1: Detección y Prevención de Alucinaciones en Runtime & Visualización Staging:**
  - Validador en tiempo real de promesas conversacionales en `preguntarIA`.
  - Panel administrativo visual para inspección de telemetría y control humano.
