# Registro de Decisiones de Arquitectura y Negocio (DECISIONS)

Este documento registra formalmente las decisiones técnicas y de negocio del proyecto GINGA.

Cada decisión se clasifica estrictamente en uno de tres estados:
- **`[APROBADA]`:** Decisión adoptada, validada y vigente en la arquitectura.
- **`[PROPUESTA]`:** Recomendación técnica documentada pendiente de aprobación o implementación.
- **`[PENDIENTE]`:** Decisión de negocio que requiere definición explícita del usuario o stakeholders comerciales.

---

## Decisiones Técnicas

### 1. Arquitectura Single-Agent con Function Calling Nativo
- **Estado:** `[APROBADA]`
- **Contexto:** Evaluación de frameworks agénticos multiagente (Google ADK, LangChain, CrewAI) frente a la implementación nativa actual en Node.js 20.
- **Decisión:** Mantener una arquitectura **single-agent con OpenAI Function Calling nativo** sobre Google Cloud Functions.
- **Justificación:** El flujo conversacional de GINGA es enfocado (prospectos de WhatsApp que consultan horarios, precios y agendan clases de prueba). Un framework multiagente introduce sobrecostos de latencia (arranques en frío en Cloud Functions) y complejidad innecesaria. Function calling con hasta 4 rondas secuenciales resuelve el 100% de los casos requeridos.

### 2. Separación Estricta de Entornos: Producción, Staging y Demo
- **Estado:** `[APROBADA]`
- **Contexto:** Riesgo de contaminar la lógica de producción con maquetas visuales de demos o cambios no probados.
- **Decisión:** Mantener 3 líneas claramente diferenciadas:
  1. `main` (`3058ada`): Reflejo de producción activa (`whatsappWebhook v67`).
  2. `fix/real-whatsapp-logic`: Desarrollo real probado con el harness local en memoria (`real_agent_harness/`).
  3. `demo/`: Sandbox aislado en memoria para grabaciones y video en vivo.
- **Justificación:** Garantiza cero impacto en clientes reales de WhatsApp mientras se audita y mejora el código.

### 3. Controles Críticos en Backend, No en Prompts ni en la UI
- **Estado:** `[APROBADA]`
- **Contexto:** Riesgo de alucinaciones en precios, fechas inválidas o duplicados cuando se confía ciegamente en el LLM.
- **Decisión:** Las reglas críticas de negocio (validación de precios reales contra `/config/negocio`, verificación de días de clase `M, J`, chequeo transaccional de duplicados y filtros fail-safe) residen obligatoriamente en código determinista de Node.js en el backend, nunca delegadas exclusivamente a instrucciones de lenguaje natural.
- **Justificación:** Los prompts orientan al modelo pero no ofrecen garantías deterministas de seguridad ni consistencia transaccional.

### 4. Estrategia de Reprogramación: Mismo Documento con Trazabilidad
- **Estado:** `[APROBADA]`
- **Contexto:** Decidir si al cambiar una fecha se crea una nueva reserva cancelando la anterior o se modifica la existente.
- **Decisión:** Modificar atómicamente el documento existente en `/reservas` actualizando `fecha_clase` y guardando la traza en el array `reprogramaciones`.
- **Justificación:** Mantiene un único identificador de reserva (`reservaId`) vinculado al lead en la app del instructor, evitando registros huérfanos o confusión visual en la lista de asistencia.

### 5. Preparación Multisede Dinámica y Libre de Alucinaciones
- **Estado:** `[APROBADA]`
- **Contexto:** Apertura de sedes futuras en Cusco (Magisterio, Larapa, etc.) o en otras ciudades.
- **Decisión:** Resolver dinámicamente `sede_id`, `sede` y `ubicacion` desde los documentos verificados de Firestore (`/clases` y `/reservas`). Se prohíbe taxativamente hardcodear direcciones fijas (como la antigua dirección fija de Cusco) si un documento de clase carece de ubicación comprobada.
- **Restricción:** No inventar sedes, calles ni locales no verificados en base de datos.

### 6. Concurrencia e Idempotencia Transaccional vía Lock Optimista
- **Estado:** `[APROBADA]`
- **Contexto:** Riesgo de reservas duplicadas cuando un lead envía múltiples mensajes en ráfaga o Meta reintenta el webhook en milisegundos.
- **Decisión:** Mover la verificación de duplicados DENTRO de `runTransaction` mediante el mapa `reservas_activas: { [slug]: ... }` en `whatsapp_leads/{leadId}`. Si dos transacciones compiten, la concurrencia optimista de Firestore aborta la segunda transacción con `DUPLICATE_ACTIVE_RESERVATION`.
- **Justificación:** Garantiza consistencia estricta ACID a nivel de base de datos, independiente de la capa de debounce de red.

### 7. Fusión No Destructiva de Perfiles Familiares en `guardar_perfil_lead`
- **Estado:** `[APROBADA]`
- **Contexto:** Cuando un padre menciona a un primer hijo (ej. Mateo de 8) y luego a un segundo hijo (ej. Sofía de 6), la versión base sobrescribía el arreglo eliminando al primero.
- **Decisión:** Implementar fusión inteligente por slug (`slugifyPersona`), combinando el arreglo previo con los nuevos perfiles.
- **Justificación:** Previene pérdida de contexto familiar durante la conversación.

### 8. Agent Control Center
- **Estado:** `[PROPUESTA]`
- **Contexto:** Necesidad de los instructores y administradores de monitorear la salud de las herramientas del agente.
- **Decisión:** Diseñar una pantalla administrativa con interruptores (toggles) dinámicos para habilitar/deshabilitar herramientas para el LLM, con la restricción estricta de que el panel **no puede desactivar validaciones críticas de backend**.

### 9. Integración con Plataforma DANEV mediante API/Eventos
- **Estado:** `[PROPUESTA]`
- **Contexto:** Futura sincronización de leads calificados y reservas con el CRM y analítica central de DANEV.
- **Decisión:** Diseñar contratos de eventos auditables normalizados en JSON Schema (`event_id`, `timestamp`, `tool_name`, `lead_hash`, `diff`), listos para emitirse vía HTTP webhook cuando se apruebe la integración.
- **Restricción:** No implementar llamadas ni infraestructura externa antes de la aprobación formal.

---

## Decisiones Comerciales y de Negocio

### 10. Diferenciación Formal entre Reserva, Asistencia y Matrícula
- **Estado:** `[APROBADA]`
- **Decisión:** Establecer claramente los tres conceptos dentro del sistema:
  - **Reserva (`/reservas`):** Intención comercial previa de asistir a una clase de prueba gratuita. Estado: `confirmado`.
  - **Asistencia (`/asistencias`):** Verificación física presencial en el tatami (check-in QR o manual del profesor). Actualiza la reserva a `asistio`.
  - **Matrícula (`/users` rol alumno / `/pagos`):** Alumno regular con mensualidad o plan multimes pagado. Deja de ser prospecto de WhatsApp y pasa a gestión de alumno en la app móvil.

