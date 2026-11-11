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

## [Unreleased / Siguiente Paso]
### [DISEÑADO - PENDIENTE IMPLEMENTACIÓN]
- **P0.2: Reprogramación, Resolución de Duplicados y Multi-Persona:**
  - Nueva tool `reprogramar_reserva` para cambios de fecha atómicos.
  - Corrección de colisión de duplicados en `reservar_clase_prueba` para permitir reservas tras cancelaciones o fechas vencidas.
  - Idempotencia transaccional moviendo el chequeo de duplicados dentro de `runTransaction`.
  - Fusión de personas por nombre en `guardar_perfil_lead`.
