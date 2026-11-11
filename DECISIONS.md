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

