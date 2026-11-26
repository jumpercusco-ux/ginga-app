# Estado Actual del Proyecto GINGA (CURRENT-STATE)

> **Documento Maestro de Estado y Arquitectura**  
> **Última Actualización:** 2026-11-26  
> **Rama Actual:** `feat/ped03-biblioteca-curricular` (base `main` `fd891a7` intacta; sin merge ni despliegue)  
> **Commits de Respaldo PED-03 / PED-04:** `613cefe` (Biblioteca Curricular FIU V1, `29` archivos) · `74f1fcc` (cierre PED-03C-CI) · `93ee84b` (cierre PED-04B1) · `62bb7f8` (cierre `PED-04B2` / `PED-04B2-UX`) · cierre `PED-04C1` en `feat/ped03-biblioteca-curricular`  
> **CI GitHub Actions (`feat/ped03-biblioteca-curricular`):** 🔄 En verificación de cierre `PED-04C1` (previo `62bb7f8` en `success`: `Flutter Web & Unit Tests` + `Node.js 22 & Agent Quality Benchmark`)  
> **Producción Intacta:** `whatsappWebhook v69` (Cloud Functions Gen 1, Node.js 22), web `https://www.gingaperu.com`, proyecto `capoeirafiu-ea8ljo`  
> **Estado Actual:** **PED-04C2-B IMPLEMENTADO Y PROBADO OFFLINE EN `feat/ped03-biblioteca-curricular` (MOTOR `functions/planner_v2/`, PROVEEDOR REAL DESHABILITADO, PREVIEW `8097` INTACTO)**

---

## 1. Arquitectura y Tecnologías

El sistema real de GINGA es una plataforma de atención comercial y gestión de academia de Capoeira que opera como un **single-agent con function calling**:

```mermaid
flowchart LR
    A["Cliente WhatsApp"] <--> B["Meta WhatsApp Cloud API\n(Graph API v20.0)"]
    B <--> C["Cloud Functions (Node.js 20)\nwhatsappWebhook"]
    C <--> D["OpenAI API\n(gpt-4o-mini + Function Calling)"]
    C <--> E["Cloud Firestore\n(NoSQL DB)"]
    E <--> F["Flutter App\n(Instructores y Alumnos)"]
```

### Componentes Clave:
- **Runtime Backend:** Node.js 20 en Google Cloud Functions (Firebase Functions v4.4.1).
- **Orquestación Conversacional:** Modelo `gpt-4o-mini` vía OpenAI Chat Completions API con tool-calling secuencial (tope de 4 rondas por turno).
- **Base de Datos:** Cloud Firestore en modo nativo (`capoeirafiu-ea8ljo`).
- **Canal de Mensajería:** Meta WhatsApp Cloud API con verificación de firma HMAC-SHA256 (`X-Hub-Signature-256`), deduplicación por `wa_message_id` y debounce de 5.0 segundos.
- **Frontend Móvil:** Aplicación Flutter multirol (`alumno`, `profesor`) en iOS y Android.
- **Harness de Pruebas Aislado (`real_agent_harness/`):** Servidor local (`http://127.0.0.1:3333`) que ejecuta el código real de `functions/index.js` en memoria con emuladores puros de Firestore, OpenAI y WhatsApp.

---

## 2. Ramas y Commits Relevantes

| Rama | Commit HEAD | Propósito y Estado |
|---|---|---|
| **`main`** | `3058ada` | **Producción activa.** Referencia de Git asociada al tag `pre-live-original-2026-10-27`. Cloud Function `whatsappWebhook v67` activa en Google Cloud (desplegada 2026-10-23T04:47:06Z; no se asume equivalencia binaria estricta). |
| **`fix/real-whatsapp-logic`** | `1197225` | **Rama Release Candidate local.** Contiene la implementación íntegra de GINGA Real: P0.1 (`9c53417`), P0.2A (`df2650e`), P0.2B (`ae75ee6`), P1A (`847d3be`), blindaje de identidad (`d9bb995`), regresiones completas (123/123 PASS) y QA real OpenAI 12/12 (`1197225`). |
| `stabilization/pre-live-2026-10-28` | `caf628a` | Línea independiente de estabilización previa al LIVE de TikTok (controles de seguridad e idempotencia). |
| `demo/tiktok-live-2026-10-28` | `7243a7f` | Línea exclusiva de demostración visual en memoria para grabación y TikTok LIVE (código aislado en `demo/`). |

---

## 3. Estado Real: Producción vs. Desarrollo vs. Simulador

- **Producción (`whatsappWebhook v67` en `main` `3058ada`):**
  - Intacta, sin cambios, sin despliegue.
  - Opera con amnesia de reservas: `generarSystemPrompt` no consulta `/reservas`.
  - Sufre bloqueo de reservas si el lead tiene una reserva cancelada o pasada.
  - No soporta reprogramación de fechas; arriesga alucinaciones de confirmación de palabra.
- **Desarrollo Local (`fix/real-whatsapp-logic`):**
  - **P0.1 implementado:** `generarSystemPrompt` recibe `leadId` y consulta `/reservas` activas en `America/Lima` (commit `9c53417`, 14/14 tests PASS).
  - **P0.2A implementado:** Tool real `reprogramar_reserva` con persistencia atómica, corrección de duplicados, salvaguardas comerciales y lock transaccional (commit `df2650e`, 22/22 tests PASS).
  - **P0.2B implementado:** Identidad familiar no destructiva, aislamiento por alumno y soporte para múltiples reservas (commit `ae75ee6`, 10/10 tests PASS).
  - **Gate de Integración completado:** Consolidación de Decisiones 5 y 13 (commit `bd36b9a`).
  - **P1A implementado localmente:**
    - Runtime Guard determinista post-generación en `preguntarIA`.
    - Detección semántica de afirmaciones no respaldadas (`booking`, `reschedule`, `cancellation`) y contradicciones de rechazos de tools.
    - Validación estructurada de correspondencia de **persona**, **fecha** y **tipo de operación**.
    - Prevención de contradicciones en resultados mixtos familiares (un hijo confirmado y otro rechazado por cupos).
    - Sustitución automática por mensaje seguro y escalación a `requiere_atencion` con detección de `alreadyEscalated`.
    - Fallback técnico transparente si la persistencia de base de datos falla, sin falsas promesas.
    - Preservación de `ai_habilitada` (el guard no la desactiva automáticamente).
    - Telemetría estructurada Zero PII con `lead_hash` HMAC-SHA256 (`TELEMETRY_SALT`) y `persona_ref` (`p_` + hash) que previene desanonimización de teléfonos o nombres de menores.
    - Suite P1A superada al 100% (**27/27 tests PASS**).
    - Suite de línea base eliminó el defecto histórico de Caso 8 (9/9 escenarios OK, 0 defectos).
    - Total de suites de pruebas locales: **82 de 82 pruebas aprobadas (100% PASS)**.
- **Simulador Local (`real_agent_harness/`):**
  - Activo en `http://127.0.0.1:3333`.
  - Ejecuta el archivo real `functions/index.js` mediante Node.js `vm.compileFunction`.
  - Emula Firestore en memoria con fixtures de Cusco (`config/negocio`, `clases`, `users`).
  - Permite pruebas automáticas y manuales con costo cero y sin tocar la nube.

---

## 4. Catálogo de Tools Actuales

Ubicadas en `functions/index.js` (`AVAILABLE_TOOLS`):

1. **`consultar_horarios_disponibles`:**
   - *Lectura:* `/clases` (where `tipo == 'regular'`), `/config/negocio`.
   - *Salida:* Texto formateado con horarios, edades, cupos, sede Cusco, precios (S/140 regular, S/260 promo acompañados, S/380 y S/720 multimes) y número de Yape.
2. **`guardar_perfil_lead`:**
   - *Escritura:* `whatsapp_leads/{leadId}.perfil_personas`.
   - *Parámetros:* `personas` (Array de `{nombre, tipo, edad}`).
   - *Comportamiento P0.2A:* Fusión inteligente por slug (`slugifyPersona`), preservando a los hijos registrados previamente y actualizando datos sin sobreescritura destructiva.
3. **`reservar_clase_prueba`:**
   - *Lectura:* `/whatsapp_leads`, `/clases`, `/reservas`.
   - *Escritura (Transaccional):* Crea `/reservas/{id}`, actualiza `whatsapp_leads` (`reserva_id`, `fecha_clase_reservada`, `reservas_activas[slug]`) y crea notificación para el profesor en `/users/{instId}/notificaciones`.
   - *Mejoras P0.2A:*
     - Chequeo de duplicados e idempotencia dentro de `runTransaction` usando `reservas_activas[slug]`.
     - Ignora reservas con `status == 'cancelado'` o con `fecha_clase` en el pasado.
     - Intercepta estados `asistio` o `no_asistio` aplicando política comercial y derivando a `marcar_seguimiento_humano`.
     - Sugiere `reprogramar_reserva` si ya existe una cita activa confirmada para esa persona.
