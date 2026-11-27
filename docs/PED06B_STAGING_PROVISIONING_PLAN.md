# PED-06B — Plan de Aprovisionamiento de Staging y Validación en Tablet

> **Estado actual:** Preparación técnica e ingeniería local 100% completadas y verificadas sobre Firebase Emulator (`demo-ginga-test`). **Ningún proyecto Firebase ni facturación Blaze han sido creados/habilitados todavía**, a espera de aprobación explícita del propietario humano.

---

## 1. Identificación Previa de Cuenta, Proyecto, Facturación y Costos

| Parámetro | Definición Propuesta | Notas y Restricciones |
|---|---|---|
| **Cuenta propietaria Firebase / GCP** | **`capoeirafiuapp@gmail.com`** (o cuenta titular de `capoeirafiu-ea8ljo`) | Detectado en `gcloud auth list`: `capoeirafiuapp@gmail.com`, `ticketperu90@gmail.com` y `enriquepinedolc@gmail.com`; `firebase login:list` sin sesión activa. **No utilizar** la cuenta nueva de Google AI Pro (exclusiva de Antigravity IDE) como propietaria del proyecto cloud. |
| **Proyecto Firebase sugerido** | **`ginga-staging`** (alternativa: `ginga-capoeira-staging`) | Totalmente separado de producción (`capoeirafiu-ea8ljo`). `GingaEnvironment` en Flutter bloquea en runtime cualquier build `GINGA_ENV=staging` que apunte a `capoeirafiu-ea8ljo`. |
| **Región** | **`us-central1`** | Alineada con Cloud Functions y clientes `FirebaseFunctions.instanceFor(region: 'us-central1')`. |
| **Plan de facturación requerido** | **Blaze (pago por uso)** | Exigido por Firebase para desplegar Cloud Functions Gen 1 (`Node.js 22`) y Artifact Registry / Cloud Build. |
| **Costo mensual estimado** | **`$0.00 – $1.00 USD/mes`** (IA simulada por defecto) | Auth, Firestore, Hosting y Cloud Functions con tráfico de pruebas sintéticas quedan dentro o muy cerca de la capa gratuita mensual; único cargo marginal posible por almacenamiento temporal de imágenes en Artifact Registry. **Sin llamadas pagadas a OpenAI** mientras `PLANNER_V2_REAL_PROVIDER_ENABLED` y `PLANNER_V2_COPILOT_REAL_ENABLED` permanezcan apagados. |
| **Controles de gasto obligatorios** | Presupuesto + alerta **`$5.00 USD/mes`** (`50%`, `90%`, `100%`) | Más cuotas transaccionales persistidas en Firestore (`_quota_runtime`: `20/min` WhatsApp manual, `4/min` IA legacy, `4/min` Planner V2, `4/min` Copiloto + `QuotaStore` diario en Planificador V2). |

