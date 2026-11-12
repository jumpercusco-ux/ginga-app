# MANIFIESTO DE RELEASE CANDIDATE: GINGA REAL V1
# RELEASE-CANDIDATE-GINGA-V1.md

> **Estado del Manifiesto:** `RELEASE CANDIDATE CLOSED LOCALLY — NOT DEPLOYED`  
> **Fecha de Cierre Local:** 2026-11-11  
> **Proyecto Firebase/GCP Objetivo:** `capoeirafiu-ea8ljo`  
> **Cloud Function Objetivo:** `whatsappWebhook`  

---

## 1. Identificación del Release

* **Identificador de Versión:** `GINGA-REAL-RC-V1`
* **Rama de Trabajo:** `fix/real-whatsapp-logic`
* **Commit Funcional Validado:** [`1197225bffffd7f2453984a3d3662cf5293402f2`](file:///Users/jumper/ginga_app) (`1197225`)
* **HEAD Remoto de Producción (Referencia Git):** `main` en [`3058adad97549c059e729b66fd8d1040cd5b91cd`](file:///Users/jumper/ginga_app) (`3058ada`, tag `pre-live-original-2026-10-27`)
* **Revisión Activa en Google Cloud Platform:** Cloud Functions Gen 1, región `us-central1`, `versionId: 67` (actualizada `2026-10-23T04:47:06.322Z`)

---

## 2. Alcance Funcional del Release

El release candidate consolida la reingeniería y blindaje de la atención automatizada por WhatsApp:

1. **Memoria de Reservas Previas (P0.1):**
   * Inyección contextual obligatoria en el system prompt antes de evaluar mensajes del lead.
   * Supresión de repreguntas de registro (nombre, edad) y ofertas redundantes para leads con reservas vigentes.
2. **Reprogramación Segura e Integridad Transaccional (P0.2A):**
   * Herramienta determinista `reprogramar_reserva` con actualización de `/reservas` y auditoría en `historial_reprogramaciones`.
   * Bloqueo de segundas clases gratuitas para leads con status `asistio` y derivación para `no_asistio`.
3. **Aislamiento de Identidad Familiar y Homónimos (P0.2B):**
   * Reconciliación estricta de hermanos en `reservas_activas` mediante identificadores canónicos y slug completo.
   * Bloqueo preventivo de mutaciones ante colisiones de nombres de pila idénticos sin identificador explícito.
4. **Runtime Guard Post-Generación Determinista (P1A):**
   * Intercepción semántica en `preguntarIA` antes del egreso hacia WhatsApp.
   * Validación estricta de afirmaciones de agendamiento, reprogramación o cancelación contra `turnContext.toolRecords`.
   * Sustitución fail-safe por mensaje de contención y marcado automático a `requiere_atencion` ante cualquier alucinación no respaldada en base de datos.
5. **Telemetría Segura Zero PII (P1A):**
   * Anonimización HMAC-SHA256 de identificadores telefónicos (`lead_hash`) y ofuscación de nombres de menores (`persona_ref`).

---

## 3. Evidencia de QA Conversacional Real OpenAI (`gpt-4o-mini`)

* **Identificador de Ejecución (`runId`):** `qa_run_1794446882861_tdvxf6`
* **Modo de Ejecución:** `LIVE_REAL_OPENAI`
* **Entorno de Prueba:** Firestore Emulator local (`127.0.0.1:8080`, proyecto sintético `demo-ginga-test`)
* **Resultado Global:** **12 de 12 Escenarios PASS (100% de éxito)**
  * **11 turnos evaluados contra inferencia real de `gpt-4o-mini`:**
    - Caso 1 (Reserva nueva Camila Rivera): PASS (`guardar_perfil_lead` + `reservar_clase_prueba`).
    - Caso 2 (Reserva vigente Daniela Perez): PASS (reconocimiento contextual sin tools espurias).
    - Caso 3 (Reprogramación Carlos Morales): PASS (`reprogramar_reserva` a martes 17 a las 18:00).
    - Caso 4 (Dos hijos Mateo y Sofía): PASS (reserva independiente de segundo hijo preservando al primero).
    - Caso 5 (Lead con asistencia previa): PASS (bloqueo de segunda clase gratis y derivación humana).
    - Caso 6 (Inasistencia previa): PASS (derivación para evaluación docente).
    - Caso 7 (Falta de cupos): PASS (solicitud de datos sin comprometer cupos inexistentes).
    - Caso 8 (Datos incompletos): PASS (solicitud de nombre y edad antes de agendar).
    - Caso 9 (Cancelación): PASS (derivación administrativa sin promesas falsas de anulación inmediata).
    - Caso 10 (Consulta sede Cusco): PASS (`consultar_horarios_disponibles` con datos de Cusco).
    - Caso 11 (Atención humana explícita): PASS (`marcar_seguimiento_humano` -> `requiere_atencion`).
  * **1 escenario inducido localmente (Caso 12):**
    - Simulación de afirmación alucinada para auditar la respuesta del Runtime Guard. Interceptada deterministamente en **29 ms** con sustitución fail-safe y marcado en Firestore.
* **Métricas de Consumo:**
  * Solicitudes HTTP salientes a OpenAI: 19 llamadas (11 turnos + tool calling loops).
  * Tokens de Prompt: 55,332 | Tokens de Completion: 613.
  * Costo Real Estimado: **US$ 0.0087**.
* **Firewall de Red Local:** 1 solicitud saliente hacia `graph.facebook.com` interceptada y bloqueada al 100%. Cero llamadas a Firestore productivo. Código de salida: 0.

---

## 4. Matriz de Pruebas Automatizadas del Backend

| Suite de Pruebas | Archivo de Prueba | Casos | Resultado | Estado |
| :--- | :--- | :---: | :---: | :---: |
| **P1A: Runtime Guard & Telemetría** | `test_p1a_runtime_guard.js` | 27 / 27 | PASS | 100% |
| **P0.1: Memoria de Reservas** | `test_p01_recognition.js` | 14 / 14 | PASS | 100% |
| **P0.2A: Reprogramación Transaccional** | `test_p02a_rescheduling.js` | 22 / 22 | PASS | 100% |
| **P0.2B: Identidad Familiar** | `test_p02b_family_identity.js` | 10 / 10 | PASS | 100% |
| **Baseline Audit** | `suite_runner.js` | 9 / 9 | PASS | 100% |
| **Regresiones Casos 1, 2, 3, 4, 9, 11** | `test_qa_regressions.js` | 33 / 33 | PASS | 100% |
| **Integración con Firestore Emulator** | `test_emulator_integration.js` | 8 / 8 | PASS | 100% |
| **Total Backend Automatizado** | — | **123 / 123** | **PASS** | **100%** |
| **QA Dry-Run Offline** | `qa_openai_runner.js` | 12 / 12 | PASS | 100% |
| **Total General de Validaciones** | — | **135 / 135** | **PASS** | **100%** |

---

## 5. Checksums Criptográficos SHA-256 de Archivos de Runtime

Verificados sobre el árbol de trabajo local en commit [`1197225`](file:///Users/jumper/ginga_app):

```text
6b636ab79d3c5070f43725d5bd52731d78c2e9025ba16a0ae84454e979ed2abd  functions/index.js
38e04c545bcd8b4e660b9651a748a678fd551f12b6e3d1c6e2845829dd876ef4  functions/package.json
3fd3442b5233942c3a7c055c57711ba510308d6447c287c8de1842e43824be1f  functions/package-lock.json
```

---

## 6. Configuración Comercial Productiva Verificada en Google Cloud / Firestore

Inspección de solo lectura autorizada (Prompt 49) sobre `capoeirafiu-ea8ljo`:

* **Sede Oficial y Dirección:** Av. de la Cultura E-4, Urb. Magisterio. Referencia: Edificio Divergym, 3er piso (al costado de la Caja Arequipa), Cusco.
* **Clases Regulares Activas (`/clases`):**
  1. *Kids (Iniciantes, ID `0fqjSJvbu64NqdqVrYAw`):* Martes y Jueves 18:00 – 19:00. Edades: 5 a 12 años. Cupos publicados: 10. Clase gratuita: `true`.
  2. *Adultos (Iniciantes, ID `WmwSTWfZvBpZtLdXDk6W`):* Martes y Jueves 19:00 – 20:00. Edades: 13 a 99 años. Cupos publicados: 3. Clase gratuita: `true`.
* **Tarifas Comerciales (`config/negocio`):**
  * Mensualidad regular: S/ 140
  * Promo acompañados (2 personas): S/ 260
  * Promos pago adelantado multimes: 1 mes: S/ 140, 2 meses: S/ 260, 3 meses: S/ 380, 6 meses: S/ 700.
* **Documento `config/whatsapp_agent`:** Confirmada existencia en Firestore (actualizado `2026-09-07T01:07:59Z`). Contenido no descargado ni inspeccionado para preservar confidencialidad y no asumir equivalencia con el prompt de prueba.

---

## 7. Diferencias entre QA Emulator y Entorno Productivo

| Variable | Fixture Sintético QA (`qa_openai_runner.js`) | Producción Real (`capoeirafiu-ea8ljo`) | Nota Técnica |
| :--- | :--- | :--- | :--- |
| **Sede** | Calle Hospital 840, 2do piso (Cusco Centro) | Av. de la Cultura E-4, Urb. Magisterio (Divergym 3er piso) | El dato de Calle Hospital es un fixture artificial de prueba; Magisterio es la sede real. |
| **Horario Kids** | Martes y Jueves 17:00 – 18:00 (edades 4–13) | Martes y Jueves 18:00 – 19:00 (edades 5–12) | Producción inicia a las 18:00 para niños. |
| **Horario Adultos**| Martes y Jueves 18:00 – 19:30 (edades 14–80) | Martes y Jueves 19:00 – 20:00 (edades 13–99) | Producción inicia a las 19:00 para adultos. |
| **Base de Datos** | Emulador local en memoria (`demo-ginga-test`) | Cloud Firestore nativo (`capoeirafiu-ea8ljo`) | La tool `consultar_horarios_disponibles` lee dinámicamente de Firestore sin hardcoding. |

---

## 8. Estado de Secrets y Variables de Entorno en GCP

| Nombre de Secreto | Estado en Secret Manager | Vinculación en Función | Versión en GCP | Estado de Verificación |
| :--- | :---: | :---: | :---: | :---: |
| `META_VERIFY_TOKEN` | `EXISTS` | `BOUND_TO_FUNCTION` | `VERSION_ENABLED` (v2) | **VERIFIED** |
| `META_APP_SECRET` | `EXISTS` | `BOUND_TO_FUNCTION` | `VERSION_ENABLED` (v1) | **VERIFIED** |
| `META_WHATSAPP_TOKEN` | `EXISTS` | `BOUND_TO_FUNCTION` | `VERSION_ENABLED` (v2) | **VERIFIED** |
| `META_PHONE_NUMBER_ID`| `EXISTS` | `BOUND_TO_FUNCTION` | `VERSION_ENABLED` (v1) | **VERIFIED** |
| `OPENAI_API_KEY` | `EXISTS` | `BOUND_TO_FUNCTION` | `VERSION_ENABLED` (v1) | **VERIFIED** |
| `TELEMETRY_SALT` | `MISSING` | `NOT_BOUND` | `N/A` | **FALLBACK EFÍMERO ACTIVO** |

* **Detalle `TELEMETRY_SALT`:** No está presente en Secret Manager ni en `environmentVariables`. La función utiliza el fallback no bloqueante `crypto.randomBytes(32)` por cold start. Los hashes de lead en telemetría varían entre instancias, sin afectar la atención comercial.

---

## 9. Dependencias Operativas

* **Cloud Functions:** Firebase Functions v4.4.1 sobre Google Cloud Functions Gen 1, Node.js 20.
* **Modelo LLM:** OpenAI `gpt-4o-mini` (temperatura 0.1, tope de 4 rondas de tool-calling).
* **Meta WhatsApp Cloud API:** Graph API v20.0 con Webhooks firmados vía HMAC-SHA256.

---

## 10. Riesgos Residuales y Bloqueadores Identificados

1. **Riesgo Crítico de CI/CD Automático:**
   * El archivo [`.github/workflows/deploy.yml`](file:///Users/jumper/ginga_app/.github/workflows/deploy.yml#L49-L68) activa el despliegue de **todas las 10 Cloud Functions** (`deploy --only functions`) ante cualquier push a `main`.
   * **Mitigación:** Prohibición absoluta de push a `main`. Despliegue restringido exclusivamente a CLI quirúrgico: `firebase deploy --only functions:whatsappWebhook --project capoeirafiu-ea8ljo`.
2. **Plataforma Gen 1 sin División de Tráfico:**
   * No existe conmutador gradual ni rollback en < 2 minutos. Toda actualización o reversión sobreescribe la versión activa.
3. **Equivalencia Binaria de `v67`:**
   * `v67` fue desplegada el 2026-10-23. El commit `3058ada` es del 2026-10-27. No existe prueba de identidad binaria bit a bit, aunque `3058ada` representa la fuente de verdad de Git más fiel disponible.

---

## 11. Estrategia de Rollback Respaldada

* **Mecanismo:** Re-despliegue quirúrgico de la versión base mediante worktree aislado (sin modificar el workspace principal ni la rama activa).
* **Worktree Preparado Localmente:**
  * Ruta: `/private/tmp/ginga_rollback_baseline`
  * Commit: [`3058ada`](file:///Users/jumper/ginga_app) (detached HEAD, tag `pre-live-original-2026-10-27`)
  * Checksum SHA-256 de `functions/index.js` en rollback:  
    `4762d1fb1600017b747de8e26909b418d1de21fbc78b82defa72f9b38baf265a`
* **Comando de Rollback (Solo bajo autorización si se requiere revertir):**
  ```bash
  cd /private/tmp/ginga_rollback_baseline/functions && npm ci
  firebase deploy --only functions:whatsappWebhook --project capoeirafiu-ea8ljo
  ```
* **Tiempo Estimado de Recuperación (RTO):** Entre **2 y 5 minutos** (empaquetado, Cloud Build y propagación de Cloud Functions Gen 1).

---

## 12. Estado de Aprobación

* **Aprobación de QA:** `QA APPROVED` (12/12 OpenAI real, 123/123 backend, 12/12 dry-run).
* **Aprobación de Despliegue:** `PRODUCTION NOT AUTHORIZED` (requiere decisión formal del usuario).

---

## 13. Checklist para el Día del Despliegue (Día D)

Este checklist es una guía operativa y documental; **no ejecuta ninguna acción por sí mismo**:

### Pre-Vuelo Inmediato:
- [ ] Confirmar que el usuario ha emitido la orden formal y expresa de despliegue.
- [ ] Verificar que la terminal interactiva está autenticada con la cuenta autorizada (`capoeirafiuapp@gmail.com`).
- [ ] Confirmar que el proyecto seleccionado es explícitamente `capoeirafiu-ea8ljo`.
- [ ] Verificar que la rama activa es `fix/real-whatsapp-logic` y el commit es [`1197225`](file:///Users/jumper/ginga_app).
- [ ] Confirmar que **NO se ejecuta git push a main**.

### Ejecución Quirúrgica:
- [ ] Ejecutar el comando selectivo único:
  ```bash
  firebase deploy --only functions:whatsappWebhook --project capoeirafiu-ea8ljo
  ```
- [ ] Verificar en Google Cloud Console que la revisión incrementa a `v68` y estado `ACTIVE`.
- [ ] Confirmar que las 9 funciones restantes conservan sus versiones previas intactas.

### Smoke Test de Producción (Contacto Interno Exclusivo):
- [ ] Utilizar exclusivamente el número de prueba interno registrado en Meta Business Suite.
- [ ] Mensaje 1: `"Hola, ¿qué horarios tienen para niños y dónde quedan en Cusco?"` -> Validar respuesta < 5s con sede Magisterio y horario 18:00–19:00.
- [ ] Mensaje 2: `"Mi hijo se llama Joaquín, tiene 7 años y queremos agendar para este próximo martes"` -> Validar reserva en `/reservas` y confirmación cordial.
- [ ] Mensaje 3: `"¿Podría ir Joaquín este sábado en vez del martes?"` -> Validar aclaración de días hábiles (martes y jueves) sin corromper la cita del martes.
- [ ] Mensaje 4: `"Quiero consultar un caso de salud directamente con el profesor"` -> Validar escalación a `requiere_atencion`.
- [ ] Limpieza post-prueba: eliminar la reserva y el lead del contacto de prueba en Firestore.

### Control de Contingencia:
- [ ] Si ocurre un error 500 no controlado o degradación crítica: ejecutar el comando de rollback desde `/private/tmp/ginga_rollback_baseline`.