4. **`reprogramar_reserva` (NUEVA P0.2A):**
   - *Lectura:* `/whatsapp_leads`, `/reservas`, `/clases`.
   - *Escritura (Transaccional):* Modifica `/reservas/{id}` (`fecha_clase`, `hora`, `updated_at`), añade entrada de auditoría en `reprogramaciones`, actualiza `whatsapp_leads.reservas_activas[slug]` y crea notificación en `/users/{instId}/notificaciones`.
   - *Parámetros:* `nombre` (string opcional/deducible), `nueva_fecha` (AAAA-MM-DD), `motivo` (opcional).
   - *Protección:* Valida días de clase permitidos (`M, J`), cupos disponibles, fecha futura, y prohíbe reprogramar citas canceladas, vencidas o asistidas.
5. **`marcar_seguimiento_humano`:**
   - *Escritura:* Actualiza `whatsapp_leads.status = 'requiere_atencion'`, crea notificaciones batch en `/users` (rol profesor) y alerta por WhatsApp al instructor.

---

## 5. Pruebas Existentes y Resultados

### A. Suite de Reconocimiento de Reservas P0.1 (`test_p01_recognition.js`):
- **14 de 14 pruebas pasaron (100% PASS):**
  - Caso A: Lead nuevo sin reservas $\rightarrow$ Prompt limpio.
  - Caso B: Reserva futura confirmada $\rightarrow$ Inyectada con fecha y hora.
  - Caso C: Reserva para hoy pendiente $\rightarrow$ Reconocida como HOY.
  - Caso D: Reserva cancelada $\rightarrow$ Descartada de vigentes.
  - Caso E: Reserva pasada $\rightarrow$ Descartada de vigentes.
  - Caso F: Estado `asistio` $\rightarrow$ Descartado de pendientes.
  - Caso G: Estado `no_asistio` $\rightarrow$ Descartado de pendientes.
  - Caso H: Familia con dos hijos $\rightarrow$ Ambos hijos listados independientemente.
  - Caso I: Error de Firestore $\rightarrow$ Fail-safe sin crasheos.
  - Caso J: Directivas contra duplicación de registro $\rightarrow$ Verificadas.
  - Caso K: Reserva de hoy que ya terminó $\rightarrow$ Descartada.
  - Caso L: Protección contra promesas falsas de reprogramación $\rightarrow$ Verificada.
  - Caso M: Neutralidad de género $\rightarrow$ Verificada.
  - Caso N: Aviso de seguridad ante caída de BD $\rightarrow$ Verificado.

### B. Suite de Pruebas P0.2A (`test_p02a_rescheduling.js`):
- **22 de 22 pruebas pasaron (100% PASS):**
  1. `01_martes_a_jueves`: Reprogramación atómica en Firestore con auditoría y notificación.
  2. `02_jueves_a_martes`: Reprogramación a la semana siguiente.
  3. `03_dos_hijos_aislacion`: Independencia total de reservas entre hermanos (Valentina y Mateo).
  4. `04_reserva_inexistente`: Manejo limpio sin falsas confirmaciones.
  5. `05_reserva_cancelada`: Bloquea reprogramar canceladas pero permite crear nuevas citas.
  6. `06_politica_comercial_asistio`: Salvaguarda provisional: Bloquea segundas clases gratis tras asistir y deriva a instructor.
  7. `07_politica_comercial_no_asistio`: Salvaguarda provisional: Bloquea reagendamiento desatendido tras inasistencia.
  8. `08_reserva_pasada_vencida`: Rechaza reprogramar citas vencidas.
  9. `09_capacidad_cupos_cero`: Detecta cupos agotados y escala a lista de espera.
  10. `10_fecha_invalida_rechazo`: Fechas inválidas preservan la cita original sin alteración.
  11. `11_reprogramaciones_repetidas`: Mantiene array histórico de auditoría con motivos.
  12. `12_concurrencia_idempotencia`: Lock optimista en `whatsapp_leads` aborta duplicados concurrentes.
  13. `13_failsafe_error_firestore`: Fail-safe ante caídas de BD prohíbe promesas falsas.
  14. `14_proteccion_alucinacion`: Garantiza que el agente solo confirma tras éxito en BD.
  15. `15_compatibilidad_legacy_multisede`: Manejo limpio de documentos sin `sede_id`.
  16. `16_fusion_perfiles_multi_hijos`: Fusión acumulativa de perfiles familiares sin sobreescritura.
  17. `17_dos_leads_cupo_cero`: Control de capacidad ante múltiples leads compitiendo con cupos agotados.
  18. `18_lead_legacy_sin_reservas_activas`: Compatibilidad con leads de producción que solo tienen `reserva_id` escalar.
  19. `19_dos_hijos_nombre_ambiguo`: Rechazo de nombres ambiguos o genéricos ("mi hijo") evitando alterar la reserva errónea.
  20. `20_sede_sin_ubicacion_no_inventa`: Prohibición estricta de hardcodear o inventar direcciones no comprobadas.
  21. `21_reprogramacion_sin_segunda_clase`: Reprogramación modifica la cita existente sin conceder clases extras.
  22. `22_error_transaccional_failsafe`: Manejo seguro de abortos transaccionales por contención o cupos.

### C. Suite de Identidad Familiar P0.2B (`test_p02b_family_identity.js`):
- **10 de 10 pruebas pasaron (100% PASS):**
  1. `01_familia_dos_hijos_dos_reservas`: Documentos independientes en `/reservas` y `reservas_activas`.
  2. `02_reprogramar_hijo_sin_alterar_hermano`: Reprogramación de Mateo a jueves sin tocar reserva de Lucía en martes.
  3. `03_mensaje_ambiguo_solicita_aclaracion`: Solicitud explícita de aclaración ante referencias ambiguas.
  4. `04_referencia_inequivoca_por_nombre`: Despacho exacto a la persona indicada.
  5. `05_lead_legacy_reserva_id_escalar`: Reconciliación no destructiva con reservas históricas.
  6. `06_registro_nuevo_con_reservas_activas`: Reprogramación directa vía `reserva_id`.
  7. `07_familia_reserva_cancelada_y_activa`: Aislamiento de estados entre hermanos.
  8. `08_dos_hijos_nombres_iguales_desambiguacion`: Desambiguación forzada ante homónimos.
  9. `09_intento_operar_reserva_ajena_unauthorized`: Rechazo estricto de autorización por teléfono.
  10. `10_reintento_operacion_sin_duplicar`: Idempotencia de booking en reintentos.

