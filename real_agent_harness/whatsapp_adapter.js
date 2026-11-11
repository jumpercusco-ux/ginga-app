/**
 * WhatsApp Interceptor Adapter for GINGA Testing Harness
 * Catches all outgoing WhatsApp messages without hitting Meta Graph API.
 */

class MockWhatsAppAdapter {
  constructor() {
    this.outbox = [];
  }

  reset() {
    this.outbox = [];
  }

  handleSendMessage(url, options) {
    let payload = {};
    try {
      payload = JSON.parse(options.body || '{}');
    } catch (_) {}

    const record = {
      timestamp: new Date().toISOString(),
      url,
      recipient: payload.to || payload.recipient || 'unknown',
      type: payload.type || 'text',
      text: payload.text?.body || null,
      template: payload.template?.name || null,
      raw: payload,
    };
    this.outbox.push(record);

    return {
      ok: true,
      status: 200,
      json: async () => ({ messages: [{ id: `wamid.mock_${Date.now()}` }] }),
      text: async () => JSON.stringify({ messages: [{ id: `wamid.mock_${Date.now()}` }] }),
    };
  }

  getMessagesFor(recipient) {
    return this.outbox.filter((m) => m.recipient === recipient);
  }
}

module.exports = { MockWhatsAppAdapter };

