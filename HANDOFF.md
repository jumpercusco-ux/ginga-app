# Guía de Reanudación Rápida (HANDOFF)

> **Propósito:** Permite a cualquier agente, chat o desarrollador retomar el trabajo en GINGA de inmediato, con contexto 100% verificado y sin depender del historial de conversación.

---

## 1. Estado Inmediato del Proyecto

- **Proyecto:** `/Users/jumper/ginga_app`
- **Rama Activa:** `fix/real-whatsapp-logic`
- **Commit Base:** `264e314` (`docs: establish permanent architectural documentation master files`)
- **Estado de Trabajo:** Implementación local de **P0.2A: Reprogramación segura e integridad de reservas** completada y verificada. **PENDIENTE DE REVISIÓN DEL USUARIO ANTES DE COMMIT.**
- **Producción:** Google Cloud Function `whatsappWebhook v67` (asociada a `main` en commit `3058ada`). **Producción NO ha sido tocada.**

---

## 2. Qué se Acaba de Terminar

1. **Implementación de P0.2A (Reprogramación Segura e Integridad de Reservas):**
   - **Tool `reprogramar_reserva`:** Creada en `functions/index.js` (`AVAILABLE_TOOLS`). Permite reprogramar citas atómicamente con trazabilidad completa en `reprogramaciones` y notificación al instructor.
   - **Corrección de Duplicados en `reservar_clase_prueba`:** Ya no bloquea citas si existen reservas previas canceladas o pasadas.
   - **Política Comercial:** Leads o personas con estado `asistio` o `no_asistio` son interceptados y derivados a `marcar_seguimiento_humano` sin conceder segundas clases de prueba gratis de forma automática.
   - **Concurrencia e Idempotencia:** Lock transaccional dentro de `runTransaction` usando `reservas_activas: { [slug]: ... }` en `whatsapp_leads` para evitar colisiones por mensajes concurrentes.
   - **Soporte Multi-Hijo:** `guardar_perfil_lead` fusiona perfiles por slug en vez de sobreescribir destructivamente el arreglo.
   - **Compatibilidad Multi-Sede y Legacy:** Clases o reservas sin `sede_id` operan limpiamente con fallback a Cusco.
   - **22 de 22 pruebas P0.2A superadas al 100% (`test_p02a_rescheduling.js`).**
   - **14 de 14 pruebas P0.1 conservadas al 100% (`test_p01_recognition.js`).**
2. **Harness Local Actualizado:**
   - Servidor local en `http://127.0.0.1:3333` actualizado y corriendo.
   - `loader.js` y `openai_adapter.js` adaptados para soportar `reprogramar_reserva`.

---

## 3. Comandos Esenciales de Ejecución y Pruebas

```bash
# 1. Iniciar o reiniciar el servidor visual de pruebas en segundo plano (puerto 3333)
node real_agent_harness/server.js

# 2. Ejecutar la suite de pruebas de reprogramación P0.2A (22 pruebas)
node real_agent_harness/test_p02a_rescheduling.js

# 3. Ejecutar la suite de pruebas de reconocimiento P0.1 (14 pruebas)
node real_agent_harness/test_p01_recognition.js

# 4. Ejecutar la suite de línea base (9 escenarios de auditoría)
node real_agent_harness/suite_runner.js

# 5. Verificar integridad de git (revisar diff local antes de commit)
git status
git diff functions/index.js
```

---

## 4. Qué Sigue Exactamente (Siguiente Tarea)

1. **Revisión del usuario de los cambios de P0.2A.**
2. Tras la aprobación del usuario, realizar commit local de P0.2A.
3. Avanzar hacia **P0.2B / P1: Detección y prevención de alucinaciones en tiempo real / Agent Control Center.**

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