### 11. Política sobre Segunda Clase de Prueba Gratuita
- **Estado:** `[PENDIENTE]` (Medida de Seguridad Provisional en Backend)
- **Contexto:** Un alumno que ya asistió a su clase de prueba gratuita vuelve a escribir solicitando otra clase sin costo.
- **Medida Provisional Actual:** El backend intercepta cualquier intento de nueva reserva o reprogramación cuando existe historial `asistio` y deriva obligatoriamente a `marcar_seguimiento_humano`. Esto **NO constituye una política comercial aprobada**, sino una salvaguarda de contención para evitar que el bot otorgue beneficios o comprometa al negocio sin autorización del instructor.
- **Propuesta Técnica:** Permitir **únicamente 1 clase de prueba gratuita por persona**. Si el lead solicita otra, derivar a profesor para evaluar caso o venta de membresía.
- **Acción Requerida:** Aprobación o ajuste formal por parte de los directores comerciales de GINGA.

### 12. Política de Reprogramación tras Inasistencia (No-Show)
- **Estado:** `[PENDIENTE]` (Medida de Seguridad Provisional en Backend)
- **Contexto:** Un alumno que reservó su clase no asistió (el profesor marcó `no_asistio` o la fecha transcurrió sin check-in).
- **Medida Provisional Actual:** El backend bloquea el reagendamiento automático desatendido y deriva a `marcar_seguimiento_humano`. Es una salvaguarda provisional para evitar reprogramaciones infinitas sin justificación.
- **Propuesta Técnica:** Permitir **un (1) reagendamiento automático** de cortesía si el cliente se comunica para justificar la inasistencia. Si incurre en una segunda falta, derivar al profesor.
- **Acción Requerida:** Aprobación o ajuste formal por parte de los directores comerciales de GINGA.

---

### 13. Resolución de Identidad Familiar y Reservas Múltiples (P0.2B)
- **Estado:** `[APROBADA]`
- **Contexto:** Familias con múltiples hijos contactan desde un único número de WhatsApp familiar (`lead_id`). En el esquema legacy (`3058ada`), los campos escalares (`reserva_id`, `fecha_clase_reservada`) sobreescribían los datos del primer hijo al agendar al segundo. Además, referencias ambiguas como "mi hijo" o "el pequeño" causaban que el sistema adivinara arbitrariamente o atribuyera reservas de un hermano al otro.
- **Decisión:**
  1. **Trazabilidad no destructiva:** Mantener el mapa estructurado `reservas_activas: { [slug]: { reserva_id, clase_id, nombre_persona, fecha_clase, status, hora } }` en `whatsapp_leads`, preservando compatibilidad retroactiva con campos escalares (`reserva_id`) para clientes legacy.
  2. **Reconciliación automática:** Al agendar o reprogramar, las reservas históricas o de hermanos en `/reservas` se auto-incorporan a `reservas_activas` sin pérdida de datos.
  3. **Aislamiento por alumno:** Las reservas de hermanos son completamente independientes. La cancelación, inasistencia o asistencia de un hermano no afecta ni bloquea las clases de sus hermanos.
  4. **Prohibición de adivinanza:** Ante referencias ambiguas ("mi hijo", "el nene") o nombres no especificados en familias con múltiples perfiles, el bot solicita aclaración explícita indicando los nombres registrados, en lugar de asumir el primer perfil (`personas[0]`) o usar el nombre de contacto de WhatsApp del padre/madre.
  5. **Autorización y desambiguación:** `reprogramar_reserva` valida que el `reserva_id` pertenezca al número de WhatsApp autenticado. Si dos alumnos comparten el mismo nombre en la misma familia, el sistema exige desambiguación mediante `reserva_id` o fecha/horario.

---

### 14. Runtime Guard Determinista y Telemetría Segura Zero PII (P1A)
- **Estado:** `[APROBADA]`
- **Contexto:** En el baseline histórico (`3058ada`, Caso 8), el modelo generaba afirmaciones verbales de éxito ("¡Listo! He reprogramado la clase de Valentina...") sin haber ejecutado la herramienta correspondiente en base de datos.
- **Decisión:**
  1. **Runtime Guard Determinista en `preguntarIA`:** Inspección automática post-generación de todas las respuestas del LLM antes de su envío a WhatsApp. Se analizan afirmaciones de mutación (`booking`, `reschedule`, `cancellation`) y se valida su correspondencia estructurada contra `TurnContext`.
  2. **Verificación Estricta de Respaldo Transaccional y Correspondencia de Entidades:**
     - La respuesta solo se permite (`action: 'allow'`) si:
       - La herramienta correspondiente ejecutó con éxito en este turno (`mutation_committed: true`, `status: 'success'`).
       - Existe correspondencia unívoca de **persona**: el éxito para un hijo no justifica la confirmación para otro, y si una persona fue rechazada (`CLASS_FULL`, etc.), cualquier afirmación individual o colectiva ("ambos quedaron listos") es interceptada.
       - Existe correspondencia de **fecha**: el agendamiento o reprogramación en martes no autoriza afirmar jueves, y viceversa.
       - Existe correspondencia de **operación**: una reserva de prueba no justifica una reprogramación ni una cancelación.
       - En caso de recordatorios de agendamiento sin tool nueva, la cita debe figurar como confirmada y vigente en el bloque estructurado del `systemPrompt`, sin afirmar acciones nuevas inmediatas.
     - *Nota técnica sobre persistencia:* `mutation_committed: true` certifica el commit atómico de la transacción en Firestore del handler; no declara una lectura posterior independiente desvinculada.
  3. **Intercepción y Fail-Safe Automático (`action: 'intercept'`):** Si se detecta una confirmación verbal no respaldada o que contradice un rechazo de herramienta:
     - La respuesta al usuario se sustituye por un mensaje seguro y verídico que no emite segundas promesas falsas.
     - Si la actualización en Firestore a `status: 'requiere_atencion'` falla, se emite un fallback técnico transparente sin declarar la derivación como completada.
     - Si el lead ya contaba con `status: 'requiere_atencion'`, se detecta `alreadyEscalated` para evitar saturación de alertas a instructores.
     - El guard **no altera `ai_habilitada`**, evitando congelamientos permanentes involuntarios del lead sin decisión humana explícita.
  4. **Privacidad y Telemetría Zero PII (ACC / DANEV):**
     - Hashing irreversible de identificadores mediante HMAC-SHA256 (`TELEMETRY_SALT`) para mitigar vulnerabilidades de tablas rainbow sobre rangos telefónicos conocidos (+51).
     - Ofuscación estricta de nombres de menores a pseudónimos opacos `persona_ref` (`p_` + HMAC hex), garantizando cero PII en eventos de telemetría.
     - Buffer en memoria volátil (`MAX_TELEMETRY_BUFFER_SIZE = 100`) sin persistencia productiva prematura en esta fase.
  5. **Límite Semántico Intrínseco Documentado:** El clasificador se apoya en reglas heurísticas y expresiones regulares robustas. Modismos coloquiales atípicos sin verbos estándar de acción (ej. "ya te apunté en la libreta") representan un límite semántico intrínseco, mitigado por las instrucciones de tono y claridad del prompt de sistema.