### D. Suite de Runtime Guard y Telemetría P1A (`test_p1a_runtime_guard.js`):
- **27 de 27 pruebas pasaron (100% PASS):**
  1. `01_booking_tool_success_allowed`: Booking exitoso con tool persistido $\rightarrow$ ALLOW.
  2. `02_booking_without_tool_intercepted`: Alucinación verbal de booking sin tool $\rightarrow$ INTERCEPT, fallback seguro y `requiere_atencion`.
  3. `03_booking_tool_failed_intercepted`: Falla de base de datos en booking $\rightarrow$ INTERCEPT.
  4. `04_booking_tool_rejected_already_attended_intercepted`: Rechazo por `asistio` previo con alucinación $\rightarrow$ INTERCEPT.
  5. `05_booking_tool_rejected_no_show_intercepted`: Rechazo por `no_asistio` previo con alucinación $\rightarrow$ INTERCEPT.
  6. `06_booking_tool_rejected_class_full_intercepted`: Rechazo por `cupos_disponibles == 0` $\rightarrow$ INTERCEPT.
  7. `07_reschedule_tool_success_allowed`: Reprogramación exitosa persistida $\rightarrow$ ALLOW.
  8. `08_reschedule_without_tool_intercepted`: Defecto histórico baseline interceptado $\rightarrow$ INTERCEPT.
  9. `09_reschedule_tool_rejected_invalid_date_intercepted`: Rechazo por fecha de día inválido $\rightarrow$ INTERCEPT.
  10. `10_reschedule_tool_rejected_expired_date_intercepted`: Rechazo por cita vencida en el pasado $\rightarrow$ INTERCEPT.
  11. `11_preexisting_reservation_reminder_allowed`: Recordatorio de cita previa en `systemPrompt` sin tool $\rightarrow$ ALLOW.
  12. `12_consultation_horarios_allowed`: Consulta de horarios y precios sin mutación $\rightarrow$ ALLOW.
  13. `13_profile_saving_allowed`: Guardado de perfil familiar sin mutación $\rightarrow$ ALLOW.
  14. `14_human_escalation_allowed`: Escalación humana vía `marcar_seguimiento_humano` $\rightarrow$ ALLOW.
  15. `15_telemetry_zero_pii_verification`: Verificación estricta de telemetría Zero PII (`lead_hash` HMAC-SHA256, sin teléfonos en texto claro).
  16. `16_multi_tool_execution_telemetry`: Ejecución multi-tool encadenada (`guardar_perfil_lead` + `reservar_clase_prueba`) $\rightarrow$ ALLOW y telemetría íntegra.
  17. `17_booking_success_different_person_intercepted`: Éxito para Mateo pero texto afirma Lucía $\rightarrow$ INTERCEPT (discrepancia de persona).
  18. `18_booking_success_different_date_intercepted`: Éxito para martes 17 pero texto afirma jueves 19 $\rightarrow$ INTERCEPT (discrepancia de fecha).
  19. `19_cross_operation_mismatch_intercepted`: Herramienta de reserva intentando autorizar afirmación de reprogramación $\rightarrow$ INTERCEPT.
  20. `20_multi_child_mixed_results_intercepted`: Resultados mixtos (Mateo OK, Lucía rechazada) con afirmación colectiva de éxito $\rightarrow$ INTERCEPT.
  21. `21_negation_and_hypothesis_no_false_positive`: Frases explicativas de negación ("no pude agendar") e hipótesis $\rightarrow$ ALLOW (sin falso positivo).
  22. `22_unrecognized_idiom_boundary_documented`: Límite semántico documentado ante modismos atípicos sin verbos estándar ("apunté en la libreta").
  23. `23_error_on_human_escalation_safe_fallback`: Falla en Firestore durante intercepción entrega mensaje técnico sin promesas falsas.
  24. `24_retry_deduplication_already_escalated`: Reintento sobre lead ya escalado detecta `alreadyEscalated` evitando saturación de alertas.
  25. `25_telemetry_sanitization_deep_inspection`: Inspección profunda de eventos: `persona_ref` HMAC, sin nombres de menores ni teléfonos.
  26. `26_multi_turn_turncontext_isolation`: Aislamiento estricto de `TurnContext`: Turno 1 no autoriza alucinaciones en Turno 2.
  27. `27_all_llm_exit_routes_coverage`: Cobertura exhaustiva: `preguntarIA` intercepta antes de entregar texto al webhook.

### E. Suite de Línea Base (`suite_runner.js`):
- Caso 1: Consulta de horarios $\rightarrow$ **OK**.
- Caso 2: Reserva vigente $\rightarrow$ **OK**.
- Caso 3: Reserva cancelada que quiere agendar $\rightarrow$ **OK (RESUELTO EN P0.2A)**.
- Caso 4: Reserva pasada que quiere volver a reservar $\rightarrow$ **OK (RESUELTO EN P0.2A)**.
- Caso 5: Padre/madre con dos hijos y reservas diferentes $\rightarrow$ **OK (RESUELTO EN P0.2B)**.
- Caso 6: Solicitud de reprogramación martes a jueves $\rightarrow$ **OK (RESUELTO EN P0.2A)**.
- Caso 7: Persistencia documental de nueva fecha $\rightarrow$ **OK (RESUELTO EN P0.2A)**.
- Caso 8: Confirmación textual sin escritura persistida $\rightarrow$ **OK (RESUELTO EN P1A)**: Runtime Guard interceptó la promesa falsa sin persistencia.
- Caso 9: Control humano $\rightarrow$ **OK**.
- **Resultado Global de Línea Base:** **9 de 9 escenarios OK (0 defectos documentados restantes).**

---

## 6. Especificación Técnica e Implementación P0.2A: Reprogramación Segura e Integridad

> [!IMPORTANT]
> **Estado:** IMPLEMENTACIÓN LOCAL COMPLETADA Y VALIDADA. Pendiente de revisión del usuario antes de commit.

### 6.1. Reglas de Negocio y Estados de Reserva

El ciclo de vida formal de una reserva de clase de prueba se rige por la siguiente máquina de estados:

```mermaid
stateDiagram-v2
    [*] --> confirmado: reservar_clase_prueba
    confirmado --> confirmado: reprogramar_reserva (nueva fecha)
    confirmado --> cancelado: cancelar_reserva o cliente desiste
    confirmado --> asistio: Check-in presencial / QR en academia
    confirmado --> no_asistio: Fecha transcurre sin asistencia
    cancelado --> [*]
    asistio --> [*]: Pasa a venta de membresía
    no_asistio --> confirmado: Reagendamiento autorizado (1 oportunidad)
```

- **`confirmado`:** Reserva activa vigente con fecha futura o de hoy pendiente de inicio.
- **`cancelado`:** El cliente avisó que no podrá ir o canceló la cita. **NO debe bloquear nuevas reservas futuras**.
- **`asistio`:** El alumno asistió a su clase de prueba (registrado en `/asistencias` y `/reservas`).
- **`no_asistio`:** La fecha pasó y no hubo check-in.
- **Diferencia Operativa:**
  - *Reserva:* Registro comercial en `/reservas` asociado a un lead de WhatsApp.
  - *Asistencia:* Registro físico en `/asistencias` vinculado a una sesión presencial.
  - *Matrícula:* Alta de alumno regular en `/users` (`rol: alumno`) con pagos mensuales en `/alumnos` o `/pagos`.

### 6.2. Estrategia de Reprogramación: ¿Mismo Documento o Cancelar y Crear?
**Decisión Técnica:** **Mismo documento con historial de cambios (`audit_trail`).**
- *Justificación:* Mantener el mismo `reservaId` preserva la trazabilidad del lead en la app del instructor (evita generar notificaciones huérfanas o duplicar filas en la UI del profesor).
- *Campos a actualizar atómicamente:*
  - `fecha_clase`: Nuevo `Timestamp` a mediodía hora Lima.
  - `dias`: Días de la clase.
  - `updated_at`: `FieldValue.serverTimestamp()`.
  - `reprogramaciones`: Array append `{ fecha_anterior, fecha_nueva, motivo, timestamp }`.

### 6.3. Contratos de Herramientas para P0.2

#### Tool 1: `reprogramar_reserva` (NUEVA)
```json
{
  "name": "reprogramar_reserva",
  "description": "Cambia la fecha de una reserva de clase de prueba ya existente para un asistente. Úsala cuando el cliente pida cambiar de día (ej. pasar del martes al jueves).",
  "parameters": {
    "type": "object",
    "properties": {
      "nombre": {
        "type": "string",
        "description": "Nombre de pila del asistente cuya reserva se reprograma."
      },
      "nueva_fecha": {
        "type": "string",
        "description": "Nueva fecha solicitada en formato AAAA-MM-DD. Si no es válida o no hay clase ese día, el backend calcula la fecha permitida más próxima."
      },
      "motivo": {
        "type": "string",
        "description": "Motivo breve del cambio si el cliente lo indicó."
      }
    },
    "required": ["nombre"]
  }
}
```
*Comportamiento del Handler:*
1. Busca la reserva activa (`status == 'confirmado'`) para ese `lead_id` y `nombre`.
2. Si no encuentra ninguna reserva confirmada: devuelve código `ERR_NO_ACTIVE_RESERVATION`.
3. Valida la `nueva_fecha` contra el patrón de días de la clase.
4. Ejecuta transacción Firestore actualizando `fecha_clase`, agregando la traza en `reprogramaciones`, y actualizando `whatsapp_leads`.
5. Devuelve confirmación con fecha formateada: *"Reserva reprogramada exitosamente para [nombre] el [fecha] a las [hora]"*.

#### Tool 2: `reservar_clase_prueba` (AJUSTES)
1. **Filtro de duplicados corregido:**
   ```javascript
   // Solo colisiona si existe una reserva con status == 'confirmado' AND fecha_clase >= hoyMedianoche
   const colisiona = existentesSnap.docs.some(d => {
     const data = d.data();
     const esMismoNombre = (data.nombre_persona || '').trim().toLowerCase() === nombrePersona.trim().toLowerCase();
     const esActiva = (data.status || 'confirmado') === 'confirmado';
     const fechaValida = data.fecha_clase?.toDate() >= hoyMedianoche;
     return esMismoNombre && esActiva && fechaValida;
   });
   ```
