/**
 * OpenAI Mock Adapter for GINGA Testing Harness
 * Operates 100% offline, intercepts OpenAI chat completion requests,
 * records prompt context and tool interactions, and simulates LLM responses.
 */

class MockOpenAIAdapter {
  constructor() {
    this.recordedCalls = [];
    this.customResponder = null;
    this.scenarioMode = 'auto'; // 'auto' | 'custom'
  }

  reset() {
    this.recordedCalls = [];
    this.customResponder = null;
    this.scenarioMode = 'auto';
  }

  setResponder(fn) {
    this.customResponder = fn;
    this.scenarioMode = 'custom';
  }

  async handleChatCompletion(body) {
    this.recordedCalls.push(body);
    const messages = body.messages || [];
    const tools = body.tools || [];
    const lastMessage = messages[messages.length - 1];

    if (this.scenarioMode === 'custom' && this.customResponder) {
      const customResult = await this.customResponder(body, messages);
      if (customResult) return customResult;
    }

    // Default intelligent offline responder based on message contents and tool results:
    return this._autoRespond(messages, tools);
  }

  _autoRespond(messages, tools) {
    const lastMsg = messages[messages.length - 1];

    // Round 2+: If previous message was a tool result, synthesize final assistant text
    if (lastMsg && lastMsg.role === 'tool') {
      const toolResults = messages.filter((m) => m.role === 'tool');
      const lastTool = toolResults[toolResults.length - 1];

      // If tool was consultar_horarios_disponibles
      if (lastTool.content.includes('Horarios disponibles:')) {
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: '¡Hola! Tenemos clases de Capoeira para niños los martes y jueves a las 18:00 en Av. de la Cultura E-4, 2do piso (frente a Divergym). La mensualidad es S/140. ¿Cómo se llama tu pequeño/a?',
              },
            },
          ],
        };
      }

      // If tool was reservar_clase_prueba
      if (lastTool.content.includes('Reserva confirmada')) {
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: `¡Perfecto! ${lastTool.content} Recuerda llegar 10 minutos antes con ropa cómoda y agua.`,
              },
            },
          ],
        };
      }

      // If tool was reprogramar_reserva
      if (lastTool.content.includes('Reprogramación confirmada')) {
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: `¡Listo! ${lastTool.content}`,
              },
            },
          ],
        };
      }

      // If tool reported provisional safety escalation or requested human handoff
      if (
        lastTool.content.includes('DERIVACIÓN A INSTRUCTOR') ||
        lastTool.content.includes('MEDIDA DE SEGURIDAD PROVISIONAL') ||
        lastTool.content.includes('POLÍTICA COMERCIAL') ||
        lastTool.content.includes('marcar_seguimiento_humano')
      ) {
        // Model obeys directive to call marcar_seguimiento_humano
        const alreadyCalledHuman = toolResults.some((t) => t.role === 'tool' && t.content.includes('Se notificó a un instructor'));
        if (!alreadyCalledHuman) {
          return {
            choices: [
              {
                message: {
                  role: 'assistant',
                  content: null,
                  tool_calls: [
                    {
                      id: `call_${Date.now()}_escalate`,
                      type: 'function',
                      function: {
                        name: 'marcar_seguimiento_humano',
                        arguments: JSON.stringify({
                          motivo: 'Política comercial: lead ya asistió o no asistió a clase previa',
                        }),
                      },
                    },
                  ],
                },
              },
            ],
          };
        }
      }

      // If tool reported duplicate reservation
      if (lastTool.content.includes('Ya existe una reserva previa')) {
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: `${lastTool.content} Te esperamos en esa fecha; si deseas cambiar de fecha, te pondré en contacto con un profesor.`,
              },
            },
          ],
        };
      }

      // If tool was marcar_seguimiento_humano
      if (lastTool.content.includes('Se notificó a un instructor')) {
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: 'He avisado a nuestro instructor del motivo de tu consulta. Te escribirá personalmente a la brevedad.',
              },
            },
          ],
        };
      }

      // If tool was guardar_perfil_lead
      if (lastTool.content.includes('Perfil guardado')) {
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: '¡Entendido! Tenemos clases para esa edad los martes y jueves a las 18:00. ¿Te gustaría agendar la clase de prueba gratuita?',
              },
            },
          ],
        };
      }

      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: lastTool.content,
            },
          },
        ],
      };
    }

    // Round 1: Check user message content
    const userMsgs = messages.filter((m) => m.role === 'user');
    const lastUserText = userMsgs.length > 0 ? (userMsgs[userMsgs.length - 1].content || '') : '';
    const textLower = lastUserText.toLowerCase();

    // 1. Human handoff request
    if (
      textLower.includes('humano') ||
      textLower.includes('persona') ||
      textLower.includes('profesor') ||
      textLower.includes('llamar') ||
      textLower.includes('lesion') ||
      textLower.includes('rodilla')
    ) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: null,
              tool_calls: [
                {
                  id: `call_${Date.now()}_human`,
                  type: 'function',
                  function: {
                    name: 'marcar_seguimiento_humano',
                    arguments: JSON.stringify({
                      motivo: textLower.includes('humano') || textLower.includes('persona')
                        ? 'Solicita hablar con una persona'
                        : 'Consulta sobre salud o lesión',
                    }),
                  },
                },
              ],
            },
          },
        ],
      };
    }

    // 2. Rescheduling request: "reprogramar", "cambiar", "pasar al jueves"
    if (textLower.includes('reprogram') || textLower.includes('cambiar') || (textLower.includes('martes') && textLower.includes('jueves'))) {
      const hasReprogramarTool = tools.some(
        (t) => (t.function?.name === 'reprogramar_reserva' || t.name === 'reprogramar_reserva')
      );

      if (hasReprogramarTool) {
        let fechaTarget = '2026-11-19';
        const matchFecha = lastUserText.match(/\d{4}-\d{2}-\d{2}/);
        if (matchFecha) {
          fechaTarget = matchFecha[0];
        } else if (textLower.includes('jueves')) {
          fechaTarget = '2026-11-19';
        } else if (textLower.includes('martes')) {
          fechaTarget = '2026-11-17';
        }

        let nombreTarget = null;
        if (textLower.includes('valentina')) nombreTarget = 'Valentina';
        else if (textLower.includes('mateo')) nombreTarget = 'Mateo';
        else if (textLower.includes('lucia') || textLower.includes('lucía')) nombreTarget = 'Lucía';

        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: null,
                tool_calls: [
                  {
                    id: `call_${Date.now()}_reprog`,
                    type: 'function',
                    function: {
                      name: 'reprogramar_reserva',
                      arguments: JSON.stringify({
                        nombre: nombreTarget,
                        nueva_fecha: fechaTarget,
                        motivo: 'Cambio solicitado por el usuario',
                      }),
                    },
                  },
                ],
              },
            },
          ],
        };
      }

      // Baseline behavior without reprogramar_reserva tool:
      if (textLower.includes('reservar de nuevo') || textLower.includes('cambiar')) {
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content: null,
                tool_calls: [
                  {
                    id: `call_${Date.now()}_reprog`,
                    type: 'function',
                    function: {
                      name: 'reservar_clase_prueba',
                      arguments: JSON.stringify({
                        nombre: 'Valentina',
                        fecha_solicitada: '2026-11-19',
                      }),
                    },
                  },
                ],
              },
            },
          ],
        };
      }

      // Hallucinated text confirmation case:
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: '¡Claro que sí! He cambiado tu reserva para este jueves a las 18:00. ¡Te esperamos!',
            },
          },
        ],
      };
    }

    // 3. Requesting reservation with names/ages: "Mateo de 12 y Lucía de 7"
    if (textLower.includes('mateo') && (textLower.includes('lucia') || textLower.includes('lucía'))) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: null,
              tool_calls: [
                {
                  id: `call_${Date.now()}_p1`,
                  type: 'function',
                  function: {
                    name: 'guardar_perfil_lead',
                    arguments: JSON.stringify({
                      personas: [
                        { nombre: 'Mateo', tipo: 'niño', edad: 12 },
                        { nombre: 'Lucía', tipo: 'niño', edad: 7 },
                      ],
                    }),
                  },
                },
                {
                  id: `call_${Date.now()}_r1`,
                  type: 'function',
                  function: {
                    name: 'reservar_clase_prueba',
                    arguments: JSON.stringify({
                      nombre: 'Mateo',
                      tipo: 'niño',
                    }),
                  },
                },
                {
                  id: `call_${Date.now()}_r2`,
                  type: 'function',
                  function: {
                    name: 'reservar_clase_prueba',
                    arguments: JSON.stringify({
                      nombre: 'Lucía',
                      tipo: 'niño',
                    }),
                  },
                },
              ],
            },
          },
        ],
      };
    }

    // 4. Requesting reservation for single child: "agendar para Valentina"
    if (textLower.includes('agendar') || textLower.includes('reservar') || textLower.includes('si quiero') || textLower.includes('sí quiero')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: null,
              tool_calls: [
                {
                  id: `call_${Date.now()}_res`,
                  type: 'function',
                  function: {
                    name: 'reservar_clase_prueba',
                    arguments: JSON.stringify({
                      nombre: 'Valentina',
                      tipo: 'niño',
                    }),
                  },
                },
              ],
            },
          },
        ],
      };
    }

    // 5. Returning customer with question: "ropa", "que llevar", "como llegar"
    if (textLower.includes('ropa') || textLower.includes('llevar') || textLower.includes('llegar') || textLower.includes('direccion')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: 'Para la clase de prueba solo necesita ropa deportiva cómoda (pantalón de buzo y polo) y una botella con agua. No hace falta calzado especial, entrenamos descalzos.',
            },
          },
        ],
      };
    }

    // 6. Generic schedule / prices question
    if (textLower.includes('horario') || textLower.includes('precio') || textLower.includes('info') || textLower.includes('clase')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: null,
              tool_calls: [
                {
                  id: `call_${Date.now()}_sched`,
                  type: 'function',
                  function: {
                    name: 'consultar_horarios_disponibles',
                    arguments: '{}',
                  },
                },
              ],
            },
          },
        ],
      };
    }

    // Fallback: polite greeting
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: '¡Hola! Bienvenido a Capoeira FIU / Ginga Cusco. ¿En qué te podemos ayudar hoy?',
          },
        },
      ],
    };
  }
}

module.exports = { MockOpenAIAdapter };

