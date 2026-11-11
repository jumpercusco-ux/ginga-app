# GINGA Real Agent — Entorno de Pruebas Aislado (Harness 3058ada)

Entorno de ejecución y auditoría local para el agente de WhatsApp de GINGA, basado exactamente en el commit `3058ada` (código activo en Google Cloud Functions `whatsappWebhook v67`).

## 1. Principio de Aislamiento y Ejecución
- **Código Real Ejecutado:** `functions/index.js` se lee directamente desde disco y se ejecuta en memoria vía Node.js `vm.compileFunction`. No se modifica ningún archivo productivo (`git diff` es 0).
- **Adaptadores Inyectados:**
  - `in_memory_firestore.js`: Emula completamente colecciones, queries compuestas, transacciones y batches de Firestore.
  - `openai_adapter.js`: Intercepta llamadas a `https://api.openai.com/v1/chat/completions` simulando respuestas de forma determinista y offline, y detectando alucinaciones/promesas falsas.
  - `whatsapp_adapter.js`: Intercepta llamadas salientes a Meta Graph API.
- **Sin Dependencias Externas:** 100% offline, sin costos de API, sin acceso a datos reales ni secretos.

## 2. Cómo Levantar el Servidor y la Interfaz Web
Para iniciar la interfaz interactiva en `http://127.0.0.1:3333`:
```bash
node real_agent_harness/server.js
```
La interfaz permite:
1. Enviar mensajes interactivos como cliente de WhatsApp.
2. Ver en vivo la tarjeta de herramientas reales ejecutadas (`consultar_horarios_disponibles`, `guardar_perfil_lead`, `reservar_clase_prueba`, `marcar_seguimiento_humano`).
3. Inspeccionar el `System Prompt` generado para ese turno exacto.
4. Explorar el estado en vivo de las colecciones `/reservas` y `/whatsapp_leads`.
5. Ejecutar la suite automatizada de 9 casos con un solo clic.

## 3. Cómo Ejecutar la Suite de Pruebas por Consola (CLI)
Para ejecutar la suite automatizada de auditoría:
```bash
node real_agent_harness/suite_runner.js
```

## 4. Matriz de Validación de los 9 Escenarios

| Escenario | Lógica Real Evaluada | Componente Simulado | Resultado Baseline |
|---|---|---|---|
| **Caso 1: Consulta de Horarios** | Lectura real de `/clases` y `/config/negocio` en `consultar_horarios_disponibles` | OpenAI mock devuelve llamada a tool | **OK** |
| **Caso 2: Reserva Vigente (Amnesia)** | Generación real del prompt en `generarSystemPrompt` (demuestra que no consulta `/reservas`) | Simulación de mensaje entrante | **DEFECTO BASELINE** |
| **Caso 3: Reserva Cancelada** | Validación real de duplicados en `reservar_clase_prueba` (demuestra que no filtra `status`) | Firestore in-memory con doc cancelado | **DEFECTO BASELINE** |
| **Caso 4: Reserva Pasada** | Validación real de duplicados en `reservar_clase_prueba` (demuestra que no evalúa `fecha_clase`) | Firestore in-memory con fecha vencida | **DEFECTO BASELINE** |
| **Caso 5: Dos Hijos (Mateo y Lucía)** | Transacción real en `reservarClasePruebaLead` y sobreescritura escalar en `whatsapp_leads` | Simulación de doble tool call | **DEFECTO BASELINE** |
| **Caso 6: Reprogramación Martes→Jueves** | Comprobación de que no existe `reprogramar_reserva` y colisión en `reservar_clase_prueba` | Simulación de solicitud de cambio | **DEFECTO BASELINE** |
| **Caso 7: Estado Documental Antes/Después** | Comprobación de que `fecha_clase` en el documento `/reservas` permanece inalterado | Inspección directa de Firestore | **DEFECTO BASELINE** |
| **Caso 8: Falsa Confirmación Textual** | Detector de discrepancia: respuesta afirmativa de la IA vs. base de datos inalterada | Responder mock simula alucinación del LLM | **DEFECTO BASELINE** |
| **Caso 9: Solicitar Humano** | Handler real de `marcar_seguimiento_humano`, actualización de lead y notificación | OpenAI mock devuelve tool call | **OK** |