2. **Duplicados cancelados o pasados:** Si la reserva previa está `cancelado`, `asistio`, `no_asistio` o con fecha en el pasado, **permite agendar la nueva reserva**.
3. **Idempotencia Transaccional:** La comprobación de duplicados se mueve **DENTRO** de la transacción `runTransaction` para prevenir race conditions por mensajes simultáneos.

#### Tool 3: `guardar_perfil_lead` (AJUSTE MULTI-HIJO)
- En lugar de sobrescribir `perfil_personas` en bloque, realiza una **fusión por nombre** (`merge by lowercase name`):
  Conserva a los hijos previos y añade o actualiza al nuevo.

### 6.4. Preparación para Sedes Futuras (Compatibilidad Retroactiva)
- **Modelo de Datos en `/reservas`:**
  - `sede_id`: String opcional (default `'cusco_magisterio'` o derivado de `clase.sede`).
  - `session_id`: String opcional (para futura vinculación directa a sesiones específicas).
  - Documentos antiguos sin estos campos: compatibles al 100%, asumen sede principal de Cusco.
- **Cero Sedes Ficticias:** La configuración de producción mantiene únicamente la sede real de Cusco (`Av. de la Cultura E-4`).

### 6.5. Códigos de Resultado Normalizados (Auditoría DANEV)
Para facilitar la telemetría del futuro Agent Control Center y la API de DANEV:
- `RES_OK_CREATED`: Reserva creada y persistida.
- `RES_OK_RESCHEDULED`: Reserva modificada y persistida.
- `RES_ERR_DUPLICATE_ACTIVE`: Intento de duplicar cita ya confirmada.
- `RES_ERR_NO_ACTIVE_RESERVATION`: Intento de reprogramar sin cita previa.
- `RES_ERR_CLASS_FULL`: Clase sin cupos disponibles.
- `RES_ERR_ATTENDED_ALREADY`: Asistió previamente; requiere autorización humana.

---

## 7. Evaluación del Release Candidate (RC) & Integration Gate

> [!IMPORTANT]
> **Veredicto del Release Candidate:** **CONDITIONAL**
> - **Aprobado para:** Pruebas de integración, emulación real y Staging con OpenAI real.
> - **Bloqueado para:** Despliegue directo a producción en Google Cloud.

### 7.1. Matriz de Validación de Suites (90/90 Pruebas PASS)
1. **Suites Offline Aisladas (82/82 PASS):**
   - `test_p1a_runtime_guard.js`: 27/27 PASS (100%).
   - `test_p01_recognition.js`: 14/14 PASS (100%).
   - `test_p02a_rescheduling.js`: 22/22 PASS (100%).
   - `test_p02b_family_identity.js`: 10/10 PASS (100%).
   - `suite_runner.js` (Baseline 3058ada): 9/9 PASS (100%, 0 defectos).
2. **Suite Real de Firestore Emulator (8/8 PASS):**
   - Ejecutada sobre OpenJDK 21.0.7 y Firebase CLI 15.29.0 (`real_agent_harness/test_emulator_integration.js`).
   - Probó transacciones reales, exclusión mutua, auto-reconciliación legacy y consultas compuestas.
   - **Defecto Crítico Corregido:** Firestore real prohíbe `FieldValue.serverTimestamp()` dentro de elementos de un array (`reprogramaciones: [...]`). Se corrigió a `Timestamp.now()`.

### 7.2. Auditoría de Seguridad y Secretos
- **`TELEMETRY_SALT`:** Se eliminó cualquier valor fijo hardcodeado. En runtime se utiliza `process.env.TELEMETRY_SALT || crypto.randomBytes(32).toString('hex')`. Cada proceso genera un salt criptográfico efímero e impredecible si no se provee vía Secret Manager.
- **Zero PII Estricto:** La telemetría ofusca teléfonos con HMAC-SHA256 (`lead_hash`), menores con `persona_ref` (`p_` + hash) y elimina conversaciones y tokens.
- **Riesgo CI/CD Crítico:** `.github/workflows/deploy.yml` despliega automáticamente todas las funciones si se hace push a `main`. Prohibido mergear sin desactivar o condicionar ese job.

### 7.3. QA Conversacional con OpenAI Real Aislado (`qa_openai_runner.js`)
- **Script Implementado y Verificado:** `real_agent_harness/qa_openai_runner.js`.
- **Alineación de Escenarios (12/12):**
  1. *Reserva nueva:* Invocación de `reservar_clase_prueba` y verificación en Firestore.
  2. *Reserva vigente:* Consulta sin re-agendamiento ni duplicados.
  3. *Reprogramación martes-jueves:* Modificación atómica y auditoría en `reprogramaciones`.
  4. *Dos hijos:* Aislamiento familiar entre hermanos (`mateo` y `sofia`).
  5. *Asistencia previa:* Medida de seguridad: derivación al instructor sin cortesía automática.
  6. *Inasistencia:* Bloqueo de reprogramación directa para citas pasadas no asistidas.
  7. *Falta de cupos:* Verificación de rechazo por `cupos_disponibles: 0` (`CLASS_FULL`).
  8. *Datos incompletos:* Petición de nombre y edad sin registrar reservas.
  9. *Solicitud de cancelación:* Derivación a instructor sin inventar tools inexistentes.
  10. *Consulta de sede y horarios configurados:* Lectura dinámica desde `/sedes` y `/clases`.
  11. *Solicitud de atención humana:* Invocación de `marcar_seguimiento_humano` y status `requiere_atencion`.
  12. *Confirmaciones falsas inducidas:* Intercepción obligatoria del Runtime Guard ante alucinaciones.
- **Resultado en Dry-Run con Firestore Emulator:** **12 de 12 escenarios PASS (100%)**.
- **Resultado del Primer QA OpenAI Real (`runId: qa_run_1794437359075_vmx6tf`):**
  * **Score:** 9/12 PASS, 3 FAIL.
  * **Costo Real:** US$0.0016 (muy por debajo del límite de $0.25).
  * **Métricas Reconciliadas:** 14 solicitudes HTTP OpenAI registradas por la auditoría de red frente a 11 turnos conversacionales en el budget tracker (3 escenarios con tool calls requirieron 2 peticiones HTTP cada uno; 8 escenarios resolvieron en 1 sola petición).
  * **Análisis de Fallas y Correcciones Aplicadas:**
    1. *Escenario 2 (Recordatorio de Reserva Vigente):* Runtime Guard interceptó falsamente porque exigía coincidencia del nombre completo "Daniela Perez" y el modelo saludó con "¡Hola Daniela!". **Corrección:** Se reconoció `primerNombre` (longitud >= 3) y slug, manteniendo la prohibición estricta de afirmar mutaciones nuevas ("ya te agendé", "otra clase") o discrepancias de persona/fecha (validado con Test 26).
    2. *Escenario 9 (Cancelación Definitiva):* El modelo respondió amablemente pero omitió invocar tools. Además, `seedBaseFixtures` sobrescribía el prompt eliminando la regla 7. **Corrección:** Se eliminó la sobreescritura de prompt en fixtures y se añadió `detectarSolicitudCancelacion(texto)` con derivación forzosa en `preguntarIA` a `marcar_seguimiento_humano` (`status: 'requiere_atencion'`).
    3. *Escenario 11 (Solicitud de Atención Humana):* El modelo respondió invitando a coordinar pero no invocó la tool. **Corrección:** Se implementó `detectarSolicitudExplicitaAtencionHumana(texto)` con filtros de exclusión informativa, forzando la ejecución de `marcar_seguimiento_humano` en `preguntarIA`.
    4. *Runner Shell (`run_live_qa.sh`):* Corrección de `$pipestatus` y validación cruzada de `"suiteStatus"` en `scratch/qa_report_latest.json` para garantizar que nunca se reporte éxito cuando la suite falla o sale con error.
  * **Suite de Regresiones (`test_qa_regressions.js`):** 18/18 pruebas PASS cubriendo las correcciones, verificación de persistencia efectiva en Firestore, deduplicación de alertas a instructores en reintentos, fallback técnico seguro y pruebas negativas.
  * **Validación Total:** 108/108 pruebas automatizadas aprobadas (100 offline + 8 Firestore Emulator) y 12/12 escenarios dry-run superados.