---

### 15. Salvaguardas de Integración, Firestore Real y Release Candidate
- **Estado:** `[APROBADA]`
- **Contexto:** Antes de considerar un despliegue de las correcciones de GINGA, era imperativo auditar la compatibilidad con el motor real de Google Cloud Firestore, evaluar la seguridad de secretos y revisar los pipelines de CI/CD.
- **Decisión:**
  1. **Compatibilidad Estricta con el Motor de Firestore:**
     - En Firestore real, las sentinelas `FieldValue.serverTimestamp()` están estrictamente prohibidas dentro de arrays. En el array de auditoría `reprogramaciones`, se debe utilizar `Timestamp.now()`.
  2. **Política de Secretos y Salt:**
     - Prohibición de strings o llaves fijas en el código fuente para funciones criptográficas. Si `TELEMETRY_SALT` no se inyecta por Secret Manager, el sistema genera automáticamente un salt efímero de 32 bytes (`crypto.randomBytes(32).toString('hex')`) por instancia.
  3. **Control de Despliegue CI/CD:**
     - El flujo `.github/workflows/deploy.yml` despliega automáticamente al fusionar con `main`. Se establece como regla estricta no fusionar ni pushear a `main` sin control manual de release.
  4. **Criterio de Aprobación de Release Candidate:**
     - Ninguna fase de integración se considera aprobada si únicamente ha sido probada con mocks en memoria. El Release Candidate requiere pruebas en Firestore Emulator oficial con Java 21 y evaluación conversacional real previa al despliegue.

---

### 16. Aislamiento Estricto de Red, Firewall Global y Credenciales Seguras de QA
- **Estado:** `[APROBADA]`
- **Contexto:** La ejecución de pruebas contra el LLM real (`gpt-4o-mini`) con el backend de producción emulado exige garantías absolutas de no-regresión hacia infraestructura productiva (Meta WhatsApp Cloud API y Google Cloud Firestore).
- **Decisión:**
  1. **Aislamiento de Transporte de Firestore:**
     - Se establece formalmente que `GCLOUD_PROJECT=demo-...` no desvía el socket de red por sí solo. Es obligatorio exigir `FIRESTORE_EMULATOR_HOST` (e.g. `127.0.0.1:8080`) antes de inicializar el SDK de Firebase Admin, junto con un ping HTTP de conectividad activa antes de iniciar cualquier prueba.
  2. **Firewall de Red Global en `global.fetch`:**
     - Se prohíbe confiar en el monkey-patching de objetos exportados en módulos con referencias léxicas internas. La intercepción de solicitudes a Meta WhatsApp se implementa a nivel del transporte global de Node.js (`global.fetch`), bloqueando de forma absoluta cualquier salida hacia `graph.facebook.com` o endpoints remotos no autorizados.
  3. **Política de Credenciales Sin Eco ni Historial:**
     - Prohibición estricta de pasar claves API como argumentos literales de shell (`OPENAI_API_KEY="sk-..."`). Se estandariza el uso del comando interactivo sin eco `read -s` de zsh/bash, impidiendo que la clave se guarde en `~/.zsh_history` o archivos de disco.
  4. **Naturaleza del Techo Presupuestario Local:**
     - El cálculo de tokens y costo local ($0.25 USD) es un circuit-breaker de cliente y no un límite contractual garantizado por el proveedor. Para límites financieros duros se exige configurar presupuestos de proyecto en OpenAI Platform.

---

### 17. Despliegue Selectivo Estricto y Prevención de Despliegue Masivo por CI/CD
- **Estado:** `[APROBADA]`
- **Contexto:** La auditoría de `.github/workflows/deploy.yml` reveló que cualquier `git push` a `main` activa de forma automática el despliegue de **todas las Cloud Functions** (`firebase deploy --only functions --project capoeirafiu-ea8ljo`) y la aplicación web en Vercel. De las 10 Cloud Functions existentes, solo `whatsappWebhook` fue objeto de modernización, auditoría y pruebas para el agente de WhatsApp.
- **Decisión:**
  1. **Prohibición de Despliegue Masivo:** Se prohíbe taxativamente ejecutar despliegues generales de functions (`--only functions`). El único target permitido para el lanzamiento de GINGA Real es estrictamente:
     `firebase deploy --only functions:whatsappWebhook --project capoeirafiu-ea8ljo`
  2. **Control de Disparo en GitHub Actions:** Antes de sincronizar o fusionar ramas en el repositorio remoto, se debe neutralizar el trigger automático de CI/CD para evitar el despliegue prematuro de las otras 9 Cloud Functions no probadas en este ciclo.
  3. **Estrategia Realista de Rollback en Cloud Functions Gen 1:**
     - La función `whatsappWebhook` está construida sobre Firebase Functions Gen 1 (`firebase-functions` v4.4.1 con `functions.runWith(...).https.onRequest`), que opera sobre Cloud Functions 1st gen. En Gen 1 **no existe división de tráfico ni conmutación instantánea entre revisiones**. Cada despliegue sobreescribe por completo la versión activa.
     - En consecuencia, el rollback no puede realizarse mediante un simple cambio de tráfico en consola y tiene un RTO realista de **2 a 5 minutos** (tiempo de empaquetado, build y propagación de Cloud Functions).
     - Procedimiento de rollback respaldado: Se realiza un re-despliegue quirúrgico de la versión previa utilizando un `git worktree` aislado basado en el tag `pre-live-original-2026-10-27` (commit `3058ada`), garantizando que el entorno local activo no se contamine.
  4. **Smoke Test Aislado sin Tráfico a Clientes:**
     - La verificación post-despliegue se ejecutará exclusivamente desde un número de teléfono de prueba interno autorizado en Meta Business Suite. Queda prohibido interactuar con leads o clientes reales.
     - Los escenarios de prueba deben ceñirse estrictamente a los días (Martes y Jueves) y a la sede y horarios que devuelva dinámicamente `consultar_horarios_disponibles` desde `/clases` y `config/negocio`, sin asumir estáticamente entre Magisterio (Av. de la Cultura) o Calle Hospital hasta verificar la base de datos de producción.
     - Una intercepción legítima del Runtime Guard ante una afirmación no respaldada en Firestore no se clasifica como fallo del sistema, sino como evidencia de funcionamiento correcto de la protección. Criterio de fallo crítico es la fuga de confirmaciones no autorizadas o excepciones 500 no controladas.

---

