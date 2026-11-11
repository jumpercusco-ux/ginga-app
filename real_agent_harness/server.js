/**
 * Real Agent Local Test Server
 * Serves the interactive visual web interface on port 3333.
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { RealAgentHarness } = require('./loader');
const { runBaselineTestSuite } = require('./suite_runner');
const { MockTimestamp } = require('./in_memory_firestore');

const PORT = 3333;
const harness = new RealAgentHarness();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Serve static UI
  if (url.pathname === '/' || url.pathname === '/index.html') {
    const html = fs.readFileSync(path.join(__dirname, 'public/index.html'), 'utf8');
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
    return;
  }

  // API: Get current DB state
  if (url.pathname === '/api/state' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(harness.firestore.dump()));
    return;
  }

  // API: Reset DB to clean baseline
  if (url.pathname === '/api/reset' && req.method === 'POST') {
    harness.reset();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, message: 'Database reset to factory baseline.' }));
    return;
  }

  // API: Setup scenario fixture
  if (url.pathname === '/api/setup-scenario' && req.method === 'POST') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', async () => {
      try {
        const { scenario, leadId } = JSON.parse(body || '{}');

        if (scenario === 'vigente') {
          await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
            telefono: leadId,
            nombre: 'Carlos',
            status: 'reservado',
            perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
            reserva_id: 'reserva_val_1',
            clase_reservada_id: 'clase_ninos_regular',
            fecha_clase_reservada: MockTimestamp.fromDate(new Date('2026-11-19T18:00:00')),
            ai_habilitada: true,
          });
          await harness.firestore.collection('reservas').doc('reserva_val_1').set({
            lead_id: leadId,
            clase_id: 'clase_ninos_regular',
            nombre_persona: 'Valentina',
            nivel: 'Iniciación Infantil',
            hora: '18:00',
            dias: 'M, J',
            fecha_clase: MockTimestamp.fromDate(new Date('2026-11-19T18:00:00')),
            status: 'confirmado',
            tipo: 'prueba',
            origen: 'whatsapp',
          });
        } else if (scenario === 'cancelada') {
          await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
            telefono: leadId,
            nombre: 'Mariana',
            status: 'perdido',
            perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
            ai_habilitada: true,
          });
          await harness.firestore.collection('reservas').doc('reserva_canc_1').set({
            lead_id: leadId,
            clase_id: 'clase_ninos_regular',
            nombre_persona: 'Valentina',
            nivel: 'Iniciación Infantil',
            hora: '18:00',
            dias: 'M, J',
            fecha_clase: MockTimestamp.fromDate(new Date('2026-11-05T18:00:00')),
            status: 'cancelado',
            tipo: 'prueba',
            origen: 'whatsapp',
          });
        } else if (scenario === 'pasada') {
          await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
            telefono: leadId,
            nombre: 'Pedro',
            status: 'asistio',
            perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
            ai_habilitada: true,
          });
          await harness.firestore.collection('reservas').doc('reserva_pasada_1').set({
            lead_id: leadId,
            clase_id: 'clase_ninos_regular',
            nombre_persona: 'Valentina',
            nivel: 'Iniciación Infantil',
            hora: '18:00',
            dias: 'M, J',
            fecha_clase: MockTimestamp.fromDate(new Date('2026-10-20T18:00:00')),
            status: 'confirmado',
            tipo: 'prueba',
            origen: 'whatsapp',
          });
        } else if (scenario === 'reprogramar') {
          await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
            telefono: leadId,
            nombre: 'Valeria',
            status: 'reservado',
            perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
            reserva_id: 'res_martes_01',
            clase_reservada_id: 'clase_ninos_regular',
            fecha_clase_reservada: MockTimestamp.fromDate(new Date('2026-11-17T18:00:00')),
            ai_habilitada: true,
          });
          await harness.firestore.collection('reservas').doc('res_martes_01').set({
            lead_id: leadId,
            clase_id: 'clase_ninos_regular',
            nombre_persona: 'Valentina',
            nivel: 'Iniciación Infantil',
            hora: '18:00',
            dias: 'M, J',
            fecha_clase: MockTimestamp.fromDate(new Date('2026-11-17T18:00:00')),
            status: 'confirmado',
            tipo: 'prueba',
            origen: 'whatsapp',
          });
        } else if (scenario === 'falsa') {
          await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
            telefono: leadId,
            nombre: 'Elena',
            status: 'reservado',
            perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
            reserva_id: 'res_falsa_01',
            clase_reservada_id: 'clase_ninos_regular',
            fecha_clase_reservada: MockTimestamp.fromDate(new Date('2026-11-17T18:00:00')),
            ai_habilitada: true,
          });
          await harness.firestore.collection('reservas').doc('res_falsa_01').set({
            lead_id: leadId,
            clase_id: 'clase_ninos_regular',
            nombre_persona: 'Valentina',
            nivel: 'Iniciación Infantil',
            hora: '18:00',
            dias: 'M, J',
            fecha_clase: MockTimestamp.fromDate(new Date('2026-11-17T18:00:00')),
            status: 'confirmado',
            tipo: 'prueba',
            origen: 'whatsapp',
          });
          harness.openai.setResponder(async () => ({
            choices: [
              {
                message: {
                  role: 'assistant',
                  content:
                    '¡Listo Elena! He reprogramado la clase de Valentina para este jueves a las 18:00. ¡Te esperamos!',
                },
              },
            ],
          }));
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // API: Send interactive message
  if (url.pathname === '/api/message' && req.method === 'POST') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', async () => {
      try {
        const { leadId, text } = JSON.parse(body || '{}');
        const result = await harness.dispatchMessage(leadId || '+51984000001', text || 'Hola');

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(
          JSON.stringify({
            replyText: result.replyText,
            executedTools: result.executedTools,
            systemPrompt: result.systemPrompt,
            dbState: harness.firestore.dump(),
          })
        );
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // API: Run automated 9-test baseline suite
  if (url.pathname === '/api/run-suite' && req.method === 'GET') {
    try {
      const report = await runBaselineTestSuite();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(report));
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[Harness Server] Running at http://127.0.0.1:${PORT}`);
});