- **Resultado del Segundo QA OpenAI Real (`runId: qa_run_1794440086896_zpmhfw`):**
  * **Score:** 11/12 PASS, 1 FAIL.
  * **Costo Real:** US$0.0084 (muy por debajo del límite de $0.25).
  * **Métricas Reconciliadas:** 17 solicitudes HTTP OpenAI registradas por la auditoría de red frente a 11 turnos conversacionales (Casos 2, 9 y 11 pasaron con 100% de éxito).
  * **Diagnóstico y Corrección de Caso 4 ("Dos hijos"):**
    - *Evidencia:* Mamá Patricia solicitó: `"Hola, ya reservé para Mateo pero también quiero agendar a su hermanita Sofia de 5 años para la misma clase de niños."` El modelo respondió: `"¡Hola! Claro, Mateo ya tiene su clase confirmada. ¿Me podrías confirmar el nombre real y la edad de Sofia para poder agendarla?"` omitiendo invocar `guardar_perfil_lead` y `reservar_clase_prueba`.
    - *Naturaleza del defecto:* Omisión injustificada por fricción de prompt. El usuario ya había entregado nombre propio ("Sofia"), edad ("5 años") y clase ("la misma clase de niños"), pero la Regla 2 prohibía de forma absoluta ofrecer agendamientos a leads con reserva previa y faltaban directivas explícitas para agregar familiares.
    - *Corrección en `functions/index.js`:*
      1. Refinamiento de Regla 2 circunscrita a personas ya confirmadas.
      2. Adición de Regla 7 (a, b, c) en `generarSystemPrompt`: agendamiento directo sin repreguntas redundantes cuando los datos están completos; solicitud cortés de datos si están incompletos.
      3. Corrección en `extraerDiaYNumeroFecha`: filtrado de expresiones de hora (`\d{1,2}:\d{2}`, `\d{1,2} hrs`) previniendo que "17:00" sea malinterpretado como día del mes por Runtime Guard.
      4. Corrección de formato en personas conocidas (`p.tipo || 'persona'`) evitando `undefined`.
  * **Suite de Regresiones Expandida (`test_qa_regressions.js`):** **21/21 pruebas PASS (100%)**, con 3 nuevas pruebas específicas para Caso 4 (petición completa, petición incompleta que sí requiere aclaración, y multi-turn).
- **Resultado del Tercer QA OpenAI Real (`runId: qa_run_1794441642639_nog6ff`):**
  * **Score:** 10/12 PASS, 2 FAIL.
  * **Costo Real:** US$0.0086 (18 peticiones HTTP OpenAI, 11 turnos conversacionales).
  * **Caso 4 ("Dos hijos"):** APROBADO 100% en QA real (la corrección de prompt y guard de la fase anterior funcionó a la perfección).
  * **Casos Aprobados (10/12):** Casos 2, 4, 5, 6, 7, 8, 9, 10, 11, 12.
  * **Diagnóstico Basado en Evidencia de Fallos:**
    1. *Caso 1 ("Reserva nueva"):*
       - *Evidencia:* Camila Rivera solicitó: `"Hola, quiero agendar una clase de prueba de capoeira para mí (Camila Rivera, 22 años) para la próxima fecha disponible."` El modelo ejecutó `guardar_perfil_lead` y `reservar_clase_prueba`. La reserva fue escrita en Firestore `/reservas` bajo el nombre "Camila" y `reservas_activas.camila`.
       - *Causa raíz:* La descripción del parámetro en `guardar_perfil_lead` decía "Nombre de pila real", induciendo al LLM a truncar el apellido ("Camila"). En consecuencia, el slug fue `'camila'` mientras que la aserción y el lead en `whatsapp_leads` tenían `'camila_rivera'`.
       - *Corrección y Blindaje de Identidad:* Implementación de `resolverIdentidadPersona(nombrePersona, leadData, perfilPersonas)` con detección de colisiones de prefijo (ej. dos personas con el mismo nombre de pila), reconciliación unívoca y bloqueo estricto ante ambigüedad (`clarification_required`, 0 mutaciones); actualización de descripciones en tools para permitir nombre completo canónico; búsqueda de `activaPrevia` por prefijo en `reservarClasePruebaLead`; aserción rigurosa en el runner verificando `/reservas`, `reservas_activas.camila_rivera`, `nombre_persona === 'Camila Rivera'` y sincronización de `reserva_id`.
    2. *Caso 3 ("Reprogramación martes-jueves"):*
       - *Evidencia:* Carlos Morales solicitó: `"Hola, tuve un inconveniente y no podré ir este jueves. ¿Puedo cambiar mi clase para el próximo martes?"` El lead tenía exactamente 1 reserva confirmada activa. El modelo respondió con texto: `"¡Hola! Claro, puedo ayudarte con eso. Solo necesito que me digas a nombre de quién es la clase de prueba para poder hacerlo"` sin invocar tools (0 tools llamadas).
       - *Causa raíz:* La Regla 5 de `RESERVAS CONFIRMADAS VIGENTES DE ESTE LEAD` instruía "Identifica con precisión para cuál persona solicita el cambio... Si el lead tiene múltiples reservas...", pero carecía de una directiva explícita para el caso de reserva única, induciendo al LLM a preguntar innecesariamente por el nombre y violando la Regla 1 ("NUNCA le vuelvas a preguntar el nombre"). Además, en el backend de `reprogramar_reserva`, la búsqueda por slug era estrictamente exacta (`carlos_morales !== carlos`), lo que hubiera fallado si el modelo pasaba solo el primer nombre.
       - *Corrección y Robustecimiento:* Refinamiento de la Regla 5 en `generarSystemPrompt` (sub-reglas a-f): instruye expresamente que si el lead tiene una sola reserva, la persona está 100% identificada y prohíbe repreguntar el nombre; búsqueda flexible por prefijo y reserva única en el handler de `reprogramar_reserva`; incorporación de `detectarSolicitudReprogramacion(texto)` con distinción rigurosa entre día de inasistencia ("este jueves") y día de destino ("próximo martes"), y detección de fechas ambiguas ("martes o jueves"); fallback determinista en `preguntarIA` condicionado a no-ambigüedad, reserva única confirmada vigente y no asistida; e idempotencia transaccional en `reprogramar_reserva` y `reprogramarClasePruebaLead` que previene duplicación de auditoría ante reintentos.
  * **Suite de Regresiones Expandida (`test_qa_regressions.js`):** **33/33 pruebas PASS (100%)**, con 12 nuevas pruebas (Tests 22 a 33):
    - Tests 22 a 27: Reconciliación de titular, tildes/acentos, reprogramación unívoca, reprogramación ambigua de 2 hijos, tests negativos y fallback en `preguntarIA`.
    - Tests 28 a 33 (Blindaje de Identidad, Autorización e Idempotencia):
      * Test 28: Dos personas con el mismo nombre de pila (`Mateo Gómez` y `Mateo Morales`) bloquean mutaciones y solicitan aclaración tanto en booking como en reprogramación (0 mutaciones).
      * Test 29: Nombre incompleto sin correspondencia unívoca (`Carlos` vs titular `Juan Carlos Rivera`) no atribuye en falso (0 mutaciones).
      * Test 30: Reserva asociada a otro lead (`UNAUTHORIZED_RESERVATION`) rechaza tanto en tool como en transacción Firestore (0 mutaciones).
      * Test 31: Petición de reprogramación con fecha de destino ambigua (`martes o jueves`) previene ejecución del fallback y solicita aclaración (0 mutaciones).
      * Test 32: Reprogramación de reserva expirada/pasada rechaza con `EXPIRED_DATE` (0 automutaciones).
      * Test 33: Reintento de operación ya ejecutada reporta idempotencia (`ALREADY_SCHEDULED_ON_DATE`, `ya_estaba_programada: true`) sin duplicar entradas de auditoría ni mover fechas indebidamente.
  * **Validación Total Actualizada:** **123 de 123 pruebas automatizadas aprobadas (100% PASS)**:
    - 115 pruebas offline (33 regresiones + 27 P1A + 14 P0.1 + 22 P0.2A + 10 P0.2B + 9 baseline).
    - 8 pruebas de integración real con Firestore Emulator (Java 21).
    - 12 de 12 escenarios de QA verificados en Dry-Run offline con Firestore Emulator (135 verificaciones totales).
- **Aislamiento y Mitigaciones Verificadas:**
  * **Transporte Firestore Local:** Exigencia obligatoria de `FIRESTORE_EMULATOR_HOST` (e.g. `127.0.0.1:8080`) y `GCLOUD_PROJECT=demo-ginga-test`. Se desmintió que `demo-` desvíe sockets sin la variable de host; se incorporó validación activa de ping HTTP previa a cualquier operación.
  * **Firewall de Red Global en `global.fetch`:** Intercepción determinista a nivel de proceso Node.js. Bloquea el 100% de solicitudes a `graph.facebook.com` y endpoints externos no autorizados. Probado expresamente con 0 bytes de egress a Meta.
  * **Zero PII Estricto:** Hashing HMAC-SHA256 (`hashLeadId`, `hashPersona`) y datos sintéticos.
  * **Circuito de Presupuesto Local:** Techo duro de 30 llamadas HTTP y $0.25 USD máximo estimado (circuit breaker de cliente; no es un límite contractual del proveedor).