### 18. Reconciliación Comercial de Sedes, Verificación de Secrets y Límites de Certeza de Rollback
- **Estado:** `[APROBADA]`
- **Contexto:** La auditoría remota de solo lectura autorizada (Prompt 49) sobre el proyecto `capoeirafiu-ea8ljo` resolvió las incógnitas sobre la configuración productiva de Firestore y el entorno de Google Cloud.
- **Decisión:**
  1. **Reconciliación de Sedes y Horarios:**
     - Se establece formalmente que la sede y horarios comerciales reales de Ginga en producción corresponden a:
       * **Sede:** Av. de la Cultura E-4, Urb. Magisterio (Edificio Divergym, 3er piso, al costado de Caja Arequipa).
       * **Clase Kids:** Martes y Jueves 18:00 – 19:00 (edades 5 a 12 años, 10 cupos).
       * **Clase Adultos:** Martes y Jueves 19:00 – 20:00 (edades 13 a 99 años, 3 cupos).
       * **Tarifas:** Mensualidad S/140, Promo 2x S/260, Multimes (1m S/140, 2m S/260, 3m S/380, 6m S/700).
     - La referencia a "Calle Hospital 840" y horarios 17:00–18:00 se clasifica estrictamente como **fixture sintético de pruebas del emulador local**, no como configuración de negocio.
  2. **Política sobre `config/whatsapp_agent`:**
     - Se confirma la existencia del documento en producción (actualizado 2026-09-07T01:07:59Z). Para preservar la confidencialidad e integridad del entorno, su contenido no fue descargado ni inspeccionado. No se asume equivalencia textual entre dicho prompt y el utilizado en los entornos de prueba.
  3. **Configuración de Secrets y Telemetría:**
     - Se verificó la existencia y habilitación de los 5 secretos esenciales (`META_VERIFY_TOKEN` v2, `META_APP_SECRET` v1, `META_WHATSAPP_TOKEN` v2, `META_PHONE_NUMBER_ID` v1, `OPENAI_API_KEY` v1).
     - Se documenta que `TELEMETRY_SALT` está ausente en Secret Manager y variables de entorno de producción. La función opera de forma no bloqueante recurriendo a un salt efímero generado por cold start (`crypto.randomBytes(32)`), con la consecuencia técnica conocida de que los hashes de telemetría no son correlacionables entre diferentes instancias de ejecución.
  4. **Límites de Certeza de Rollback:**
     - La versión activa en GCP es `v67` (actualizada el 23 de octubre de 2026).
     - El worktree de contingencia `/private/tmp/ginga_rollback_baseline` está configurado sobre el commit `3058ada` (tag `pre-live-original-2026-10-27`). No se asume equivalencia binaria estricta entre este commit y el artefacto ZIP desplegado en `v67`, pero constituye el respaldo de código fuente más fiel disponible para un eventual re-despliegue de recuperación.

---

### 19. Biblioteca Curricular Unificada FIU y Separación Estricta de Rol vs. Graduación (`PED-01..PED-03B`)
- **Estado:** `[APROBADA]`
- **Contexto:** El propietario (también practicante de capoeira) necesita consultar su propia graduación y las anteriores usando la misma base técnica que sus alumnos, sin duplicar librerías y preparando el terreno para `PED-04`.
- **Decisión:**
  1. **Una sola Biblioteca evolutiva:** Evolucionar `BibliotecaScreen` incorporando el Centro Curricular Oficial FIU (`CurriculoBibliotecaScreen` + `MovimientoDetalleScreen` / `MovimientoDetallePanel`), conservando los 6 módulos clásicos (`Música`, `Tutoriales`, `Cultura`, `Glosario`, `Sistema de Graduaciones`, `Nuestros Mestres`), los `21` tutoriales vivos y los `5` videos reales sin destruir permisos heredados.
  2. **Separación de Tracks y Bloques Compartidos:** Mantener separados `adulto` (`adulto_corda_01..17`) e `infantil` (`infantil_corda_01..12`), compartiendo el catálogo canónico `curriculum_movements` y preservando bloques oficiales como `adulto_bloque_05_06` (evaluación diferenciada para Corda 5 y Corda 6).
  3. **Desacoplamiento estricto Rol vs. Graduación Personal:** `BibliotecaUserContext` resuelve `isTeacher` y `canBypassTutorialLock` únicamente desde `rol` (`profesor`, `instructor`, `admin`), mientras `cordaFIU` / `adultCordaIndex` regulan únicamente la visualización del repertorio personal.
  4. **Control de elegibilidad IA y deduplicación visual no destructiva:** Excluir entradas pendientes (`desequilibrante`, `espelho_cruz`, `au_chibata_pulado`) y equivalencias no confirmadas del futuro planificador IA; deduplicar únicamente en vista (`MovimientoDetallePanel.visibleAliasesForDisplay`) los alias idénticos al nombre canónico sin alterar `data/curriculum/fiu_adulto_v1.json`.

---

### 20. Seguridad de Colecciones Curriculares por Custom Claims e Importador Idempotente (`PED-03A/03C`)
- **Estado:** `[APROBADA]`
- **Contexto:** Al auditar `firestore.rules`, se observó que `match /users/{userId}` permite escritura autenticada, lo cual convertiría en vector de auto-elevación cualquier regla que dependiera de `users/{uid}.data.rol == 'admin'`.
- **Decisión:**
  1. **Autorización basada exclusivamente en Custom Claims:** `isCurriculumAdmin()` en `firestore.rules` exige `request.auth.token.admin == true || request.auth.token.curriculum_admin == true`; además, se prohíbe `delete` en todas las colecciones `curriculum_*` incluso para administradores.
  2. **Protección anti-escritura en producción e idempotencia:** `scripts/import_curriculum_to_firestore.js` opera en modo `dryRun` por defecto, exige `FIRESTORE_EMULATOR_HOST` o confirmación explícita (`--allow-live-write --confirm-production`), aplica hashes `content_hash` para idempotencia al 100% y sincroniza referencias hacia `/tutoriales` de forma estrictamente aditiva preservando `video_url` y campos legacy.
  3. **Deprecación segura del seed mockup:** `TutorialesService.legacyMockSeedEnabled = false` deshabilita escrituras mockup desde el cliente manteniendo compatibilidad de compilación con `InstructorClaseScreen`.

---

### 21. Conservación de `GingaTheme` Adaptable y Contrato Opt-In `CurriculumSelectionContract` (`PED-03B-UX/FINAL`)
- **Estado:** `[APROBADA]`
- **Contexto:** Tras detectar mezcla de modo claro/oscuro en el preview aislado cuando `ThemeManager.instance` no estaba sincronizado con `MaterialApp`, se evaluó adoptar la paleta fija negra de `InstructorClaseScreen` o conservar `GingaTheme`.
- **Decisión:**
  1. **Mantener `GingaTheme` adaptable claro/oscuro:** Se conserva intacto `lib/core/theme/ginga_theme.dart`; el preview (`main_biblioteca_preview.dart`) sincroniza `ThemeManager.instance` igual que `main.dart`, y las pantallas de Biblioteca blindan colores y dimensiones de botones leyendo `Theme.of(context).brightness` con acentos legibles en oscuro (`#66BB6A` sobre `surfaceDark`).
  2. **Contrato de selección sin IA para `PED-04`:** Se define el contrato opt-in `CurriculumSelectionContract` + `CurriculumMovementSelectionItem` en `lib/core/models/curriculum_models.dart`, conectando tarjetas y fichas de movimiento para selección manual en futuras pantallas del planificador mientras se mantiene bloqueada la selección automática de movimientos en revisión técnica.

