# PED-05 — Persistencia Firestore, Ciclo de Vida y Continuidad Multidispositivo

## 1. Arquitectura de Colecciones (Reutilización sin duplicar sistemas)

| Colección | Uso | Propiedad e Inmutabilidad |
|---|---|---|
| `instructor_planes_clase/{planId}` | Planes y borradores V1/V2 (`bloques`, `ejercicios`, `tiempos_internos`, variantes por nivel, metadatos de generación y `last_copilot_summary`). | Propiedad del instructor (`instructor_id`), concurrencia optimista mediante `revision` entero monotónico y `plan_status` explícito. |
| `instructor_ideas/{ideaId}` | Recursos de Pizarra creados por el profesor. | Propiedad (`instructor_id`) y bandera `shared`. Los contadores (`completado`, `veces_impartida`, `clase_usada`) solo suben al finalizar una clase real. |
| `instructor_sesiones_activas/active_{uid}` | Estado de ejecución en vivo multidispositivo (`LiveSessionState`, marcas temporales `started_at`, `last_resumed_at`, `accumulated_session_elapsed_sec`, `active_exercise_index`). | Propiedad estricta `instructor_id == auth.uid`. Se elimina en la transacción de cierre al finalizar la sesión. |
| `instructor_sesiones_impartidas/{sessionId}` | Historial inmutable de sesiones impartidas, con `plan_snapshot` completo, ejercicios completados/omitidos/pendientes, `taught_resource_ids` y notas de continuidad. | `allow update, delete: if false;` en `firestore.rules`. Nunca se modifica retroactivamente aunque se edite el plan original después. |
| `clases`, `users`, `asistencias`, `sesiones`, `tutoriales`, `curriculum_*` | Colecciones preexistentes intactas. | `sesiones` (QR de asistencia) permanece separada del Planificador. |
| `planner_v2_quotas`, `planner_ai_*`, `planner_copilot_*` | Cuotas e idempotencia transaccional del servidor IA. | `allow read, write: if false;` para clientes. |

---

## 2. Ciclo de Vida de una Clase (`ClassPlanStatus`)

```
draft (Borrador) ──▶ saved (Planificada) ──▶ in_progress (En ejecución) ──▶ completed (Finalizada)
   ▲                      │                          │                            │
   └──────────────────────┴──────────────────────────┴────────────────────────────┘
                          │                                                       │
                          └──────────────────────▶ archived (Archivada) ◀─────────┘
```

- Validar transiciones mediante `ClassPlanStatus.canTransitionTo(next)`.
- Guardar o editar borradores **nunca** marca recursos Pizarra como impartidos ni altera el historial ya cerrado.
- Al finalizar una clase en vivo, `FirestorePlannerDataSource.recordCompletedLiveSession` ejecuta una **transacción atómica idempotente**:
  1. Verifica que `instructor_sesiones_impartidas/{sessionId}` no exista (si existe, retorna `false` sin volver a incrementar).
  2. Crea el registro histórico inmutable con `plan_snapshot`.
  3. Actualiza únicamente `veces_impartida`, `ultima_ejecucion`, `plan_status: 'completed'` y `revision` del plan (sin alterar sus bloques ni ejercicios).
  4. Incrementa `veces_impartida` y marca `completado: true` exclusivamente sobre los `taughtResourceIds` completados en la sesión.

---

## 3. Continuidad Multidispositivo y Concurrencia Optimista

1. **Edición entre PC, tablet y celular**:
   - Cada guardado pasa `expectedRevision` a `runTransaction`.
   - Si otro dispositivo ya incrementó `revision` en Firestore, el cliente recibe `PlannerConcurrencyConflictException` y la UI abre el diálogo de resolución:
     - **Cargar versión más reciente**: descarta la edición local obsoleta cargando la revisión remota.
     - **Guardar como copia independiente**: genera nuevo `planId` (`revision: 1`) conservando ambos trabajos sin sobrescrituras silenciosas.
2. **Ejecución en vivo entre dispositivos**:
   - `FirestoreLiveSessionStorage` guarda siempre en caché local (`SharedPreferences`) primero y sincroniza contra `instructor_sesiones_activas/active_{uid}`.
   - Al recuperar en otro dispositivo, `effectiveTotalElapsedSec(now)` recalcula el tiempo exacto usando `started_at`, `last_resumed_at` y `accumulated_session_elapsed_sec`.
3. **Honestidad sin conexión**:
   - Si Firestore falla o no hay red, el editor mantiene el borrador abierto en pantalla (`PlannerSyncState.pendingOffline`), nunca miente "Sincronizado" y ofrece **Reintentar**.

---

## 4. Continuidad Pedagógica Real por Grupo (`Zero-PII`)

- `PedagogicalContinuityContext.fromGroupHistory` filtra `instructor_sesiones_impartidas` estrictamente por `clase_id` (o nombre normalizado + `audienceType` igual), tomando hasta las últimas **3 sesiones** de ese grupo sin mezclar Infantil, Mixto y Adultos.
- Este contexto alimenta tanto la Creación Rápida/Avanzada (`continuity_context` en el Generador V2) como al Copiloto Pedagógico (`continuity_context` en el cliente y `group_continuity` sanitizado en `functions/planner_v2/copilot_context_and_prompt.js`).

---

## 5. Migración Idempotente (`--dry-run` y Rollback)

Ejecución segura exclusivamente contra Firebase Emulator:

```bash
# Vista previa sin escrituras
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/migrate_planner_v2_firestore.js --dry-run --default-instructor-uid=prof_1

# Aplicación idempotente en emulador
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/migrate_planner_v2_firestore.js --apply --default-instructor-uid=prof_1
```

- **Compatibilidad hacia atrás**: solo rellena metadatos faltantes (`schema_version`, `plan_status`, `revision`, `instructor_id`, `shared`) dejando intactos `bloques`, `titulo`, `url`, `notas`, `veces_impartida` y `ultima_ejecucion`.
- **Rollback**: ante un fallo en un entorno futuro autorizado, remover únicamente los campos añadidos (`migrated_metadata_at`, `schema_version`, `plan_status`, `revision`) sin borrar documentos; los modelos V1 y V2 toleran su ausencia.

---

## 6. Bloqueadores P0 de Seguridad Preexistentes (Abiertos antes de Producción)

Aunque PED-05 endurece `instructor_planes_clase`, `instructor_ideas`, `instructor_sesiones_activas`, `instructor_sesiones_impartidas` y colecciones de cuotas IA en `firestore.rules`, permanecen **abiertos** en producción los bloqueadores P0 históricos del repositorio (fuera de alcance PED-05, pendientes antes de abrir escritura pública):
1. `users/{userId}` aún permite `allow read, write: if request.auth != null` (permite auto-elevación del campo mutable `users/{uid}.rol` si no se migran todos los módulos a Custom Claims firmados).
2. Colecciones legacy (`pedidos`, `asistencias`, `reservas`, `sesiones`, `whatsapp_leads`, `cantigas`, `eventos`) mantienen `if request.auth != null`.
3. Preview Web de Vercel continúa apuntando al proyecto Firebase `capoeirafiu-ea8ljo` mientras no se configure un proyecto separado `ginga-staging`.
