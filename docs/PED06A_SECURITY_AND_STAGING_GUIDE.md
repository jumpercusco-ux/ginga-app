# PED-06A — Bloqueadores P0 Resueltos y Guía de Preparación para Staging

> **Alcance:** Cierre de hallazgos de seguridad P0 (`firestore.rules`, `functions/index.js`, roles y seeds Flutter) sin modificar producción (`capoeirafiu-ea8ljo`) ni crear infraestructura cloud todavía.

---

## 1. Bloqueadores P0 Resueltos y Evidencia de Verificación

| Bloqueador P0 | Corrección Implementada | Evidencia Verificada |
|---|---|---|
| **Auto-escalación y exposición de PII en `/users/{uid}`** | Lectura restringida al propio usuario o `isStaff()`. Creación de alumno acotada a `rol == 'alumno'` y `status == 'nuevo'`. Actualización del propietario limitada mediante `affectedKeys().hasOnly([...])` prohibiendo mutar `rol`, `corda`, `clase_id`, `fecha_inicio`, `uid` y `email`, y permitiendo únicamente transiciones válidas de `status` (`nuevo -> prueba`, `activo -> inactivo`). | `test_ped06a_security_emulator.js` (`demo-ginga-test`): rechaza lectura/escritura cruzada, auto-elevación `rol`/`corda`/`status: activo` y acepta edición de ficha/FCM/QR legítima. |
| **Permisos abiertos `if request.auth != null` en colecciones legacy** | `pedidos`, `asistencias`, `reservas`, `clases`, `sesiones`, `pagos`, `tutoriales`, `cantigas`, `eventos`, `productos`, `config` y denegación explícita por defecto (`match /{document=**} { allow read, write: if false; }`). Los alumnos solo pueden decrementar `clases.cupos_disponibles` en `-1`, registrar `asistencias` contra una `sesion` activa, gestionar sus propias reservas/pedidos y leer el catálogo público autenticado. | `test_ped06a_security_emulator.js` + `CantigasService` protegido con guarda `UserRoleUtils.isStaff(rol)`. |
| **Acceso abierto a `whatsapp_leads` y `mensajes`** | Lectura y escritura restringidas estrictamente a `isStaff()` (`profesor` / `instructor` / `admin` / `administrador`). Alumnos y anónimos reciben `403 PERMISSION_DENIED`. | `test_ped06a_security_emulator.js` (`whatsapp_leads` y subcolección `mensajes`). |
| **Inconsistencia `'admin'` vs `'administrador'`** | Centralizada en `lib/core/utils/user_role_utils.dart` (`UserRoleUtils`), `functions/index.js` (`normalizeUserRole`), `functions/planner_v2/auth_and_quota_guard.js` y `firestore.rules` (`isAdmin()` / `isStaff()`). Además se creó `scripts/migrate_auth_roles_and_claims.js` (`--dry-run` e idempotente). | `test/user_role_utils_test.dart` + `test_ped06a_security_emulator.js`. |
| **Endpoints HTTP sin auth en `functions/index.js`** | `migrarMensajesHistoricos`, `ejecutarStressTestAI` y `actualizarMiniaturasExistentes` exigen `POST`, token Bearer verificado con `verifyIdToken` y **Custom Claim de admin** (`405`/`401`/`403`), rate limit, `dry_run: true` por defecto, guardia explícita `confirm_stress_test === true` + `ALLOW_STRESS_TEST_HTTP` en stress test y filtro anti-SSRF (`isSafePublicHttpUrl`) en `obtenerOgImage`. | `test_ped06a_security_emulator.js` verificando handlers reales con Firebase Auth mock + Firestore Emulator. |
| **Callables sin control de rol o validación fuerte** | `sendManualWhatsAppMessage` y `generarPlanClaseIA` exigen `profesor`/`admin`, rate limit (`20/min` y `4/min`) y validación estricta de `leadId`, texto, duración (`20..180`), límites de strings y existencia de lead. Motor V2 y Copiloto refuerzan claims firmados sin confiar en Firestore. | `test_ped06a_security_emulator.js` (`B01`–`B04`) + `test_agent_evaluations.js` + `test_reservation_date_semantics.js` + `test_firestore_rules.js`. |

### Riesgos y Limites Residuales Documentados
1. **Rate limiting en memoria en Cloud Functions Gen 1 (`RUNTIME_RATE_LIMIT_BUCKETS`):** protege ráfagas dentro de una misma instancia en caliente, pero no sincroniza entre múltiples instancias paralelas ni sustituye cuota persistente transaccional (el Motor V2 y Copiloto sí usan `FirestoreTransactionQuotaStore`).
2. **Firebase App Check:** aún no activado en clientes móviles/web (`capoeirafiu-ea8ljo`); recomendado activarlo junto con `ginga-staging`.
3. **Custom Claims en usuarios históricos de producción:** en producción actual (`capoeirafiu-ea8ljo`), algunos docentes legados solo poseen `users/{uid}.rol` sin Custom Claims firmados todavía. Las reglas generales aceptan ambos de forma segura (porque el alumno no puede editar `rol`), mientras `curriculum_*`, los endpoints HTTP administrativos y el futuro Planificador V2 remoto exigen Custom Claims firmados generados por script autorizado.

---

