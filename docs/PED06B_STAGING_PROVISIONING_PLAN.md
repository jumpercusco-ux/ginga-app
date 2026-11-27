# PED-06B — Staging Provisionado (`ginga-capoeira-staging`), Controles de Gasto y Preparación Linux

> **Estado actual:** Entorno aislado **`ginga-capoeira-staging`** (`113866371476`) **provisionado, sembrado y verificado remotamente (`5/5` bloques PASS)**. Producción (`capoeirafiu-ea8ljo`) y rama `main` permanecen intactas.

---

## 1. Infraestructura Desplegada y Aislamiento

| Componente | Estado en Staging | Detalle Verificado |
|---|---|---|
| **Proyecto Firebase / GCP** | ✅ Activo | **`ginga-capoeira-staging`** (`113866371476`) bajo **`capoeirafiuapp@gmail.com`** (separado de `capoeirafiu-ea8ljo` y de Google AI Pro). |
| **Hosting Web HTTPS** | ✅ Desplegado | **`https://ginga-capoeira-staging.web.app`** (`App ID: 1:113866371476:web:239b2c3296e1e19af65f81`, bundle `build/web` compilado con `GINGA_ENV=staging` y `0` referencias a `capoeirafiu-ea8ljo`). |
| **Firebase Authentication** | ✅ Activo | Proveedor **Email/Password** habilitado, dominio autorizado `ginga-capoeira-staging.web.app`, 3 cuentas sintéticas con Custom Claims firmados (`prof_staging@ginga.test`, `admin_staging@ginga.test`, `alumno_staging_1@ginga.test`). |
| **Cloud Firestore (`us-central1`)** | ✅ Activo | Modo Nativo (`freeTier`), [firestore.rules](file:///Users/jumper/ginga_app/firestore.rules) e índices desplegados; `10` documentos sintéticos + `164` documentos curriculares FIU + clase demo infantil `plan_demo_infantil_staging_01`. |
| **Cloud Functions (`us-central1`, Node.js 22)** | ✅ Desplegado selectivamente | Exclusivamente **`generarPlanClaseV2`** (`512MB`, `180s`, `maxInstances: 2`), **`copilotoPedagogicoV1`** (`512MB`, `90s`, `maxInstances: 2`) y **`onNotificationCreated`** (`256MB`). Sin funciones WhatsApp ni estrés; OpenAI real desactivado (`is_simulated: true`). |
| **Firebase App Check** | 🟡 API habilitada | `firebaseappcheck.googleapis.com` habilitada; falta registrar `siteKey`/`siteSecret` de reCAPTCHA v3 en Firebase Console -> App Check y recompilar Hosting con `--dart-define=GINGA_APP_CHECK_WEB_SITE_KEY=...` para exigir App Check en Web. |
| **Facturación y Alerta Mensual** | ✅ Configurado y verificado | **`My Billing Account` (`017B04-148E04-2AD9B1`)** vinculada; presupuesto **`0fb16e7d-4ede-4a0e-a391-fdb9933cc8de`** por **`PEN 18`** (~USD 5 en moneda nativa de la cuenta), alertas al **`50%`, `90%` y `100%`**, filtrado **estrictamente a `projects/113866371476`**. El presupuesto de producción (`projects/543186587052`, `PEN 25`) permanece intacto. **Nota:** la alerta de presupuesto notifica y no constituye un límite duro de gasto; la contención operativa recae en `maxInstances: 2`, cuotas transaccionales `_quota_runtime` + `FirestoreTransactionQuotaStore` e IA simulada por defecto. |

---

## 2. Verificación Remota Real Ejecutada ([verify_staging_remote.js](file:///Users/jumper/ginga_app/scripts/verify_staging_remote.js))

1. **`R01` Hosting HTTPS:** `https://ginga-capoeira-staging.web.app/` devuelve `200 OK` con arranque Flutter Web y `0` menciones a `capoeirafiu-ea8ljo`.
2. **`R02` Auth + Custom Claims:** Inicio de sesión Email/Password real para `prof_staging@ginga.test` (`profesor: true`, `instructor: true`, `admin: false`) y `alumno_staging_1@ginga.test` (`rol: 'alumno'`).
3. **`R03` Reglas Firestore en vivo:** `prof_staging` lee `curriculum_movements/ginga`, `clases/clase_infantil_mj` e `instructor_ideas/idea_staging_01`; `alumno_staging_1` recibe `403` en `users/prof_staging`, `whatsapp_leads`, `instructor_planes_clase` y `_quota_runtime`.
4. **`R04` Callables `generarPlanClaseV2` y `copilotoPedagogicoV1`:** Rechazan al alumno (`PERMISSION_DENIED`) y responden al profesor en modo simulado (`is_simulated: true`, `60 min`, Ginga/Armada/Aú + juegos + musicalidad + Pizarra).
5. **`R05` Persistencia remota E2E:** Guarda clase demo `plan_demo_infantil_staging_01`, recupera, ejecuta sesión en vivo (`instructor_sesiones_activas`) y recupera tiempo acumulado, crea historial inmutable (`instructor_sesiones_impartidas`, `PATCH` bloqueado `403`) y limpia la sesión temporal activa.

---

## 3. Instalación Reproducible en Linux (Preparación para Futuro `PED-06R` / Remote Agents)

> **Nota:** Esta sección documenta requisitos reproducibles sin dependencia de macOS para facilitar futuros Remote Agents en Linux (`ubuntu-22.04`/`24.04`), sin implementar `PED-06R` ni almacenar credenciales en Git.

- **Herramientas base requeridas:**
  - **Node.js 22 LTS** + `npm ci` en `functions/`.
  - **OpenJDK 21** (Temurin) para ejecutar Firebase Firestore Emulator (`JAVA_HOME` apuntando a JDK 21).
  - **Flutter `3.41.4`** (`stable`, con soporte Web habilitado).
  - **Firebase CLI `15.x`** (`npm install -g firebase-tools@15.10.1`) y **Google Cloud CLI** (solo cuando el entorno tenga autorización explícita).
- **Portabilidad de scripts y secretos:**
  - Los scripts [seed_staging_synthetic_data.js](file:///Users/jumper/ginga_app/scripts/seed_staging_synthetic_data.js) y [verify_staging_remote.js](file:///Users/jumper/ginga_app/scripts/verify_staging_remote.js) son 100% Node.js multiplataforma (sin Keychain ni dependencias exclusivas de macOS) y consumen credenciales/configuración exclusivamente vía variables de entorno en memoria (`GCLOUD_ACCESS_TOKEN`, `STAGING_PROJECT_ID`, `STAGING_WEB_API_KEY`, `STAGING_PROF_EMAIL`, `STAGING_PROF_PASSWORD`, `STAGING_ALU_EMAIL`, `STAGING_ALU_PASSWORD`) o `--dart-define` al compilar Flutter Web.
  - Nunca copiar archivos `.env`, llaves JSON de cuenta de servicio ni contraseñas en el repositorio ni en logs de CI.

---

## 4. Pasos para Validar desde Mac y Tablet + Rollback

### Validación desde Tablet y Mac
1. Abrir **`https://ginga-capoeira-staging.web.app`** en Chrome/Safari (tablet o Mac).
2. Iniciar sesión con `prof_staging@ginga.test` (utilizando la contraseña temporal entregada por el propietario/chat; cambiarla tras la prueba desde Firebase Auth si se comparte).
3. Abrir **Planificador V2** -> abrir la clase demo **`Clase Demo Infantil — Ginga, Armada y Aú (Staging)`** (`plan_demo_infantil_staging_01`) o generar una nueva de `60 min` sobre **`Infantil M/J 18:00`** (modo simulado).
4. Editar un ejercicio, consultar al **Copiloto**, pulsar **Aplicar cambios** y **Guardar planificación**.
5. Abrir la misma URL desde el segundo dispositivo (Mac <-> Tablet), iniciar **Clase en vivo**, avanzar el reloj, recargar/cerrar pestaña para validar recuperación del temporizador, finalizar la clase y verificar el **Historial** y la continuidad pedagógica en una nueva planificación.

### Procedimiento de Rollback en Staging
- **Hosting:** `firebase hosting:rollback --project ginga-capoeira-staging`
- **Firestore Rules:** restaurar revisión previa desde Firebase Console (*Firestore -> Rules -> Version history*) o `git checkout <commit_previo> -- firestore.rules && firebase deploy --only firestore:rules --project ginga-capoeira-staging`.
- **Cloud Functions:** `firebase deploy --only functions:generarPlanClaseV2,functions:copilotoPedagogicoV1,functions:onNotificationCreated --project ginga-capoeira-staging` desde el commit previo (o eliminar funciones de staging temporalmente con `firebase functions:delete <fn> --region us-central1 --project ginga-capoeira-staging --force`).
