/**
 * Isolated Real Ginga Agent Loader
 * Loads the UNMODIFIED functions/index.js directly from disk into memory,
 * injecting in-memory Firestore, mock OpenAI, and mock WhatsApp adapters.
 * Guarantees 0 diffs against base commit 3058ada.
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { InMemoryFirestore, createMockAdmin, MockTimestamp } = require('./in_memory_firestore');
const { MockOpenAIAdapter } = require('./openai_adapter');
const { MockWhatsAppAdapter } = require('./whatsapp_adapter');

class RealAgentHarness {
  constructor() {
    this.firestore = new InMemoryFirestore();
    this.openai = new MockOpenAIAdapter();
    this.whatsapp = new MockWhatsAppAdapter();
    this.admin = createMockAdmin(this.firestore);
    this.module = null;
    this.internals = null;
    this.toolExecutionLog = [];

    this._init();
  }

  _init() {
    this.firestore.seedBaseline();

    const indexPath = path.resolve(__dirname, '../functions/index.js');
    const sourceCode = fs.readFileSync(indexPath, 'utf8');

    // Append internal export hook without modifying the file on disk
    const exportHook = `
module.exports.__internals = {
  DEFAULT_SYSTEM_PROMPT,
  obtenerSystemPrompt,
  obtenerFechaLimaAhora,
  diasPermitidosDesdePatron,
  formatearFechaLarga,
  calcularProximaFechaDisponible,
  validarFechaSolicitada,
  reservarClasePruebaLead,
  buscarClaseDisponibleParaPrueba,
  AVAILABLE_TOOLS,
  preguntarIA,
  generarSystemPrompt,
  llamarOpenAI,
  enviarMensajeWhatsApp,
};
`;
    const wrappedCode = sourceCode + exportHook;

    const mockFunctionsBuilder = () => {
      const docBuilder = {
        onCreate: (fn) => fn,
        onUpdate: (fn) => fn,
        onDelete: (fn) => fn,
        onWrite: (fn) => fn,
      };
      const obj = {
        runWith: () => obj,
        https: { onRequest: (fn) => fn, onCall: (fn) => fn },
        firestore: { document: () => docBuilder },
        pubsub: { schedule: () => ({ timeZone: () => ({ onRun: (fn) => fn }) }) },
      };
      return obj;
    };

    const customRequire = (id) => {
      if (id === 'firebase-admin') return this.admin;
      if (id === 'firebase-functions') return mockFunctionsBuilder();
      try {
        return require(id);
      } catch (e) {
        return require(path.resolve(__dirname, '../functions/node_modules', id));
      }
    };

    // Custom fetch router
    const customFetch = async (url, options = {}) => {
      const urlStr = String(url);
      if (urlStr.includes('api.openai.com')) {
        const body = JSON.parse(options.body || '{}');
        const completion = await this.openai.handleChatCompletion(body);
        return {
          ok: true,
          status: 200,
          text: async () => JSON.stringify(completion),
          json: async () => completion,
        };
      }
      if (urlStr.includes('graph.facebook.com')) {
        return this.whatsapp.handleSendMessage(urlStr, options);
      }
      return {
        ok: false,
        status: 404,
        text: async () => 'Mocked URL not handled',
      };
    };

    const mod = { exports: {} };
    const compiledFn = vm.compileFunction(
      wrappedCode,
      ['exports', 'require', 'module', '__filename', '__dirname', 'fetch'],
      { filename: indexPath }
    );

    compiledFn(
      mod.exports,
      customRequire,
      mod,
      indexPath,
      path.resolve(__dirname, '../functions'),
      customFetch
    );

    this.module = mod.exports;
    this.internals = mod.exports.__internals;
  }

  reset() {
    this.firestore.seedBaseline();
    this.openai.reset();
    this.whatsapp.reset();
    this.toolExecutionLog = [];
  }

  /**
   * Dispatches a user message through the exact real agent pipeline:
   * 1. Updates whatsapp_leads with message
   * 2. Calls generarSystemPrompt(leadData, historyLength)
   * 3. Calls preguntarIA with instrumented tool execution
   * 4. Updates Firestore with agent reply
   */
  async dispatchMessage(leadId, userText, callerName = 'Tester') {
    const leadRef = this.firestore.collection('whatsapp_leads').doc(leadId);
    let leadDoc = await leadRef.get();

    if (!leadDoc.exists) {
      await leadRef.set({
        telefono: leadId,
        nombre: callerName,
        status: 'nuevo',
        ai_habilitada: true,
        created_at: MockTimestamp.now(),
        ultima_interaccion: MockTimestamp.now(),
      });
      leadDoc = await leadRef.get();
    }

    const leadData = leadDoc.data();

    // Store user message in subcollection
    const msgRef = leadRef.collection('mensajes').doc(`msg_u_${Date.now()}`);
    await msgRef.set({
      from: 'lead',
      texto: userText,
      timestamp: MockTimestamp.now(),
    });

    // Fetch conversation history
    const histSnap = await leadRef.collection('mensajes').orderBy('timestamp', 'desc').limit(10).get();
    const historial = histSnap.docs.reverse().map((d) => {
      const m = d.data();
      return { role: m.from === 'lead' ? 'user' : 'assistant', content: m.texto };
    });

    // Generate real System Prompt using index.js logic
    const { systemPrompt, preciosValidos } = await this.internals.generarSystemPrompt(
      leadData,
      histSnap.docs.length
    );

    // Call preguntarIA with tool execution instrumentation
    const executedTools = [];
    const onToolCall = (record) => {
      executedTools.push(record);
      this.toolExecutionLog.push({ leadId, ...record, timestamp: new Date().toISOString() });
    };

    const replyText = await this.internals.preguntarIA(
      leadId,
      systemPrompt,
      historial,
      onToolCall
    );

    if (replyText) {
      const replyRef = leadRef.collection('mensajes').doc(`msg_a_${Date.now()}`);
      await replyRef.set({
        from: 'ai',
        texto: replyText,
        timestamp: MockTimestamp.now(),
      });
    }

    // Refresh lead state
    const updatedLead = (await leadRef.get()).data();
    const reservationsSnap = await this.firestore.collection('reservas').where('lead_id', '==', leadId).get();
    const reservations = reservationsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

    return {
      replyText,
      executedTools,
      systemPrompt,
      leadData: updatedLead,
      reservations,
      conversationHistory: historial,
    };
  }
}

module.exports = { RealAgentHarness };