---

### 22. Planificador Pedagógico Unificado V2, Honestidad de Borradores Locales y No-Fallback Infantil (`PED-04A/04B1`)
- **Estado:** `[APROBADA]`
- **Contexto:** Evolucionar `InstructorPizarraScreen` sin crear un segundo planificador paralelo, permitiendo preparación rápida y avanzada sobre los mismos contratos tipados antes de conectar llamadas IA de pago o persistencia de sesiones en `PED-04B2`.
- **Decisión:**
  1. **Un único planificador integrado con Pizarra y Biblioteca:** `InstructorPizarraScreen` conserva sus modales productivos (`_ModalIdea`, `_GeneradorClaseModal`, `_ClaseEnVivoScreen`) e incorpora `PlannerHubBody` (`Mis Planes`, `Pizarra de Recursos`, `Historial`, `Creación rápida`, `Creación avanzada`) conectado al `CurriculumSelectionContract` y con lectura retrocompatible de planes V1 (`ClassPlanModel.fromMap`).
  2. **Seguridad curricular y privacidad por defecto:** Se bloquea explícitamente cualquier fallback automático al currículo Adulto FIU para grupos `infantil` o `mixto` (`PlannerCurriculumScope.suggestedForAudience`), `toAiSafeRequestMap()` excluye PII y las referencias técnicas (`UID`, `PED-04C`, `Zero-PII`, `ID estable`, `V1 Compatible`) se mantienen internas sin exponerse en la UI del profesor.
  3. **Honestidad de origen en borradores y fixtures:** Los borradores creados localmente sin backend IA (`ClassPlanModel.fromLocalDraftRequest`) nunca se etiquetan como `Propuesta IA` y muestran el aviso explícito `Borrador local sin generación IA`; las sesiones del Historial en preview muestran aviso de fixtures locales de demostración (`isSimulatedFixture`) y seleccionar recursos para planificar no altera `hasBeenTaught` ni `timesUsed`.
  4. **Preview web sin Service Worker en puerto dedicado:** Para evitar caché persistente durante validación visual, `lib/main_planificador_preview.dart` se compila con `--pwa-strategy=none` (eliminando `flutter_service_worker.js`) y se sirve en puerto `8097`.




### 23. Editor Pedagógico de Clases V2 Desacoplado, Inmutable y No Bloqueante (`PED-04B2`)
- **Estado:** `[APROBADA]`
- **Contexto:** Convertir los borradores del planificador V2 y los planes V1 heredados en clases completamente editables (bloques, ejercicios, tiempos y recursos) sin escribir en Firestore de producción ni usar llamadas IA de pago.
- **Decisión:**
  1. **Operaciones puras e inmutables (`ClassPlanEditorOperations`):** Toda edición, duplicación o reordenamiento de bloques, ejercicios o clases completas produce nuevas instancias preservando `blockId`, `exerciseId`, `curriculumMovementIds`, `linkedResourceIds` y `contentOrigin`, evitando mutaciones compartidas o alteración del plan original al reutilizar.
  2. **Control permanente de tiempos no bloqueante (`ClassPlanTimingSummary`):** La barra superior de tiempos muestra permanentemente objetivo, total planificado, restante/excedente y avisos de desajuste por clase o bloque, permitiendo guardar borradores incompletos en todo momento.
  3. **Protección curricular y honestidad de origen:** El editor contextual bloquea la vinculación automática del currículo Adulto FIU en clases `infantil` o `mixto`, nunca etiqueta contenido manual o duplicado como `Propuesta IA`, y nunca marca recursos de Pizarra como utilizados (`hasBeenTaught` / `timesUsed`).
  4. **Refinamiento UX y separación de variantes/recursos (`PED-04B2-UX`):** Distribución ~60/40 en escritorio (`>=1200px`), tarjetas a ancho completo, etiquetas superiores (`PlannerFieldLabel` + `plannerInputDecoration`), variantes separadas en 3 niveles (`Principiantes`, `Intermedios` vía `diferenciacion_intermedios`, `Avanzados`), 5 opciones de organización pedagógica (`kPlannerOrganizationOptions`), notas de uso particulares por recurso (`resourceUsageNotes`) con apertura directa, origen propio independiente de los vínculos, y relación explícita bloque vs. suma de ejercicios.

---

### 24. Ejecución de Clases en Vivo V2 por Reloj de Pared, Recuperación Local e Idempotencia (`PED-04C1`)
- **Estado:** `[APROBADA]`
- **Contexto:** Incorporar la ejecución de clases en vivo al Planificador V2 reutilizando los patrones útiles de `_ClaseEnVivoScreen` V1 sin depender de contadores susceptibles a pausa en segundo plano ni realizar escrituras en Firestore de producción antes de autorizar persistencia remota.
- **Decisión:**
  1. **Temporizador resistente al segundo plano (`LiveSessionState`):** El tiempo transcurrido y restante se calculan desde marcas de reloj de pared (`startedAt`, `lastResumedAt`, acumuladores y reloj inyectable) reconciliadas con `WidgetsBindingObserver`, evitando deriva cuando la pestaña o app pasa a segundo plano.
  2. **Recuperación local, actualización de `ultimaEjecucion` e instantánea inmutable:** La sesión activa se serializa en JSON en `SharedPreferences` (`LiveSessionStorage`), permitiendo reanudar desde el Hub tras interrupciones. Al finalizar, `TaughtSessionRecord` guarda `planSnapshot` (copia profunda) y actualiza únicamente `ultimaEjecucion` y `vecesImpartida` en el plan original sin modificar su contenido pedagógico.
  3. **Contabilización estricta e idempotente de recursos y confirmación en `00:00`:** Solo los recursos de ejercicios marcados como `completed` incrementan `timesUsed` / `hasBeenTaught`; completar un ejercicio con `00:00` de tiempo real exige confirmación manual; y `_recordedSessionIds` evita registros duplicados en `Historial`, en `vecesImpartida` o en `timesUsed`.
  4. **Contexto pedagógico estructurado aislado por grupo (`PedagogicalContinuityContext`) y sanitización Zero-PII (`PlannerPiiSanitizer`):** «Preparar siguiente clase» transfiere los 8 campos pedagógicos (grupo, ejercicios realizados, omitidos, movimientos trabajados, dificultades, observaciones, contenido por reforzar y propuesta de continuidad) mediante un resumen expandible (`PlannerContinuityContextCard`) conservado en borrador, visor y Editor V2, con aislamiento estricto al grupo seleccionado (se reemplaza o limpia al cambiar de grupo o usar configuración manual). `toAiSafeRequestMap()` y `toAiSafeMap()` aplican `PlannerPiiSanitizer.sanitizeFreeText()` sobre observaciones e instrucciones libres para redactar nombres, teléfonos, correos, fechas e IDs preservando la terminología técnica de Capoeira/FIU.
  5. **Contención de producción:** `FirestorePlannerDataSource.recordCompletedLiveSession` mantiene los registros nuevos y actualizaciones de `ultimaEjecucion` solo en memoria de sesión durante `PED-04C1` (0 escrituras en producción), mientras `_ClaseEnVivoScreen` legacy permanece disponible para `_GeneradorClaseModal` sin romper flujos heredados.


