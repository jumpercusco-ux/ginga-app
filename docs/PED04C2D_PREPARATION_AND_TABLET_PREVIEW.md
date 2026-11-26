# Preparación Segura de `PED-04C2-D` y Acceso Controlado desde Tablet

---

## 1. Mecanismo Seguro para Habilitar el Proveedor Real OpenAI en `PED-04C2-D`

**Regla invariante:** Ninguna clave de OpenAI ni credencial de API se incluirá jamás en el cliente Flutter, compilación web o navegador.

### Arquitectura de habilitación controlada
1. **Exportación en Cloud Functions Gen 1 (aislada de `whatsappWebhook` y `generarPlanClaseIA`):**
   - Exponer una función dedicada `exports.generarPlanClaseV2` en [functions/index.js](file:///Users/jumper/ginga_app/functions/index.js) con `secrets: ['OPENAI_API_KEY']`, `timeoutSeconds: 60`, `memory: '512MB'`.
   - Configurar en entorno de servidor (nunca desde el cliente):
     - `PLANNER_V2_REAL_PROVIDER=true` (solo en el entorno autorizado; apagado por defecto en desarrollo).
     - `PLANNER_V2_MODEL=gpt-4.1-mini` (primario) y `PLANNER_V2_FALLBACK_MODEL=gpt-4o-mini` (alternativa).
2. **Cliente Flutter (`FirebaseFunctionsPlannerV2Client` a implementar en `PED-04C2-D`):**
   - En producción, implementar una segunda subclase de `PlannerV2EngineClient` que invoque `FirebaseFunctions.instance.httpsCallable('generarPlanClaseV2')` enviando únicamente `request.toPlannerV2RequestMap(requestId: ...)`.
   - El servidor ignora o rechaza (`FORBIDDEN_CLIENT_POLICY_OVERRIDE`) cualquier parámetro de proveedor, modelo, cuota o reparación enviado desde el cliente.

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
