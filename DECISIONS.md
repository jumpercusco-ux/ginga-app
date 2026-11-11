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

### 5. Preparación Multisede Retrocompatible
- **Estado:** `[PROPUESTA]`
- **Contexto:** Posible apertura de sedes futuras en Cusco (Magisterio, Larapa, etc.) o en otras ciudades.
- **Decisión:** Incorporar campos opcionales `sede_id` y `session_id` en las entidades de reserva y clases, manteniendo fallback a los campos actuales (`sede`, `ubicacion`, `dias`, `hora`).
- **Restricción:** No crear sedes ni horarios ficticios como configuración real de producción mientras no existan físicamente.

### 6. Agent Control Center
- **Estado:** `[PROPUESTA]`
- **Contexto:** Necesidad de los instructores y administradores de monitorear la salud de las herramientas del agente.
- **Decisión:** Diseñar una pantalla administrativa con interruptores (toggles) dinámicos para habilitar/deshabilitar herramientas para el LLM, con la restricción estricta de que el panel **no puede desactivar validaciones críticas de backend**.

### 7. Integración con Plataforma DANEV mediante API/Eventos
- **Estado:** `[PROPUESTA]`
- **Contexto:** Futura sincronización de leads calificados y reservas con el CRM y analítica central de DANEV.
- **Decisión:** Diseñar contratos de eventos auditables normalizados en JSON Schema (`event_id`, `timestamp`, `tool_name`, `lead_hash`, `diff`), listos para emitirse vía HTTP webhook cuando se apruebe la integración.
- **Restricción:** No implementar llamadas ni infraestructura externa antes de la aprobación formal.

---

## Decisiones Comerciales y de Negocio

### 8. Diferenciación Formal entre Reserva, Asistencia y Matrícula
- **Estado:** `[APROBADA]`
- **Decisión:** Establecer claramente los tres conceptos dentro del sistema:
  - **Reserva (`/reservas`):** Intención comercial previa de asistir a una clase de prueba gratuita. Estado: `confirmado`.
  - **Asistencia (`/asistencias`):** Verificación física presencial en el tatami (check-in QR o manual del profesor). Actualiza la reserva a `asistio`.
  - **Matrícula (`/users` rol alumno / `/pagos`):** Alumno regular con mensualidad o plan multimes pagado. Deja de ser prospecto de WhatsApp y pasa a gestión de alumno en la app móvil.

### 9. Política sobre Segunda Clase de Prueba Gratuita
- **Estado:** `[PENDIENTE]`
- **Contexto:** Un alumno que ya asistió a su clase de prueba gratuita vuelve a escribir solicitando otra clase sin costo.
- **Propuesta Técnica:** Permitir **únicamente 1 clase de prueba gratuita por persona de por vida**. Si el lead ya cuenta con estado `asistio`, el agente debe agradecer su participación previa, ofrecer los planes de membresía mensual vigentes (S/140 regular, S/260 promo acompañados) y, si el cliente insiste en una segunda prueba, invocar `marcar_seguimiento_humano` para que el profesor autorice la excepción.
- **Acción Requerida:** Aprobación o ajuste formal por parte de los directores comerciales de GINGA.

### 10. Política de Reprogramación tras Inasistencia (No-Show)
- **Estado:** `[PENDIENTE]`
- **Contexto:** Un alumno que reservó su clase no asistió (el profesor marcó `no_asistio` o la fecha transcurrió sin check-in).
- **Propuesta Técnica:** Permitir **un (1) reagendamiento automático** de cortesía si el cliente se comunica para justificar la inasistencia. Si incurre en una segunda falta consecutiva, el agente deriva automáticamente a contacto humano con el profesor.
- **Acción Requerida:** Aprobación o ajuste formal por parte de los directores comerciales de GINGA.
