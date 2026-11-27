# Preparación Segura de `PED-04C2-D` y Acceso Controlado desde Tablet

---

## 1. Mecanismo Seguro para Habilitar el Proveedor Real OpenAI en `PED-04C2-D`

**Regla invariante:** Ninguna clave de OpenAI ni credencial de API se incluirá jamás en el cliente Flutter, compilación web o navegador.

### A. Habilitación real aislada exclusivamente en servidor local de desarrollo (`PED-04C2-D`)
1. El servidor local [scripts/planner_v2_local_server.js](file:///Users/jumper/ginga_app/scripts/planner_v2_local_server.js) **arranca deshabilitado por defecto** (`mode=simulated_offline`, `real_provider_enabled=false`).
2. Para habilitar el proveedor real (`gpt-4.1-mini`) únicamente tras autorización del propietario:
   - Exportar la clave únicamente en esa sesión de terminal local (sin escribirla en `.env` versionado ni código):
     `export PLANNER_V2_OPENAI_API_KEY="<TU_CLAVE_DEV>"` (o `OPENAI_API_KEY`).
   - Iniciar el servidor local con `--enable-real-openai` y tope presupuestal estricto (`--budget-usd 0.10 --max-real-generations 4`):
     ```bash
     node scripts/planner_v2_local_server.js \
       --static-dir /tmp/ginga_ped04c2c_8097 \
       --port 8097 \
       --enable-real-openai \
       --budget-usd 0.10 \
       --max-real-generations 4
     ```
   - Incluso con `--enable-real-openai`, el botón discreto `Cambiar a simulado` en la UI (y `force_simulated: true` fuera de `request`) mantiene disponible el modo simulado offline sin costo.
3. Para ejecutar el piloto automatizado de 4 generaciones (`USD 0.10` máximo acumulado):
   - Primero validar en seco (`0` llamadas pagadas):
     `node scripts/run_planner_v2_real_pilot.js --dry-run`
   - Solo tras autorización explícita, ejecutar:
     `PLANNER_V2_ALLOW_PAID_PILOT=YES PLANNER_V2_OPENAI_API_KEY="<TU_CLAVE_DEV>" node scripts/run_planner_v2_real_pilot.js --authorize-paid-pilot`

### B. Contrato preparado para futura Cloud Function en producción (no desplegada aún)
1. Contrato callable implementado y probado en Firebase Emulator (`demo-ginga-test`): [callable_handler.js](file:///Users/jumper/ginga_app/functions/planner_v2/callable_handler.js) + `FirestoreTransactionQuotaStore` en [auth_and_quota_guard.js](file:///Users/jumper/ginga_app/functions/planner_v2/auth_and_quota_guard.js) + `FirebaseFunctionsPlannerV2Client` en [planner_v2_engine_client.dart](file:///Users/jumper/ginga_app/lib/features/instructor/planificador/services/planner_v2_engine_client.dart).
2. `functions/index.js`, `firestore.rules`, cuentas productivas y `generarPlanClaseIA` V1 permanecen intactos hasta aprobación de despliegue.

---

## 2. Requisitos Pendientes para `PED-04C2-D` antes de Producción

| Requisito | Estado Actual (`PED-04C2-C`) | Trabajo requerido en `PED-04C2-D` |
|---|---|---|
| **Cuota distribuida atómica** | Validada en memoria vía `InMemoryAtomicQuotaStore` | Implementar `FirestoreTransactionQuotaStore.acquireSlot` con `runTransaction` sobre `planner_ai_usage/{uid_dayBucket}` + `planner_ai_requests/{requestIdHash}` para atomicidad real entre múltiples instancias Cloud Functions (`20/día`, `4/min`, idempotencia). |
| **Custom Claims firmados** | `auth_and_quota_guard.js` exige `instructor === true` (o `teacher`/`admin`) en JWT | Ejecutar script administrativo único asignando Custom Claims firmados (`instructor: true`) a las cuentas reales de profesores autorizados (sin confiar en `users/{uid}.rol` editable). |
| **Persistencia Firebase de planes y sesiones V2** | Local en memoria / `SharedPreferences` (0 escrituras en producción) | Definir reglas en `firestore.rules` (solo propietario instructor con Custom Claim, validación de esquema, cero PII en campos enviados a IA) e implementar guardado remoto en `FirestorePlannerDataSource` con pruebas en Firebase Emulator JDK 21. |
| **Presupuesto OpenAI y límite de gasto** | Tope de tokens por duración (`4500`/`5600`) y 1 pase máx. de reparación | Configurar límite mensual duro de gasto en OpenAI Platform (`Usage Limits`) y validar piloto controlado de 4 planes reales (<`\$0.05 USD` total) con evaluación pedagógica humana en tatami. |

---

## 3. Acceso desde Tablet mediante Red Local Restringida (Preview Aislado)

Para probar el preview `PED-04C2-C` desde una tablet iOS/Android conectada a la misma red Wi-Fi privada, **sin exponer el puerto públicamente en Internet** ni conectarse a Firebase de producción:

1. El servidor [scripts/planner_v2_local_server.js](file:///Users/jumper/ginga_app/scripts/planner_v2_local_server.js) enlaza por defecto únicamente a `127.0.0.1:8097`. Si se pasa una IP LAN en `--host`, **rechaza arrancar si no se incluye `--token <PIN>`**.
2. Obtener la IP local de la Mac (ejemplo `192.168.1.45` vía Wi-Fi):
   ```bash
   ipconfig getifaddr en0
   ```
3. Iniciar el servidor en LAN restringida con token temporal mínimo de 4 caracteres y firewall activo en macOS:
   ```bash
   node scripts/planner_v2_local_server.js \
     --static-dir /tmp/ginga_ped04c2c_8097 \
     --host 192.168.1.45 \
     --port 8097 \
     --token <PIN_TEMPORAL>
   ```
4. Abrir en el navegador de la tablet **exactamente**:
   `http://192.168.1.45:8097/?token=<PIN_TEMPORAL>`
   - Todas las peticiones `/api/planner-v2/*` y de recursos sin `?token=` o cabecera `X-Preview-Token` válido reciben `401 PREVIEW_TOKEN_REQUIRED`.
   - No abrir puertos en el router (`port-forwarding`), no usar túneles públicos ni ngrok, y detener el proceso al finalizar la prueba.
