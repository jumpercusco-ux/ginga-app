/**
 * Baseline Test Scenarios for GINGA Real Agent (Commit 3058ada)
 * Documents actual behavior, limitations, amnesia, duplicate bugs, and lack of rescheduling.
 */

const { MockTimestamp } = require('./in_memory_firestore');

const BASELINE_SCENARIOS = [
  {
    id: 'case_1_consulta_horarios',
    nombre: 'Caso 1: Lead sin reservas que consulta horarios',
    descripcion: 'Lead nuevo sin reservas pregunta por horarios para una niña de 9 años.',
    setup: async (harness) => {
      const leadId = '+51984000001';
      // Limpio, sin datos previos
      return { leadId };
    },
    ejecutar: async (harness, context) => {
      return await harness.dispatchMessage(
        context.leadId,
        'Hola, quisiera saber los horarios de capoeira para niños de 9 años'
      );
    },
    evaluar: (resultado, harness, context) => {
      const toolLlamada = resultado.executedTools.some(
        (t) => t.name === 'consultar_horarios_disponibles'
      );
      const mencionaHorarios =
        resultado.replyText.toLowerCase().includes('18:00') ||
        resultado.replyText.toLowerCase().includes('martes y jueves');
      const pasa = toolLlamada && mencionaHorarios;
      return {
        pasa,
        categoria: 'Consulta',
        diagnostico: pasa
          ? 'Ejecutó consultar_horarios_disponibles y entregó horarios reales.'
          : 'Fallo al consultar u ofrecer horarios.',
      };
    },
  },

  {
    id: 'case_2_lead_con_reserva_vigente',
    nombre: 'Caso 2: Lead con reserva vigente que vuelve a escribir',
    descripcion:
      'Padre con reserva activa para Valentina el próximo jueves escribe consultando vestimenta. Comprueba si el System Prompt reconoce la reserva.',
    setup: async (harness) => {
      const leadId = '+51984000002';
      // 1. Guardar lead
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

      // 2. Guardar reserva en /reservas
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

      return { leadId };
    },
    ejecutar: async (harness, context) => {
      return await harness.dispatchMessage(
        context.leadId,
        'Hola, ¿qué ropa debe llevar Valentina a la clase?'
      );
    },
    evaluar: (resultado, harness, context) => {
      // Inspección de la memoria en la versión base 3058ada:
      // ¿El System Prompt generado incluye las reservas de este lead?
      const promptContieneReserva =
        resultado.systemPrompt.includes('reserva_val_1') ||
        resultado.systemPrompt.includes('RESERVAS CONFIRMADAS') ||
        resultado.systemPrompt.includes('clase de prueba agendada');

      // En la versión 3058ada, generarSystemPrompt NUNCA consulta /reservas
      const amnesiaConfirmada = !promptContieneReserva;

      return {
        pasa: true, // Registra el hallazgo del baseline
        baselineBug: amnesiaConfirmada,
        categoria: 'Memoria de Reserva',
        diagnostico: amnesiaConfirmada
          ? 'BASELINE CONFIRMADO: El agente sufre de amnesia de reservas. generarSystemPrompt no consulta la colección /reservas, por lo que el agente desconoce la reserva vigente de Valentina.'
          : 'El prompt incluyó datos de reserva.',
      };
    },
  },

  {
    id: 'case_3_reserva_cancelada_reintento',
    nombre: 'Caso 3: Reserva cancelada que quiere agendar nuevamente',
    descripcion:
      'Lead tenía una reserva previa para Valentina que fue cancelada (status: cancelado). Intenta agendar de nuevo.',
    setup: async (harness) => {
      const leadId = '+51984000003';
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

      return { leadId };
    },
    ejecutar: async (harness, context) => {
      return await harness.dispatchMessage(
        context.leadId,
        'Hola, quisiéramos retomar y agendar la clase de prueba para Valentina'
      );
    },
    evaluar: (resultado, harness, context) => {
      // En 3058ada, reservar_clase_prueba ejecuta:
      // where('lead_id', '==', leadId).where('clase_id', '==', clase.id)
      // sin filtrar por status. Por tanto, bloquea con "Ya existe una reserva previa..."
      const toolReserva = resultado.executedTools.find((t) => t.name === 'reservar_clase_prueba');
      const fueBloqueadoPorDuplicado =
        toolReserva && toolReserva.result.includes('Ya existe una reserva previa');

      return {
        pasa: true,
        baselineBug: fueBloqueadoPorDuplicado,
        categoria: 'Duplicados',
        diagnostico: fueBloqueadoPorDuplicado
          ? 'BASELINE CONFIRMADO: Error de duplicado espurio. reservar_clase_prueba no filtra por status != cancelado, bloqueando permanentemente a Valentina para volver a reservar.'
          : 'Permitió agendar a pesar de tener reserva cancelada previa.',
      };
    },
  },

  {
    id: 'case_4_reserva_pasada_reintento',
    nombre: 'Caso 4: Reserva pasada que quiere volver a reservar',
    descripcion:
      'Lead asistió o tuvo una reserva hace dos semanas. Ahora quiere volver a agendar.',
    setup: async (harness) => {
      const leadId = '+51984000004';
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
        fecha_clase: MockTimestamp.fromDate(new Date('2026-10-20T18:00:00')), // fecha pasada
        status: 'confirmado',
        tipo: 'prueba',
        origen: 'whatsapp',
      });

      return { leadId };
    },
    ejecutar: async (harness, context) => {
      return await harness.dispatchMessage(
        context.leadId,
        'Hola, quisiéramos agendar otra clase de prueba para Valentina'
      );
    },
    evaluar: (resultado, harness, context) => {
      const toolReserva = resultado.executedTools.find((t) => t.name === 'reservar_clase_prueba');
      const fueBloqueado =
        toolReserva && toolReserva.result.includes('Ya existe una reserva previa');

      return {
        pasa: true,
        baselineBug: fueBloqueado,
        categoria: 'Duplicados / Vencidas',
        diagnostico: fueBloqueado
          ? 'BASELINE CONFIRMADO: Error de fecha vencida. La verificación de duplicados no evalúa si la fecha_clase ya pasó, impidiendo cualquier nueva coordinación.'
          : 'No bloqueó la reserva pasada.',
      };
    },
  },

  {
    id: 'case_5_familia_dos_hijos',
    nombre: 'Caso 5: Padre/madre con dos hijos y reservas diferentes',
    descripcion:
      'Mamá agenda clase para Mateo (12 años) y Lucía (7 años). Comprueba persistencia en /reservas y en whatsapp_leads.',
    setup: async (harness) => {
      const leadId = '+51984000005';
      return { leadId };
    },
    ejecutar: async (harness, context) => {
      return await harness.dispatchMessage(
        context.leadId,
        'Hola, quiero agendar clase de prueba para mis dos hijos: Mateo de 12 y Lucía de 7'
      );
    },
    evaluar: (resultado, harness, context) => {
      const reservas = resultado.reservations;
      const tieneMateo = reservas.some((r) => (r.nombre_persona || '').includes('Mateo'));
      const tieneLucia = reservas.some((r) => (r.nombre_persona || '').includes('Lucía'));

      // Verificar whatsapp_leads escalares
      const lead = resultado.leadData;
      const reservaIdEscalar = lead.reserva_id;
      // Solo puede guardar uno en reserva_id
      const sobreescrituraDetectada =
        reservas.length === 2 &&
        reservaIdEscalar &&
        reservas.filter((r) => r.id === reservaIdEscalar).length === 1;

      return {
        pasa: true,
        baselineBug: sobreescrituraDetectada,
        categoria: 'Multi-Persona',
        diagnostico: sobreescrituraDetectada
          ? `BASELINE CONFIRMADO: En /reservas se crearon ${reservas.length} documentos, pero en whatsapp_leads los campos reserva_id y fecha_clase_reservada son escalares y solo reflejan a uno de los hijos (${reservaIdEscalar}), perdiendo la trazabilidad del primero.`
          : `Se crearon ${reservas.length} reservas.`,
      };
    },
  },

  {
    id: 'case_6_solicitud_reprogramacion',
    nombre: 'Caso 6: Solicitud de reprogramación de martes a jueves',
    descripcion:
      'Lead tiene reserva el Martes. Solicita cambiar la fecha al Jueves. Comprueba si existe herramienta de reprogramación.',
    setup: async (harness) => {
      const leadId = '+51984000006';
      await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
        telefono: leadId,
        nombre: 'Valeria',
        status: 'reservado',
        perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
        reserva_id: 'res_martes_01',
        clase_reservada_id: 'clase_ninos_regular',
        fecha_clase_reservada: MockTimestamp.fromDate(new Date('2026-11-17T18:00:00')), // Martes
        ai_habilitada: true,
      });

      await harness.firestore.collection('reservas').doc('res_martes_01').set({
        lead_id: leadId,
        clase_id: 'clase_ninos_regular',
        nombre_persona: 'Valentina',
        nivel: 'Iniciación Infantil',
        hora: '18:00',
        dias: 'M, J',
        fecha_clase: MockTimestamp.fromDate(new Date('2026-11-17T18:00:00')), // Martes
        status: 'confirmado',
        tipo: 'prueba',
        origen: 'whatsapp',
      });

      return { leadId };
    },
    ejecutar: async (harness, context) => {
      return await harness.dispatchMessage(
        context.leadId,
        'Hola, teníamos agendado para el martes pero no podemos ir, ¿podemos cambiar para el jueves?'
      );
    },
    evaluar: (resultado, harness, context) => {
      // Verificar si alguna herramienta llamada se llama 'reprogramar_reserva'
      const existeToolReprogramar = harness.internals.AVAILABLE_TOOLS.some(
        (t) => t.name === 'reprogramar_reserva'
      );
      const intentoReservar = resultado.executedTools.find(
        (t) => t.name === 'reservar_clase_prueba'
      );
      const rechazoPorDuplicado =
        intentoReservar && intentoReservar.result.includes('Ya existe una reserva previa');

      return {
        pasa: true,
        baselineBug: !existeToolReprogramar,
        categoria: 'Reprogramación',
        diagnostico: !existeToolReprogramar
          ? `BASELINE CONFIRMADO: NO existe la herramienta 'reprogramar_reserva'. Si el modelo intenta llamar a 'reservar_clase_prueba' con la nueva fecha, el backend la rechaza como duplicado ("${intentoReservar?.result || 'sin llamada'}").`
          : 'Existe herramienta de reprogramación.',
      };
    },
  },

  {
    id: 'case_7_reserva_original_vs_nueva_fecha_docs',
    nombre: 'Caso 7: Reserva original y nueva fecha: estado de documentos antes y después',
    descripcion:
      'Verifica documentalmente que la fecha en /reservas no cambió tras pedir reprogramación.',
    setup: async (harness) => {
      const leadId = '+51984000007';
      const fechaMartes = new Date('2026-11-17T18:00:00');
      await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
        telefono: leadId,
        nombre: 'Sonia',
        status: 'reservado',
        perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
        reserva_id: 'res_doc_audit',
        clase_reservada_id: 'clase_ninos_regular',
        fecha_clase_reservada: MockTimestamp.fromDate(fechaMartes),
        ai_habilitada: true,
      });

      await harness.firestore.collection('reservas').doc('res_doc_audit').set({
        lead_id: leadId,
        clase_id: 'clase_ninos_regular',
        nombre_persona: 'Valentina',
        nivel: 'Iniciación Infantil',
        hora: '18:00',
        dias: 'M, J',
        fecha_clase: MockTimestamp.fromDate(fechaMartes),
        status: 'confirmado',
        tipo: 'prueba',
        origen: 'whatsapp',
      });

      return { leadId, fechaOriginal: fechaMartes };
    },
    ejecutar: async (harness, context) => {
      return await harness.dispatchMessage(
        context.leadId,
        'Por favor, cambia mi reserva de Valentina del martes para el jueves a las 18:00'
      );
    },
    evaluar: (resultado, harness, context) => {
      const docPost = resultado.reservations.find((r) => r.id === 'res_doc_audit');
      const fechaPost = docPost?.fecha_clase?.toDate?.();
      const fechaSigueIgual =
        fechaPost && fechaPost.getTime() === context.fechaOriginal.getTime();
      const reservasTotales = resultado.reservations.length;

      return {
        pasa: true,
        baselineBug: fechaSigueIgual && reservasTotales === 1,
        categoria: 'Persistencia de Documentos',
        diagnostico: fechaSigueIgual
          ? `BASELINE CONFIRMADO: La fecha del documento 'res_doc_audit' en Firestore permanece inalterada en ${fechaPost?.toISOString?.()}. No hubo actualización de fecha ni creación de segundo documento.`
          : 'El documento fue modificado.',
      };
    },
  },

  {
    id: 'case_8_confirmacion_textual_sin_persistencia',
    nombre: 'Caso 8: Confirmación textual sin escritura persistida (Falsa Confirmación)',
    descripcion:
      'Detecta si la IA responde con afirmaciones de cambio exitoso mientras la base de datos no fue modificada.',
    setup: async (harness) => {
      const leadId = '+51984000008';
      const fechaMartes = new Date('2026-11-17T18:00:00');
      await harness.firestore.collection('whatsapp_leads').doc(leadId).set({
        telefono: leadId,
        nombre: 'Elena',
        status: 'reservado',
        perfil_personas: [{ nombre: 'Valentina', tipo: 'niño', edad: 9 }],
        reserva_id: 'res_falsa_01',
        clase_reservada_id: 'clase_ninos_regular',
        fecha_clase_reservada: MockTimestamp.fromDate(fechaMartes),
        ai_habilitada: true,
      });

      await harness.firestore.collection('reservas').doc('res_falsa_01').set({
        lead_id: leadId,
        clase_id: 'clase_ninos_regular',
        nombre_persona: 'Valentina',
        nivel: 'Iniciación Infantil',
        hora: '18:00',
        dias: 'M, J',
        fecha_clase: MockTimestamp.fromDate(fechaMartes),
        status: 'confirmado',
        tipo: 'prueba',
        origen: 'whatsapp',
      });

      return { leadId, fechaOriginal: fechaMartes };
    },
    ejecutar: async (harness, context) => {
      // Configuramos el responder de OpenAI para simular el caso donde la IA alucina confirmación
      harness.openai.setResponder(async () => {
        return {
          choices: [
            {
              message: {
                role: 'assistant',
                content:
                  '¡Listo Elena! He reprogramado la clase de Valentina para este jueves a las 18:00. ¡Te esperamos!',
              },
            },
          ],
        };
      });

      return await harness.dispatchMessage(
        context.leadId,
        'Cámbiame para el jueves por favor'
      );
    },
    evaluar: (resultado, harness, context) => {
      const texto = resultado.replyText.toLowerCase();
      const afirmaConfirmacion =
        texto.includes('listo') ||
        texto.includes('reprogramado') ||
        texto.includes('cambiado') ||
        texto.includes('te esperamos el jueves');

      // Verificar si Firestore realmente tiene una reserva para el jueves
      const reservasJueves = resultado.reservations.filter((r) => {
        const f = r.fecha_clase?.toDate?.();
        return f && f.getDay() === 4; // Jueves = 4
      });

      const esAlucinacion = afirmaConfirmacion && reservasJueves.length === 0;

      return {
        pasa: true,
        baselineBug: esAlucinacion,
        categoria: 'Alucinación / Promesa Falsa',
        diagnostico: esAlucinacion
          ? 'ERROR CRÍTICO DETECTADO: Confirmación textual falsa (alucinación) sin persistencia en Firestore. El agente le dice al cliente que su clase fue cambiada para el jueves, pero en la base de datos sigue figurando el martes o no hay reserva.'
          : 'No se detectó promesa falsa.',
      };
    },
  },

  {
    id: 'case_9_solicitud_humano',
    nombre: 'Caso 9: Solicitud de hablar con una persona',
    descripcion:
      'Lead solicita hablar con un profesor humano. Comprueba invocación de marcar_seguimiento_humano y notificación al profesor.',
    setup: async (harness) => {
      const leadId = '+51984000009';
      return { leadId };
    },
    ejecutar: async (harness, context) => {
      return await harness.dispatchMessage(
        context.leadId,
        'Quiero hablar con un profesor humano, por favor'
      );
    },
    evaluar: (resultado, harness, context) => {
      const toolHumano = resultado.executedTools.find(
        (t) => t.name === 'marcar_seguimiento_humano'
      );
      const leadStatus = resultado.leadData?.status;
      const pasa = toolHumano && leadStatus === 'requiere_atencion';

      return {
        pasa,
        categoria: 'Control Humano',
        diagnostico: pasa
          ? `Ejecutó marcar_seguimiento_humano correctamente. Lead marcado como requiere_atencion con motivo: "${toolHumano.args?.motivo}".`
          : 'Fallo al derivar a control humano.',
      };
    },
  },
];

module.exports = { BASELINE_SCENARIOS };