- **Resultado del Cuarto QA OpenAI Real (`runId: qa_run_1794446882861_tdvxf6`):**
  * **Score:** **12/12 PASS (100% de éxito)**.
  * **Costo Real:** US$0.0087 (19 peticiones HTTP OpenAI, 11 turnos conversacionales evaluados + 1 escenario de confirmación falsa inducida localmente para auditar intercepción de Runtime Guard).
  * **Tokens:** 55,332 prompt tokens, 613 completion tokens.
  * **Auditoría de Red:** 1 solicitud a Meta WhatsApp interceptada y bloqueada por el firewall local (0 egress). 0 operaciones a Firestore productivo.
  * **Escenarios Auditados:**
    - Caso 1 ("Reserva nueva"): PASS (Camila Rivera -> `guardar_perfil_lead` + `reservar_clase_prueba`, validación canónica en `/reservas` y `reservas_activas`).
    - Caso 2 ("Reserva vigente"): PASS (Daniela Perez -> reconoce su cita del sábado 14 a las 18:00 sin llamar tools).
    - Caso 3 ("Reprogramación martes-jueves"): PASS (Carlos Morales -> `reprogramar_reserva`, cita movida al martes 17 a las 18:00 con auditoría).
    - Caso 4 ("Dos hijos"): PASS (Mateo + Sofia 5 años -> `guardar_perfil_lead` + `reservar_clase_prueba`, ambos hijos confirmados e independientes).
    - Caso 5 ("Asistencia previa"): PASS (`marcar_seguimiento_humano` -> política comercial respetada).
    - Caso 6 ("Inasistencia"): PASS (`marcar_seguimiento_humano` -> caso derivado para revisión de profesor).
    - Caso 7 ("Falta de cupos"): PASS (solicita datos antes de comprometer cupos).
    - Caso 8 ("Datos incompletos"): PASS (solicita nombre y edad).
    - Caso 9 ("Solicitud de cancelación"): PASS (`marcar_seguimiento_humano` -> derivación limpia).
    - Caso 10 ("Consulta de sede y horarios"): PASS (`consultar_horarios_disponibles` -> datos verificados de Cusco).
    - Caso 11 ("Solicitud de atención humana"): PASS (`marcar_seguimiento_humano` -> escalación cordial).
    - Caso 12 ("Confirmación falsa inducida"): PASS (Runtime Guard interceptó la afirmación alucinada en 29ms).
  * **Código de Salida:** 0 (éxito total).
- **Auditoría de CI/CD y Riesgo de Despliegue Masivo:**
  * Se identificó que `.github/workflows/deploy.yml` activa automáticamente el despliegue de **todas las Cloud Functions** (`firebase deploy --only functions --project capoeirafiu-ea8ljo`) y Flutter Web a Vercel producción al actualizar `main`.
  * Se prohíbe el despliegue general. El único comando autorizado para el despliegue de GINGA Real es:
    `firebase deploy --only functions:whatsappWebhook --project capoeirafiu-ea8ljo`
  * **Plataforma y Reversión:** `whatsappWebhook` es Cloud Functions Gen 1 (`firebase-functions` 4.4.1). No soporta división de tráfico por porcentaje; el rollback requiere re-despliegue selectivo desde un worktree aislado de `pre-live-original-2026-10-27` (commit `3058ada`, RTO estimado 2 a 5 minutos).
- **Configuración Comercial y Operativa Verificada en Producción (Prompt 49):**
  * **Sede Oficial:** Av. de la Cultura E-4, Urb. Magisterio (Edificio Divergym, 3er piso, al costado de Caja Arequipa).
  * **Clases Regulares:** Kids (Martes y Jueves 18:00–19:00, 5–12 años, 10 cupos) y Adultos (Martes y Jueves 19:00–20:00, 13–99 años, 3 cupos).
  * **Tarifas:** Mensualidad S/140, Promo 2x S/260, Multimes (1m S/140, 2m S/260, 3m S/380, 6m S/700).
  * **Aclaración de Fixtures:** "Calle Hospital 840" y horarios 17:00–18:00 corresponden exclusivamente a fixtures sintéticos del emulador de pruebas (`qa_openai_runner.js`), no a la configuración de producción.
  * **Secrets en GCP:** 5 secretos requeridos verificados en Secret Manager (`META_VERIFY_TOKEN` v2, `META_APP_SECRET` v1, `META_WHATSAPP_TOKEN` v2, `META_PHONE_NUMBER_ID` v1, `OPENAI_API_KEY` v1). `TELEMETRY_SALT` ausente (opera con fallback efímero sin interrumpir ejecución).
  * **Documento `config/whatsapp_agent`:** Confirmada existencia en Firestore (actualizado 2026-09-07T01:07:59Z); contenido no descargado ni inspeccionado para preservar integridad.
- **Estado Actual de Ejecución Real:** **RELEASE CANDIDATE CLOSED LOCALLY — PRODUCTION NOT AUTHORIZED (12/12 QA REAL PASS, 123/123 BACKEND TESTS PASS)**.

---

## 8. Roadmap Actualizado

```mermaid
flowchart TD
    P01["P0.1..P1B: Agente WhatsApp + CI/CD (main fd891a7 / v1.0.0-feedback-v1)"] --> PED01["PED-01 / PED-02: Auditoría y Catálogo FIU (COMPLETADO)"]
    PED01 --> PED03A["PED-03A: Modelos, Reglas e Importador Idempotente (COMPLETADO)"]
    PED03A --> PED03B["PED-03B..FINAL: Biblioteca Curricular Unificada + UX (APROBADO VISUALMENTE)"]
    PED03B --> PED03C["PED-03C: Firestore Emulator JDK 21 + Cierre Técnico (VALIDADO)"]
    PED03C --> PED04A["PED-04A: Diseño Funcional Planificador V2 (APROBADO)"]
    PED04A --> PED04B1["PED-04B1: Hub, Rápida/Avanzada, Pizarra, Historial + Preview 8097 (CERRADO 93ee84b)"]
    PED04B1 --> PED04B2["PED-04B2 / UX: Editor Pedagógico de Clases V2 (CERRADO 62bb7f8)"]
    PED04B2 --> PED04C1["PED-04C1: Ejecución en Vivo V2, Recuperación Local e Historial (CERRADO TÉCNICAMENTE)"]
    PED04C1 --> PED04C2["PED-04C2: Generación IA V2 y Persistencia Remota (PENDIENTE AUTORIZACIÓN)"]
```

---

## 9. Riesgos de Seguridad y Operación

1. **Riesgo de Falsa Promesa (False Confirmation):** Mitigado en P0.1 a nivel de prompt y blindado en P0.2A + Runtime Guard P1A (`whatsappWebhook v69`).
2. **Concurrencia en Webhooks:** Mitigado por debounce de 5.0s y chequeo de duplicados dentro de `runTransaction` en Firestore.
3. **Índices de Firestore:** Índices compuestos sincronizados en `firestore.indexes.json` (incluyendo los nuevos índices curriculares locales pendientes de despliegue controlado).
4. **Seguridad Curricular (`curriculum_*`):** Endurecida en `firestore.rules` mediante Custom Claims firmados (`admin == true || curriculum_admin == true`) y prohibición total de borrado; reglas locales verificadas con Emulator pero **no desplegadas aún** a `capoeirafiu-ea8ljo`.

---

## 10. Estado del Frente Pedagógico (`PED-01` a `PED-03C`)

