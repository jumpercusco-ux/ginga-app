# Guía de Reanudación Rápida (HANDOFF)

> **Propósito:** Permite a cualquier agente, chat o desarrollador retomar el trabajo en GINGA de inmediato, con contexto 100% verificado y sin depender del historial de conversación.

---

## 1. Estado Inmediato del Proyecto

- **Proyecto:** `/Users/jumper/ginga_app`
- **Rama Activa:** `fix/real-whatsapp-logic`
- **Commit Base:** `df2650e` (`feat(agent): implement safe rescheduling tool, duplicate prevention, and transactional integrity (P0.2A)`)
- **Estado de Trabajo:** Implementación de **P0.2B: Identidad familiar y reservas múltiples** completada y verificada al 100%. **PENDIENTE DE COMMIT LOCAL.**
- **Producción:** Google Cloud Function `whatsappWebhook v67` (asociada a `main` en commit `3058ada`). **Producción NO ha sido tocada.**

---

## 2. Qué se Acaba de Terminar

1. **Implementación de P0.2B (Identidad Familiar y Reservas Múltiples):**
   - **Resolución de Identidad No Ambigua:** Ante términos genéricos ("mi hijo", "el nene", etc.), el bot no asume el primer perfil (`personas[0]`) sino que solicita clarificación explícita con los nombres de pila de la familia.
   - **Prohibición de Nombre de Contacto en Niños:** Clases infantiles (`tipo === 'niño'`) no usan el nombre del padre/madre en el perfil si no se especificó el nombre del menor.
   - **Trazabilidad y Reconciliación de Hermanos:** `reservas_activas` preserva a todos los hijos al registrar o reprogramar, auto-migrando documentos legacy.
   - **Aislamiento Estricto:** Estados de cancelación, inasistencia o asistencia previa de un hijo no afectan ni bloquean a los demás.
   - **Seguridad de Autorización:** Control estricto en `reprogramar_reserva` y aborto transaccional `UNAUTHORIZED_RESERVATION` en `reprogramarClasePruebaLead` ante intentos de operar reservas ajenas.
   - **Resolución de Homónimos:** Exige desambiguación por `reserva_id` o fecha/horario si dos alumnos tienen el mismo nombre en la misma familia.
   - **10 de 10 pruebas P0.2B superadas al 100% (`test_p02b_family_identity.js`).**
   - **22 de 22 pruebas P0.2A conservadas al 100% (`test_p02a_rescheduling.js`).**
   - **14 de 14 pruebas P0.1 conservadas al 100% (`test_p01_recognition.js`).**
   - **Suite de línea base:** Defectos reducidos a 1 (Caso 5 resuelto).

---

## 3. Comandos Esenciales de Ejecución y Pruebas

```bash
# 1. Iniciar o reiniciar el servidor visual de pruebas en segundo plano (puerto 3333)
node real_agent_harness/server.js

# 2. Ejecutar la suite de identidad familiar P0.2B (10 pruebas)
node real_agent_harness/test_p02b_family_identity.js

# 3. Ejecutar la suite de reprogramación P0.2A (22 pruebas)
node real_agent_harness/test_p02a_rescheduling.js

# 4. Ejecutar la suite de reconocimiento P0.1 (14 pruebas)
node real_agent_harness/test_p01_recognition.js

# 5. Ejecutar la suite de línea base (9 escenarios de auditoría)
node real_agent_harness/suite_runner.js

# 6. Verificar integridad de git
git status
git diff functions/index.js
```

---

## 4. Qué Sigue Exactamente (Siguiente Tarea)

1. **Commit local de P0.2B.**
2. Avanzar hacia **P1 / Agent Control Center & Runtime Anti-Hallucination Guard (Caso 8).**

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
