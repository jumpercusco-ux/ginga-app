# Guía de Reanudación Rápida (HANDOFF)

> **Propósito:** Permite a cualquier agente, chat o desarrollador retomar el trabajo en GINGA de inmediato, con contexto 100% verificado y sin depender del historial de conversación.

---

## 1. Estado Inmediato del Proyecto

- **Proyecto:** `/Users/jumper/ginga_app`
- **Rama Activa:** `fix/real-whatsapp-logic`
- **Último Commit:** `9c53417` (`fix(agent): recognize confirmed trial reservations in conversation context`)
- **Producción:** Google Cloud Function `whatsappWebhook v67` (asociada a `main` en commit `3058ada`). **Producción NO tiene aún los cambios de P0.1**.

---

## 2. Qué se Acaba de Terminar

1. **Creación del Harness de Pruebas Aislado (`real_agent_harness/`):**
   - Servidor HTTP local en `http://127.0.0.1:3333`.
   - Ejecuta directamente el código real de `functions/index.js` en memoria mediante Node.js `vm`.
   - Emulación completa de Firestore, OpenAI y WhatsApp sin red ni costos.
2. **Implementación de P0.1 (Reconocimiento de Reservas):**
   - `generarSystemPrompt` recibe `leadId` y consulta `/reservas` activas futuras o de hoy en horario `America/Lima`.
   - Inyecta el bloque contextual `[RESERVAS CONFIRMADAS VIGENTES DE ESTE LEAD]` con reglas obligatorias para no pedir datos redundantes.
   - Neutralidad de género garantizada y fail-safe ante fallos de Firestore.
   - **14 de 14 pruebas de P0.1 pasaron (100% PASS).**
3. **Auditoría de Tools y Línea Base:**
   - 7 de 9 escenarios de la versión base `3058ada` documentaron defectos conocidos (amnesia, colisión de reprogramación, duplicados en canceladas, etc.).

---

## 3. Comandos Esenciales de Ejecución y Pruebas

```bash
# 1. Iniciar el servidor visual de pruebas en segundo plano (puerto 3333)
node real_agent_harness/server.js

# 2. Ejecutar la suite de pruebas de reconocimiento P0.1 (14 pruebas)
node real_agent_harness/test_p01_recognition.js

# 3. Ejecutar la suite de línea base (9 escenarios de auditoría)
node real_agent_harness/suite_runner.js

# 4. Verificar integridad de git
git status
git log -3 --oneline
```

---

## 4. Qué Sigue Exactamente (Siguiente Tarea)

**Implementar P0.2: Reprogramación, Resolución de Duplicados y Multi-Persona:**
1. Crear la herramienta `reprogramar_reserva` en `functions/index.js` para modificar atómicamente la fecha de una reserva existente en Firestore.
2. Ajustar `reservar_clase_prueba` para que las reservas canceladas (`status == 'cancelado'`) o pasadas no bloqueen nuevas reservas.
3. Trasladar el chequeo de duplicados dentro de `runTransaction` para garantizar idempotencia y evitar race conditions.
4. Mejorar `guardar_perfil_lead` para fusionar personas por nombre en vez de sobrescribir todo el array.

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