---

### 25. Motor Pedagógico V2 Desacoplado, Seguridad por Custom Claims y Precedencia de Orígenes (`PED-04C2-A/B`)
- **Estado:** `[APROBADA]`
- **Contexto:** Evolucionar la generación automática de clases sin tocar la función legada `generarPlanClaseIA`, garantizando seguridad contra elevación de privilegios, control de presupuesto, fidelidad al catálogo FIU, flexibilidad pedagógica y trazabilidad estricta en el entorno offline antes de conectar llamadas pagadas.
- **Decisión:**
  1. **Cloud Function independiente y núcleo puro Node.js 22 (`functions/planner_v2/`):** Se separa el motor completo fuera de `functions/index.js` para probarlo offline en CI; la futura exposición remota (`PED-04C2-D`) se realizará mediante una nueva función `generarPlanClaseV2` dejando intactas `generarPlanClaseIA` y `whatsappWebhook`. En `PED-04C2-B` el proveedor real permanece estrictamente deshabilitado (`REAL_PROVIDER_DISABLED`).
  2. **Políticas exclusivamente de servidor y autorización por Custom Claims:** El servidor fija modelo primario (`gpt-4.1-mini`), alternativa (`gpt-4o-mini`), cuota atómica con idempotencia por `request_id` (`20` diarias / `4` por minuto), presupuesto de salida escalado (`4500` tokens `<=60 min` / `5600` tokens `>60 min`), timeouts y máximo `1` pase de reparación (`max_repair_attempts = 1`), rechazando cualquier intento del cliente de sobrescribirlos (`FORBIDDEN_CLIENT_POLICY_OVERRIDE`). La autorización exige Custom Claims firmados (`instructor`, `teacher`, `admin`, `curriculum_admin`) sin confiar en `users/{uid}.rol`; el bypass local sin auth aplica únicamente en desarrollo aislado.
  3. **Catálogo canónico empaquetado + validación estricta de obligatorios y espacio:** `functions/planner_v2/data/fiu_adulto_v1.json` se verifica por hash SHA-256 (`0a4b2237...`) en CI y carga. Todo movimiento o recurso `required` inválido o no autorizado se rechaza explícitamente (nunca se excluye en silencio), el payload hacia LLM excluye `uid`/`clase_id`/`group_id`/`request_id`/URLs, y no se asumen automáticamente `tatami`, `colchonetas` ni materiales cuando no han sido declarados.
  4. **Precedencia de orígenes, flexibilidad y límite explícito Zero-PII:** Al combinar recurso de Pizarra + movimiento FIU en un ejercicio prevalece `content_origin: "teacher_resource"` con `source_origins: ["teacher_resource", "official_fiu_curriculum"]` y `activity_authoring: "teacher_resource_with_official_fiu_movements"`; un ejercicio creado por IA desde FIU se distingue mediante `activity_authoring: "ai_exercise_from_official_fiu"`. Se soporta estructura flexible por enfoque (incluyendo solo Musicalidad/Angola o solo recursos del profesor sin penalización heurística) y se documenta explícitamente que la sanitización heurística reduce riesgo pero no garantiza ausencia absoluta de PII.
  5. **Honestidad de evaluación:** La validación de infraestructura y estructural determinista se separan de la evaluación pedagógica heurística offline; tanto la evaluación humana en tatami como la calidad del proveedor LLM real permanecen marcadas como pendientes.

---

### 26. Integración Flutter con Transporte Local Aislado y Guardia LAN `--token` (`PED-04C2-C`)
- **Estado:** `[APROBADA]`
- **Contexto:** Conectar Creación Rápida, Creación Avanzada, Editor V2 y Preview en tablet al motor `functions/planner_v2/` sin modificar `functions/index.js`, sin desplegar Cloud Functions ni escribir en Firestore de producción, y sin introducir credenciales OpenAI en el frontend ni exponer el preview en red abierta sin control de acceso.
- **Decisión:**
  1. **Abstracción de cliente `PlannerV2EngineClient` (`HttpLocalPlannerV2Client` en `PED-04C2-C`):** El planificador delega la generación en [planner_v2_engine_client.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_v2_engine_client.dart) sobre HTTP local (`scripts/planner_v2_local_server.js`), manteniendo cero duplicación de lógica de generación o validación en Dart y dejando preparada la subclase `FirebaseFunctionsPlannerV2Client` (`generarPlanClaseV2`) para `PED-04C2-D`.
  2. **No-suposición de espacio/materiales por defecto y preservación de estado ante fallos:** `ClassPlanDraftRequest.fromGroup` deja `materialsConfirmed = false` y `spaceContext` en valores `desconocido` / `availableMats: null` hasta confirmación explícita del instructor. Ante cualquier error de red o validación, la UI conserva íntegros los campos configurados y habilita reintento con preservación de `request_id` en el cliente.
  3. **Preview web aislado y guardia LAN obligatoria (`--token`):** `scripts/planner_v2_local_server.js` enlaza por defecto a `127.0.0.1:8097` (sin `/flutter_service_worker.js` y `Cache-Control: no-store`), prohíbe iniciar en IP LAN no-loopback sin `--token <PIN>` y protege todas las rutas `/api/planner-v2/*` y estáticos con `401 PREVIEW_TOKEN_REQUIRED`.

---