### Servicios Estrictamente Necesarios
1. **Firebase Authentication:** Proveedor **Email/Password** + dominios autorizados (`ginga-staging.web.app`).
2. **Cloud Firestore (Modo Nativo, `us-central1`):** Reglas [firestore.rules](file:///Users/jumper/ginga_app/firestore.rules) + índices [firestore.indexes.json](file:///Users/jumper/ginga_app/firestore.indexes.json).
3. **Cloud Functions Gen 1 (`Node.js 22`, `us-central1`):** Despliegue selectivo sin conectar WhatsApp de producción (`META_WHATSAPP_TOKEN` de producción prohibido; `ALLOW_STRESS_TEST_HTTP` sin definir; `PLANNER_V2_REAL_PROVIDER_ENABLED=false`):
   - `generarPlanClaseV2`
   - `copilotoPedagogicoV1`
   - `onNotificationCreated`
4. **Firebase Hosting:** Configurado en [firebase.json](file:///Users/jumper/ginga_app/firebase.json) (`build/web`, rewrites SPA, sin service worker persistente agresivo) -> URL accesible desde Mac y Tablet sin depender de tener la Mac encendida.
5. **Firebase App Check:** Activado para Web (`--dart-define=GINGA_APP_CHECK_WEB_SITE_KEY=<reCAPTCHA_v3_key>`) y móviles (`Play Integrity` / `App Attest`).
6. **Secret Manager (opcional para fase futura):** Solo necesario si en `PED-06C` se autorizan llamadas reales OpenAI con clave separada y tope mensual duro.

---

## 2. Orden Seguro de Despliegue y Migración (Solo tras Autorización)

1. **Autenticación CLI en la cuenta propietaria correcta:**
   - `gcloud config set account capoeirafiuapp@gmail.com`
   - `firebase login` (iniciar sesión con `capoeirafiuapp@gmail.com`)
2. **Crear proyecto `ginga-staging` y vincular facturación Blaze con alerta de `$5 USD`:**
   - `firebase projects:create ginga-staging --display-name "GINGA Staging"`
   - Habilitar Firestore, Auth, Functions, Hosting y App Check en consola y registrar Web App (`flutterfire` / valores `--dart-define` propios de `ginga-staging`, **sin sobrescribir** [lib/firebase_options.dart](file:///Users/jumper/ginga_app/lib/firebase_options.dart)).
3. **Desplegar reglas e índices primero:**
   - `firebase deploy --only firestore:rules,firestore:indexes --project ginga-staging`
4. **Sembrar datos 100% sintéticos y catálogo FIU:**
   - Preview: `node scripts/seed_staging_synthetic_data.js --dry-run --project=ginga-staging --allow-staging=ginga-staging`
   - Aplicar: `node scripts/seed_staging_synthetic_data.js --apply --project=ginga-staging --allow-staging=ginga-staging`
   - Crear las 3 cuentas sintéticas en Firebase Auth (`admin_staging@ginga.test`, `prof_staging@ginga.test`, `alumno_staging_1@ginga.test`) y asignar Custom Claims (`admin`, `curriculum_admin`, `profesor`, `instructor`, `rol`) con Firebase Admin CLI / Cloud Shell autorizado sobre `ginga-staging` (tras auditar con [migrate_auth_roles_and_claims.js](file:///Users/jumper/ginga_app/scripts/migrate_auth_roles_and_claims.js)).
5. **Desplegar Cloud Functions de staging (sin conectar WhatsApp productivo):**
   - `firebase deploy --only functions:generarPlanClaseV2,functions:copilotoPedagogicoV1,functions:onNotificationCreated --project ginga-staging`
6. **Compilar Flutter Web de staging y desplegar en Hosting:**
   - `flutter build web --release --pwa-strategy=none --dart-define=GINGA_ENV=staging --dart-define=GINGA_FIREBASE_PROJECT_ID=ginga-staging --dart-define=GINGA_FIREBASE_API_KEY=<WEB_KEY> --dart-define=GINGA_FIREBASE_APP_ID=<WEB_APP_ID> --dart-define=GINGA_FIREBASE_MESSAGING_SENDER_ID=<SENDER_ID> --dart-define=GINGA_APP_CHECK_WEB_SITE_KEY=<RECAPTCHA_V3_KEY>`
   - `firebase deploy --only hosting --project ginga-staging`

---

## 3. Procedimiento de Rollback Inmediato

- **Hosting web:** `firebase hosting:rollback --project ginga-staging` o re-despliegue de build previo.
- **Reglas Firestore:** Restaurar versión previa desde *Firebase Console -> Firestore -> Rules -> Version history* o desde Git (`git checkout <commit_previo> -- firestore.rules`).
- **Cloud Functions:** Re-desplegar versión etiquetada previa sin tocar `capoeirafiu-ea8ljo`.
- **Roles heredados (`administrador` -> `admin`):** Los clientes Flutter (`UserRoleUtils`), `firestore.rules` y `functions/index.js` aceptan tanto `'admin'` como `'administrador'`, garantizando compatibilidad durante la transición.

---

## 4. Pasos para Probar desde Tablet (cuando `ginga-staging` esté activo)

1. Abrir en el navegador de la **tablet** la URL `https://ginga-staging.web.app` (no depende de la Mac).
2. Iniciar sesión con `prof_staging@ginga.test` y verificar entrada directa al panel docente.
3. Abrir **Biblioteca Curricular**, consultar movimientos FIU y volver a **Planificador V2**.
4. Seleccionar el grupo **`Infantil M/J 18:00`**, elegir **`60 min`**, incluir **`Ginga`**, **`Armada`**, **`Aú`** y el recurso sintético de Pizarra **`Juego de Palma y Esquiva`**, y generar el plan (motor simulado en Cloud Functions).
5. Editar una observación o tiempo interno, abrir el **Copiloto**, pedir un ajuste y pulsar **Aplicar cambios**, luego **Guardar planificación**.
6. Abrir `https://ginga-staging.web.app` desde la **Mac** (o recargar otra pestaña en tablet) con la misma cuenta y comprobar que la clase aparece sincronizada con su revisión exacta.
7. Pulsar **Iniciar clase**, avanzar unos minutos, cerrar o cambiar de pestaña para simular interrupción, volver a abrir y confirmar la recuperación del temporizador.
8. Pulsar **Finalizar clase**, revisar el **Historial** y crear la siguiente planificación verificando la presencia del contexto de continuidad pedagógica.
9. Opcional de seguridad: iniciar sesión con `alumno_staging_1@ginga.test` en incógnito para confirmar acceso de alumno a su perfil/clases/biblioteca y bloqueo estricto de vistas/colecciones de profesor y leads.