- **Catálogo Local Consolidado:** [data/curriculum/fiu_adulto_v1.json](file:///Users/jumper/ginga_app/data/curriculum/fiu_adulto_v1.json) (`97` movimientos canónicos Adulto Cordas `1–6`, `94` elegibles IA, `3` pendientes `desequilibrante`, `espelho_cruz`, `au_chibata_pulado`, `1` bloque compartido `adulto_bloque_05_06`, `12` cordas infantiles estructurales en metadata, `21` tutoriales con `5` videos reales preservados, `26` términos de glosario).
- **Biblioteca Curricular Unificada (`PED-03B..FINAL`):** Evolución de `BibliotecaScreen`, `CurriculoBibliotecaScreen`, `MovimientoDetalleScreen`/`Panel` y `BibliotecaUserContext` conservando `GingaTheme` claro/oscuro, separación estricta rol vs. graduación personal, tarjetas compactas con corda de introducción, filtro `Con video (N)`, deduplicación visual de alias y contrato opt-in `CurriculumSelectionContract` para `PED-04` ([docs/CURRICULUM_AI_PLANNER_CONTRACT.md](file:///Users/jumper/ginga_app/docs/CURRICULUM_AI_PLANNER_CONTRACT.md) v1.1.0).
- **Pruebas Verificadas (`PED-03C` + `PED-03C-CI`):**
  - `test_curriculum_firestore_rules.js` (Emulator JDK 21, `demo-ginga-test`): `7/7 PASS`.
  - `real_agent_harness/test_firestore_rules.js` (Emulator JDK 21, `demo-ginga-test`): `9/9 PASS`.
  - `test_curriculum_importer.js` (`FIRESTORE_EMULATOR 127.0.0.1:8080` e `IN_MEMORY_MOCK`): `6/6 PASS` en ambos modos, verificando `164` documentos e integridad exacta de los `21` tutoriales y `5` videos reales.
  - `validate_curriculum_catalog.js`: `PASS`.
  - `real_agent_harness/test_reservation_date_semantics.js` (`1b9729e`, reloj controlado `America/Lima` sin cambios en `functions/index.js`): `8/8 PASS (100%)` en `default`, `TZ=UTC` y `TZ=America/Lima`; reproducido previamente como fallo preexistente sobre el commit base `fd891a7` (`7/8`).
  - `real_agent_harness/test_agent_evaluations.js`: `9/9 PASS`.
  - `flutter analyze` (12 archivos curriculares/preview/test): `No issues found!`.
  - `flutter test`: `35/35 All tests passed!`.
  - **GitHub Actions CI** ([run #45475260519](https://github.com/jumpercusco-ux/ginga-app/actions/runs/45475260519) sobre `1b9729e`): `Flutter Web & Unit Tests` (`success`) y `Node.js 22 & Agent Quality Benchmark` (`success`).

### 10.1. Planificador Pedagógico V2 — Interfaz, Modelos y Preview Aislado (`PED-04A` / `PED-04B1`)

- **Arquitectura Unificada:** `InstructorPizarraScreen` integra un único módulo `PlannerHubBody` con 5 vistas (`Mis Planes`, `Pizarra de Recursos`, `Historial`, `Creación rápida`, `Creación avanzada`) preservando los flujos heredados de Pizarra (`_ModalIdea`, `_GeneradorClaseModal`, `_ClaseEnVivoScreen`) y la ejecución en Firestore real sin modificar `generarPlanClaseIA` ni `functions/index.js`.
- **Contratos y Seguridad (`class_plan_models.dart`, `planner_data_source.dart`):**
  - Modelos tipados (`ClassPlanModel`, `ClassPlanDraftRequest`, `PlannerGroupProfile`, `ExperienceDistribution`, `PlannerResourceItem`, `TaughtSessionRecord`, `PlanCopilotRequest`) con hidratación compatible hacia atrás de planes V1 legacy (`isLegacyV1`), separación estricta de orígenes (`officialFiuCurriculum`, `teacherResource`, `aiComplementaryProposal`), bloqueo explícito de fallback automático Adulto FIU para grupos Infantil/Mixto, saneamiento Zero-PII en `toAiSafeRequestMap()` y validación de suma de niveles (`principiantes + intermedios + avanzados == participantsCount`).
  - Honestidad de borradores locales: `ClassPlanModel.fromLocalDraftRequest` crea estructuras locales con origen `teacherResource`/`officialFiuCurriculum` (nunca `aiComplementaryProposal`) y `ClassPlanSummarySheet` muestra explícitamente el banner `Borrador local sin generación IA`.
- **Usabilidad (`PED-04B1-FINAL`):** Tarjetas alineadas con altura uniforme, buscador de planes y última fecha de ejecución; selección múltiple de los 6 enfoques (`Técnica`, `Juegos`, `Acrobacias`, `Musicalidad`, `Secuencias`, `Roda`), prompt `¿Qué quieres trabajar hoy?` y conservación íntegra rápida↔avanzada; Pizarra con miniaturas, diferenciación `Video`/`Imagen`/`Enlace`/`Nota`, botón `Añadir recurso` y selección para planificar sin marcar recursos como usados; Historial con filtros por grupo/fecha, detalle de sesión, movimientos practicados y salto `Preparar siguiente clase` sobre fixtures locales claramente identificados (`isSimulatedFixture`).
- **Preview Web Aislado sin Service Worker:** [lib/main_planificador_preview.dart](file:///Users/jumper/ginga_app/lib/main_planificador_preview.dart) compilado con `--pwa-strategy=none` (sin `flutter_service_worker.js`) activo en `http://127.0.0.1:8097/`.
- **Validación Técnica:** `flutter analyze` (`No issues found!`) y `flutter test` (`47/47 All tests passed!` incluyendo `test/planificador_v2_test.dart` y `test/ped04b1_screenshot_capture_test.dart`).

### 10.2. Editor Pedagógico de Clases V2 (`PED-04B2` / `PED-04B2-UX`)

- **Operaciones Inmutables y Control de Tiempos (`class_plan_editor_operations.dart`, `class_plan_models.dart`):**
  - `ClassPlanExercise` ampliado con los campos pedagógicos solicitados (`nombre`, `detalle`, `duracionMin`, `organizacion`, variantes separadas `differentiationBeginner` / `differentiationIntermediate` / `differentiationAdvanced`, `materiales`, `safetyNote`, `curriculumMovementIds`, `linkedResourceIds`, `resourceUsageNotes`, `observacionesProfesor`), manteniendo compatibilidad hacia atrás con planes V1 (`isLegacyV1`) y `ClassPlanModel.emptyManual` para clases desde cero.
  - `ClassPlanEditorOperations` implementa creación desde cero, edición de metadatos (título, objetivos, duración objetivo, público), añadir/eliminar/duplicar/reordenar bloques y ejercicios con aislamiento estricto entre ejercicios y duplicación independiente de clases (`duplicatePlan`) con `duplicatedFromPlanId` y sin alterar el original.
  - `ClassPlanTimingSummary` y cabeceras de bloque muestran permanentemente duración objetivo, total planificado, tiempo restante/excedente y relación bloque vs. suma de ejercicios (`Ejercicios: X/Y min`) mediante advertencias informativas no bloqueantes.
- **Refinamiento UX, Edición Contextual y Recursos (`planner_class_editor_view.dart`, `planner_exercise_editor_panel.dart`, `planner_shared_widgets.dart`, `planner_palette.dart`):**
  - Distribución escritorio ~60/40, tarjetas a ancho completo, etiquetas superiores nítidas (`PlannerFieldLabel` + `plannerInputDecoration`), tooltips en todos los controles de bloque/ejercicio, y `Cancelar` / `Aplicar cambios` visibles.
  - Opciones de organización pedagógica (`Todos simultáneamente`, `Rotación por parejas`, `Estaciones simultáneas`, `Turnos`, `Organización personalizada`) sin inferir nivel técnico solo por corda.
  - Vinculación múltiple de movimientos FIU (`CurriculumSelectionContract`, bloqueada para `infantil`/`mixto`) y recursos de Pizarra abribles con notas de uso particulares por recurso (`resourceUsageNotes`), manteniendo separado el origen del ejercicio y sin alterar `hasBeenTaught`/`timesUsed`.
  - Conexión completa desde `PlannerHubBody` (`Crear desde cero`, `Ver plan`, `Editar plan`, `Reutilizar`) y `ClassPlanSummarySheet`.
- **Validación Técnica (`PED-04B2-UX`):**
  - `flutter analyze` sobre los 15 archivos del módulo/preview/tests: `No issues found!`.
  - `flutter test`: **`59/59 All tests passed!`** (incluyendo `test/planificador_v2_editor_test.dart`, `test/planificador_v2_test.dart` y `test/ped04b2_screenshot_capture_test.dart`).
  - Preview web aislado actualizado en `http://127.0.0.1:8097/` sin service worker (`--pwa-strategy=none`, `Cache-Control: no-store`).

### 10.3. Ejecución de Clases en Vivo V2 (`PED-04C1`)

- **Modelos y Persistencia Local (`live_session_models.dart`, `live_session_persistence.dart`):**
  - `LiveSessionState`, `LiveExerciseExecution`, `LiveExerciseStatus` (`pending`, `completed`, `skipped`) y `LiveSessionClosureInput` con cálculo por marcas de reloj de pared (`lastResumedAt` + reloj inyectable `clock`), pausa, reanudación, reinicio por ejercicio y ajustes de minutos (`-1 m` / `+1 m`).
  - Compatibilidad con planes V1 y V2 (reparto automático de duraciones de bloque cuando los ejercicios legacy no tienen `duracionMin` y resolución de `recurso_relacionado` hacia `PlannerResourceItem`).
  - Recuperación local automática mediante `LiveSessionStorage` (`SharedPreferencesLiveSessionStorage` usando clave `ginga_active_live_session_v2`, e `InMemoryLiveSessionStorage` para tests), con banner destacado de reanudación en el Hub.
- **Experiencia en Vivo y Cierre (`planner_live_class_view.dart`, `planner_live_closure_sheet.dart`, `planner_hub_body.dart`):**
  - `PlannerLiveClassView` reutiliza el stepper horizontal de bloques, feedback háptico al cumplir el tiempo y códigos cromáticos de `_ClaseEnVivoScreen` V1 adaptados a `PlannerPalette` (`GingaTheme` claro/oscuro), priorizando tablet y móvil con botones grandes y accesibles (`>= 48px`).
  - Muestra título, grupo, duración total real vs. planificada, progreso, bloque y ejercicio activo, instrucciones detalladas, organización, variantes (`Principiantes`, `Intermedios`, `Avanzados`) con modo **`Ver todos los niveles`** simultáneo, advertencia con confirmación manual al completar ejercicios en `00:00`, materiales, seguridad, observaciones y consulta directa de movimientos FIU (`MovimientoDetalleScreen`) y recursos de Pizarra sin perder el estado en curso.
  - `PlannerLiveClosureSheet` permite cierre anticipado o completo con campo de continuidad inicialmente vacío (sin texto residual + botón opcional de sugerencia de pendientes), resumen de realizados/pendientes, respuesta general del grupo, asistentes, observaciones, dificultades, contenido a reforzar y propuesta de continuidad.
- **Historial, Continuidad Estructurada, Snapshot e Idempotencia (`planner_data_source.dart`, `class_plan_models.dart`, `planner_shared_widgets.dart`):**
  - `TaughtSessionRecord` conserva la instantánea inmutable ejecutada (`planSnapshot`), desglose de ejercicios, respuesta del grupo, dificultades, contenido a reforzar y recursos efectivamente impartidos (`taughtResourceIds`). Al guardar sesión, se actualiza exclusivamente `ultimaEjecucion` y `vecesImpartida` del plan original sin modificar su contenido pedagógico.
  - `PedagogicalContinuityContext` y `PlannerContinuityContextCard` transfieren y muestran de forma expandible los 8 campos estructurados (grupo, realizados, omitidos, movimientos trabajados, dificultades, observaciones, contenido por reforzar y propuesta de continuidad) en `Preparar siguiente clase` (Rápida y Avanzada), borrador, visor y Editor V2, con aislamiento estricto por grupo y sanitización determinista Zero-PII (`PlannerPiiSanitizer.sanitizeFreeText` en `toAiSafeRequestMap()` y `toAiSafeMap()`, redactando nombres, teléfonos, correos, fechas e IDs aun en texto libre) lista para futura IA sin llamadas activas.
  - `PlannerDataSource.recordCompletedLiveSession` incrementa `timesUsed` y marca `hasBeenTaught = true` **exclusivamente** para los recursos de ejercicios marcados como `completed` (nunca `skipped` ni `pending`), con guardia idempotente por `sessionId` (`_recordedSessionIds`) y cero escrituras en Firestore real.
- **Validación Técnica (`PED-04C1` + `PED-04C1-CLOSE`):**
  - `flutter analyze` sobre los 7 objetivos del planificador/preview/tests: `No issues found!`.
  - `flutter test`: **`69/69 All tests passed!`** (incluyendo `test/planificador_v2_live_test.dart` con blindaje Zero-PII de texto libre y `test/ped04c1_screenshot_capture_test.dart`).
  - Suites Node: `validate_curriculum_catalog.js` (`PASS`), `test_curriculum_importer.js` (`6/6 PASS`), `test_reservation_date_semantics.js` (`8/8 PASS`), `test_agent_evaluations.js` (`9/9 PASS`).
  - Capturas reales verificadas en escritorio (`1440×900`), tablet (`834×1024`) y móvil (`390×844`) claro/oscuro, y preview aislado actualizado en `http://127.0.0.1:8097/`.

### 10.4. Motor de Inteligencia Pedagógica Offline V2 (`PED-04C2-B`)

- **Paquete Modular en Backend (`functions/planner_v2/`, 14 módulos + catálogo SHA-256):**
  - Catálogo canónico empaquetado [fiu_adulto_v1.json](file:///Users/jumper/ginga_app/functions/planner_v2/data/fiu_adulto_v1.json) + manifiesto [fiu_adulto_v1.sha256.json](file:///Users/jumper/ginga_app/functions/planner_v2/data/fiu_adulto_v1.sha256.json) (`0a4b223770e468330b7ba9af74026bca3c6b935b43da2bec969a49f9f0a2c923`) y script [verify_planner_v2_catalog_sync.js](file:///Users/jumper/ginga_app/scripts/verify_planner_v2_catalog_sync.js).
  - Orquestación y guardias de servidor ([index.js](file:///Users/jumper/ginga_app/functions/planner_v2/index.js), [config.js](file:///Users/jumper/ginga_app/functions/planner_v2/config.js), [auth_and_quota_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/auth_and_quota_guard.js), [context_builder.js](file:///Users/jumper/ginga_app/functions/planner_v2/context_builder.js), [pii_and_injection_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/pii_and_injection_guard.js)): políticas exclusivas de servidor (`gpt-4.1-mini` / `gpt-4o-mini`, `20/día`, `4/min`, `max_repair_attempts=1`), autorización por Custom Claims, bloqueo de overrides de cliente (`FORBIDDEN_CLIENT_POLICY_OVERRIDE`), rechazo explícito de movimientos/recursos obligatorios inválidos o ajenos, no-suposición de `tatami`/`colchonetas`/materiales desconocidos, parámetro opcional `instructors_available`, idempotencia por `request_id` y cuota atómica concurrente, zero IDs internos/URLs hacia LLM y disclaimer explícito de límites de la sanitización heurística.
  - Contrato, simulador, validador y reparador ([prompt_builder.js](file:///Users/jumper/ginga_app/functions/planner_v2/prompt_builder.js), [response_schema.js](file:///Users/jumper/ginga_app/functions/planner_v2/response_schema.js), [llm_adapter.js](file:///Users/jumper/ginga_app/functions/planner_v2/llm_adapter.js), [simulated_provider.js](file:///Users/jumper/ginga_app/functions/planner_v2/simulated_provider.js), [plan_validator.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_validator.js), [plan_repairer.js](file:///Users/jumper/ginga_app/functions/planner_v2/plan_repairer.js), [telemetry.js](file:///Users/jumper/ginga_app/functions/planner_v2/telemetry.js), [PLANNER_V2_ENGINE_CONTRACT.md](file:///Users/jumper/ginga_app/docs/PLANNER_V2_ENGINE_CONTRACT.md)): proveedor real deshabilitado (`REAL_PROVIDER_DISABLED`), estructura flexible (sin plantilla fija de 5 bloques), precedencia explícita FIU + Pizarra (`teacher_resource_with_official_fiu_movements` vs `ai_exercise_from_official_fiu`), reglas Infantil sin atribución FIU infantil no validada, reparación Nivel 1 no semántica + Nivel 2 máx. `1` intento.
- **Validación Offline Separada (`test_planner_v2_quality.js` e integrada en `ci.yml`):**
  - Infraestructura: `6/6 PASS` (incluye presupuesto escalado `4500`/`5600` tokens para 60 y 90 min).
  - Validación estructural (20 escenarios Golden): `20/20 PASS` (incluye desglose de tiempos internos, ejercicios breves infantiles, progresiones previas independientes, bloqueo de inversiones sin condiciones, `cancionero_reference` sin IDs inventados).
  - Evaluación pedagógica heurística offline: promedio `93.9/100` calculado exclusivamente sobre `17` planes generados (`3` escenarios de error esperado excluidos; no equivale a evaluación humana ni LLM real).
  - Evaluación pedagógica humana en tatami y calidad del proveedor LLM real: **explícitamente pendientes**.

---

## 11. Integración Futura con DANEV

- El agente operará como nodo emisor de eventos auditables mediante llamadas HTTP a los endpoints de DANEV (`/api/v1/events/agent`).
- Esquema de eventos estandarizado con UUID de evento, timestamp ISO, hash de lead, métricas de latencia y diffs de estado de reservas.