### 27. Arquitectura Modular por Bloques, Validador Ejecutable y Piloto Real Local (`PED-04C2-D`)
- **Estado:** `[APROBADA]`
- **Contexto:** Durante los primeros intentos reales con `gpt-4o-mini`, el esquema monolítico completo (`OPENAI_STRICT_CLASS_PLAN_V2_JSON_SCHEMA`, 22 campos/ejercicio + 11 raíz, `~3,537` tokens de entrada) provocaba cierre anticipado tras `blk_1` y timeouts en pases de reparación (`35s`), mientras un reintento automático en `HttpLocalPlannerV2Client` ante `504` duplicaba el consumo en segundo plano.
- **Decisión:**
  1. **Generación modular por bloques y esquema slim (`OPENAI_STRICT_BLOCK_V2_JSON_SCHEMA`):** [temporal_planner.js](file:///Users/jumper/ginga_app/functions/planner_v2/temporal_planner.js) pre-asigna duraciones exactas y vínculos obligatorios por slot; el LLM genera solo 1 bloque por llamada (`~879–950` tokens de entrada, 12 campos creativos); [block_assembler.js](file:///Users/jumper/ginga_app/functions/planner_v2/block_assembler.js) ensambla determinísticamente IDs, duraciones, orígenes, vínculos, `cantiga_id: null` y honestidad de video.
  2. **Reparación paralela acotada al subconjunto fallido y reserva multi-bloque:** [plan_repairer.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_repairer.js) repara en 1 único pase paralelo únicamente los bloques con errores sin regenerar bloques sanos; [pilot_budget_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/pilot_budget_guard.js) reserva peor caso cubriendo `blocksCount` iniciales más hasta `blocksCount` reparados simultáneamente.
  3. **Validador de juegos en 3 dimensiones ejecutables (`GAME_MISSING_EXECUTABLE_RULES`):** Todo `juego_dinamico` infantil exige descripción `>= 75` caracteres (excluyendo `Tiempos internos (...)`) cubriendo preparación/espacio, reglas/señales/consignas y rondas/turnos/rotación sin solapamiento léxico.
  4. **Cliente Flutter sin reintentos silenciosos y recuperación directa en Editor:** [planner_v2_engine_client.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_v2_engine_client.dart) usa `timeout: 120s`, elimina reintentos automáticos ante `504`/`TimeoutException` y consulta `/api/planner-v2/last-status` para abrir la clase generada en el Editor sin llamadas pagadas adicionales.
  5. **Fallback controlado y proveedor real deshabilitado por defecto:** Se prioriza `gpt-4o-mini` con fallback controlado ante `MODEL_ACCESS_DENIED` (`gpt-4.1-mini`); el proveedor real continúa deshabilitado fuera del servidor local autorizado en desarrollo (`REAL_PROVIDER_DISABLED` en producción).

---

### 28. Especialización Pedagógica en Capoeira, Participación Simultánea y Separación IA vs. Profesor (`PED-04C2-E`)
- **Estado:** `[APROBADA]`
- **Contexto:** La revisión humana del primer piloto Infantil válido (`6/8`) mostró dinámicas genéricas de educación física (`Juego de las Estatuas`, `Silla`, `Animales/Relevos`), filas/eliminaciones, prosa libre en `organizacion`, `tiempos_internos` triviales de una etapa, mezcla de `observaciones_profesor` con sugerencias IA y enrutamiento de `idea_res_02` hacia `roda_musicalidad` por mención incidental de `pandeiro`.
- **Decisión:**
  1. **Especialización en Capoeira y espacio técnico dedicado sin desbloquear FIU adulto:** En clases Infantil `50–79 min` con enfoque técnico y lúdico, el planificador temporal reserva bloques independientes para `Técnica y progresiones` y `Juegos de capoeira` (enrutando recursos por categoría/título/uso en lugar de menciones incidentales de instrumentos) e identifica movimientos no curriculares mediante `technical_movement_refs` editables sin atribuir graduaciones oficiales infantiles ni currículo Adulto FIU.
  2. **Validación pedagógica dura y reparación anti-regresión:** Se prohíben dinámicas genéricas ajenas a Capoeira, filas/eliminaciones/`Turnos` cuando se solicita participación simultánea, `tiempos_internos` de una sola etapa para ejercicios $\ge 4\text{ min}$, rodadas/volteretas en suelo sin tatami/colchonetas, materiales no confirmados sin alternativa (`palmas/voz`) y musicalidad sin las 3 dimensiones ejecutables (reportando exactamente qué dimensión falta); el reparador preserva determinísticamente campos y ejercicios hermanos ya válidos (`preserveValidExercisesOnBlockRepair`).
  3. **Separación visual e interna IA vs. Profesor y tiempos estructurados:** El esquema de bloque, los modelos Dart, el Editor V2 y la Vista en Vivo separan `sugerencias_ia` de `observaciones_profesor`, soportan etapas editables en `tiempos_internos` con etiquetas legibles por bloque y amplían el timeout cliente local a `180s` para cubrir hasta 3 oleadas de 5 bloques más su eventual reparación.

### 29. Copiloto Conversacional Pedagógico Tipado con Confirmación Explícita y Modo Offline-First (PED-04C3) — [APROBADA]
- **Decisión:** Integrar el Copiloto directamente dentro de `PlannerClassEditorView` operando sobre un contrato estricto de 10 operaciones tipadas sobre `ClassPlanModel` (prohibiendo mutaciones directas en Firestore o código generado), aplicado de forma inmutable en código determinista tras validación completa y confirmación explícita del profesor (`Aplicar cambios` / `Descartar` / `Deshacer IA`), con detección de conflicto por firma del borrador (`computeDraftVersion` / `computeDraftVersionHash`).
- **Aislamiento de Presupuesto y Validación Real Acotada:** El Copiloto mantiene presupuesto independiente (`scratch/copilot_ped04c3_budget_state.json`, tope `$0.05` USD), preservando intacto el piloto `PED-04C2` (`$0.020187 / $0.10`, `8/8`, `28` llamadas). Validación real acotada aprobada con `gpt-4o-mini` (`$0.004682 / $0.05` en `6` escenarios reales más `4` fallos históricos `$0.00` conservados en auditoría).

### 30. Gestión Local Segura de API Key vía macOS Keychain sin Exposición ni Límite de `getpass()` (PED-04C3) — [APROBADA]
- **Decisión:** Almacenar la API Key local de desarrollo exclusivamente en **macOS Keychain** (`ginga-dev-openai-api-key`) mediante lectura oculta (`read -r -s`) y entrada hexadecimal por `stdin` (`security -i` con `-X`), evitando `.env`, `.zshrc`, argumentos CLI visibles en `ps` y el truncamiento a 128 caracteres de `getpass()`, junto al lanzador único [start_ginga_dev_server.sh](file:///Users/jumper/ginga_app/scripts/start_ginga_dev_server.sh) y sin modificar producción ni Firebase Secret Manager.

---

### 31. Persistencia Real Firestore, Concurrencia Optimista, Reglas e Idempotencia Multidispositivo (`PED-05`) — `[APROBADA]`
- **Decisión:** Reutilizar colecciones existentes (`instructor_planes_clase`, `instructor_ideas`, `instructor_sesiones_impartidas`, `clases`, `users`) e incorporar `instructor_sesiones_activas/active_{uid}` exclusivamente para continuidad en vivo multidispositivo sin tocar `sesiones` (QR) ni `asistencias`.
- **Ciclo de vida, concurrencia optimista y separación histórica:** `ClassPlanStatus` valida transiciones (`draft`, `saved`/`planned`, `in_progress`, `completed`, `archived`); `FirestorePlannerDataSource.savePlan` y `updatePlanStatus` operan dentro de `runTransaction` con `expectedRevision` entero monotónico levantando `PlannerConcurrencyConflictException` ante ediciones concurrentes entre PC/tablet/celular (ofreciendo recargar versión remota o guardar copia independiente sin sobrescritura silenciosa). `recordCompletedLiveSession` usa transacción idempotente por `session_id`, crea documento inmutable en `instructor_sesiones_impartidas` (`allow update, delete: if false`) con `plan_snapshot`, actualiza solo métricas del plan e incrementa `veces_impartida` y `completado` únicamente en `taughtResourceIds` (nunca al guardar borradores).
- **Continuidad grupal y Copiloto:** `PedagogicalContinuityContext.fromGroupHistory` resume hasta las 3 últimas sesiones del grupo exacto en contrato `Zero-PII` tanto para Generador V2 como Copiloto; `copilot_engine.js` excluye campos persistidos de auditoría (`created_at`, `updated_at`, etc.) al ejecutar `scanResidualPiiHeuristic` para evitar falsos positivos con timestamps ISO al editar planes guardados en Firestore.
- **Seguridad y Bloqueadores P0 Preexistentes:** `firestore.rules` exige `isPlannerInstructor()` + aislamiento `instructor_id == request.auth.uid`, estados válidos e inmutabilidad histórica, bloqueando lectura/escritura cliente sobre cuotas IA. Los bloqueadores P0 históricos (`users/{userId}` y colecciones legacy aún con `request.auth != null`) y la ausencia de proyecto separado `ginga-staging` permanecen explícitamente registrados como prerrequisitos obligatorios antes de abrir escritura en producción (`capoeirafiu-ea8ljo`).

---

### 32. Endurecimiento de Seguridad P0 (`firestore.rules`, Cloud Functions, Roles y Preparación Staging) (`PED-06A`) — `[APROBADA]`
- **Decisión:** Resolver todos los bloqueadores P0 de seguridad preexistentes sin alterar comportamiento productivo de `whatsappWebhook` ni romper consumidores legítimos Flutter (`login`, `splash`, `instructor`, `qr_scanner`, `clase_detalle`, `carrito`, `cantigas`, `biblioteca`, `feedback`, `planificador V2`).
- **Reglas Firestore y Default-Deny:** Endurecer `users/{userId}` (lectura restringida a dueño o `isStaff()`, auto-registro acotado a `rol == 'alumno'` y `status == 'nuevo'`, actualización de propietario mediante `affectedKeys().hasOnly(...)` impidiendo mutación de `rol`, `corda`, `clase_id`, `fecha_inicio`, `uid` y `email` y validando transiciones de `status`), restringir `whatsapp_leads` y `mensajes` a `isStaff()`, acotar `asistencias` contra sesiones QR activas, proteger `clases` (solo decremento `cupos_disponibles` en `-1` por alumnos), `reservas`, `pedidos`, `pagos`, `config`, `tutoriales`, `cantigas`, `eventos` y agregar `match /{document=**} { allow read, write: if false; }` preservando estrictamente `isCurriculumAdmin()` basado solo en Custom Claims.
- **Unificación de Roles (`admin` / `administrador` / `profesor`):** Centralizar equivalencias en `UserRoleUtils` ([user_role_utils.dart](file:///Users/jumper/ginga_app/lib/core/utils/user_role_utils.dart)), `normalizeUserRole` en `functions/index.js`, `assertAuthorizedActor` en [auth_and_quota_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/auth_and_quota_guard.js), `firestore.rules` y el script idempotente [migrate_auth_roles_and_claims.js](file:///Users/jumper/ginga_app/scripts/migrate_auth_roles_and_claims.js) (exclusivo de Emulador, normalizando `'administrador' -> 'admin'` sin modificar cuentas reales). Proteger [cantigas_service.dart](file:///Users/jumper/ginga_app/lib/core/services/cantigas_service.dart) con guarda `isStaff` antes de intentar seeding automático.
- **Endurecimiento Cloud Functions y Anti-SSRF:** Proteger `migrarMensajesHistoricos`, `ejecutarStressTestAI` y `actualizarMiniaturasExistentes` mediante `verifyHttpAdminRequest` (`POST` + token Bearer + Custom Claim `admin`), `dry_run: true` por defecto, confirmación explícita + bandera `ALLOW_STRESS_TEST_HTTP` y `isSafePublicHttpUrl` en `obtenerOgImage`; proteger los callables `sendManualWhatsAppMessage` (`profesor`/`admin`, `20/min`, validación de formato `leadId`/texto y existencia del lead) y `generarPlanClaseIA` (`profesor`/`admin`, `4/min`, acotación de `duracion` `20..180` y payload). Preservar intactos los límites y riesgos residuales documentados (rate limit en memoria Gen 1 y activación futura de App Check + `ginga-staging` en `PED-06B`) en [PED06A_SECURITY_AND_STAGING_GUIDE.md](file:///Users/jumper/ginga_app/docs/PED06A_SECURITY_AND_STAGING_GUIDE.md).

---

### 33. Estabilización Determinista de Regresiones, Cuotas Transaccionales, Multi-Entorno Flutter y Preparación Cloud de Staging (`PED-06B`) — `[APROBADA]`
- **Decisión:** Completar toda la preparación de ingeniería, seguridad indirecta, callables V2, cuotas transaccionales, configuración Flutter multi-entorno y validación integral de 15 pasos en Emulador antes de solicitar autorización humana para crear el proyecto cloud `ginga-staging` y habilitar Blaze.
- **Reloj determinista para harness de agente WhatsApp:** Incorporar `fixedNowIso` en `RealAgentHarness` ([loader.js](file:///Users/jumper/ginga_app/real_agent_harness/loader.js)) inyectando `DeterministicDate` sobre `vm.compileFunction`, estabilizando `test_p1a_runtime_guard.js` (`27/27`) y `test_qa_regressions.js` (`33/33`) sin modificar comportamiento productivo ni fechas de reservas reales.
- **Endurecimiento indirecto de reglas y cuotas transaccionales:** Exigir transición atómica `nuevo -> prueba` (`get` + `getAfter`) al decrementar `clases.cupos_disponibles`, ID compuesto `${sesion_id}_${uid}` + consistencia `clase_id`/`fecha` en `asistencias` ([qr_scanner_screen.dart](file:///Users/jumper/ginga_app/lib/features/home/qr_scanner_screen.dart) y [firestore.rules](file:///Users/jumper/ginga_app/firestore.rules)), existencia de clase en `reservas` y `!leido` en creación de notificaciones no-staff. Incorporar `assertTransactionalRateLimit` sobre `_quota_runtime` en [functions/index.js](file:///Users/jumper/ginga_app/functions/index.js) y registrar oficialmente `generarPlanClaseV2` y `copilotoPedagogicoV1` (`us-central1`, modo simulado por defecto).
- **Separación estricta de infraestructura y cuentas:** Mantener [lib/firebase_options.dart](file:///Users/jumper/ginga_app/lib/firebase_options.dart) productivo sin cambios mediante [ginga_environment.dart](file:///Users/jumper/ginga_app/lib/core/config/ginga_environment.dart) (bloqueando `GINGA_ENV=staging` sobre `capoeirafiu-ea8ljo`), Web App Check reCAPTCHA v3 en [main.dart](file:///Users/jumper/ginga_app/lib/main.dart) y sección `hosting` en [firebase.json](file:///Users/jumper/ginga_app/firebase.json). Documentar cuenta propietaria (`capoeirafiuapp@gmail.com` separada de Google AI Pro), costo estimado (`$0.00–$1.00 USD/mes` con presupuesto `$5 USD`), sembrador sintético [seed_staging_synthetic_data.js](file:///Users/jumper/ginga_app/scripts/seed_staging_synthetic_data.js) y guía paso a paso en [PED06B_STAGING_PROVISIONING_PLAN.md](file:///Users/jumper/ginga_app/docs/PED06B_STAGING_PROVISIONING_PLAN.md).