## 2. Requisitos Mínimos para Proyecto Firebase de Staging (`ginga-staging`)

> **Importante:** No crear infraestructura ni habilitar facturación hasta contar con aprobación explícita.

### 2.1 Firebase Authentication & Custom Claims
- Habilitar proveedor **Email/Password** en `ginga-staging` (y dominios autorizados para el preview web).
- Crear únicamente cuentas sintéticas de prueba (Cero PII real):
  - `admin_staging@ginga.test` -> Custom Claims: `{ admin: true, curriculum_admin: true, profesor: true, instructor: true, rol: 'admin' }`
  - `profesor_staging@ginga.test` -> Custom Claims: `{ admin: false, curriculum_admin: false, profesor: true, instructor: true, rol: 'profesor' }`
  - `alumno_staging@ginga.test` -> Custom Claims: `{ admin: false, curriculum_admin: false, profesor: false, instructor: false, rol: 'alumno' }`
- Ejecutar `migrate_auth_roles_and_claims.js --dry-run` (adaptado solo con aprobación al proyecto staging) antes de cualquier asignación de claims.

### 2.2 Cloud Firestore & Reglas
- Base de datos Firestore en modo nativo en `us-central1` (o región equivalente) sobre `ginga-staging`.
- Desplegar `firestore.rules` y `firestore.indexes.json` únicamente contra `--project ginga-staging`.
- Cargar exclusivamente **datos sintéticos**:
  - Catálogo FIU (`node scripts/import_curriculum_to_firestore.js --apply` apuntando solo a staging tras validación previa con `--dry-run`).
  - 2 grupos sintéticos (`clases`: Adultos M/J 19:00, Infantil M/J 18:00), 1 sesión QR de prueba y 2 recursos Pizarra sintéticos (0 nombres, teléfonos o fechas reales de alumnos).

### 2.3 Cloud Functions & Secret Manager
- Proyecto staging con Firebase Functions Node.js 22 (`region: us-central1`).
- Secretos separados exclusivos de staging en Google Cloud Secret Manager (nunca reutilizar tokens productivos de Meta WhatsApp ni llaves OpenAI de producción):
  - `OPENAI_API_KEY`: clave restringida con tope mensual duro bajo (ej. `$2.00 USD`).
  - `META_WHATSAPP_TOKEN` / `META_PHONE_NUMBER_ID`: número sandbox / pruebas o desactivado con mock controlado en staging.
  - `ALLOW_STRESS_TEST_HTTP`: mantener sin definir (`false` efectivo) salvo prueba puntual autorizada.

### 2.4 Hosting / Preview Web Desacoplado
- Generar `firebase_options_staging.dart` dedicado con `flutterfire configure --project=ginga-staging` (sin sobrescribir `lib/firebase_options.dart` productivo ni mezclarlo en builds de `www.gingaperu.com`).
- Servir el frontend web de staging en **Firebase Hosting (`ginga-staging.web.app`)** o un proyecto **Vercel Staging** separado apuntando exclusivamente a `ginga-staging` (nunca apuntar previews con escritura hacia `capoeirafiu-ea8ljo`).

### 2.5 Validación desde Mac y Tablet (cuando exista staging)
1. **Desktop (Mac):** iniciar sesión con `profesor_staging`, verificar flujo completo de Pizarra -> Planificador V2 -> Edición -> Guardar borrador (`rev 1`), confirmar rechazo de lectura/escritura al cambiar a sesión `alumno_staging`.
2. **Tablet / Celular:** iniciar sesión con el mismo `profesor_staging`, recuperar el plan guardado, editarlo (`rev 2`), probar conflicto optimista desde Mac (`rev 1` -> diálogo *Cargar versión más reciente* / *Guardar como copia independiente*), iniciar ejecución en vivo en tablet, continuar en Mac y finalizar verificando historial inmutable y check-in QR con `alumno_staging`.

---

## 3. Procedimiento Seguro de Despliegue y Rollback (Referencia)

### Despliegue controlado (solo con autorización humana explícita)
1. Verificar CI verde y respaldo etiquetado en Git.
2. Seleccionar proyecto explícito: `firebase use ginga-staging` (o confirmar explícitamente antes de producción).
3. Validar reglas y funciones primero en Staging:
   - `firebase deploy --only firestore:rules --project ginga-staging`
   - `firebase deploy --only functions:sendManualWhatsAppMessage,functions:generarPlanClaseIA,functions:whatsappWebhook --project ginga-staging`
4. Ejecutar batería de smoke tests positivos y negativos autenticado en staging.

### Rollback inmediato
- **Reglas Firestore:** re-desplegar la versión inmediatamente anterior desde Firebase Console (*Firestore -> Rules -> Version history*) o desde el commit previo en Git (`git checkout <commit_previo> -- firestore.rules && firebase deploy --only firestore:rules --project <target>`).
- **Cloud Functions:** restaurar el commit etiquetado previo (`v1.0.0-feedback-v1` / tag previo) mediante el workflow manual `deploy-functions.yml` con confirmación explícita.
- **Custom Claims / Roles:** `users/{uid}` conserva los datos originales; si una normalización requiriera reversión en un entorno autorizado, los valores `'admin'` ya son aceptados por `UserRoleUtils`, `firestore.rules` y `functions/index.js`.
