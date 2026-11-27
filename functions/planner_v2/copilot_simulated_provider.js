'use strict';

const { normalizeMaterialKey } = require('./copilot_context_and_prompt');

/**
 * Deterministic Capoeira Pedagogical Copilot provider for 100% offline execution
 * and acceptance testing (`PED-04C3`, 0 paid OpenAI calls).
 */
class SimulatedCopilotProvider {
  constructor({ catalog } = {}) {
    this.name = 'simulated-copilot';
    this.catalog = catalog || null;
  }

  async proposeTurn({ copilotContext }) {
    const msg = String(copilotContext.rawMessage || '').trim();
    const msgAscii = normalizeMaterialKey(msg);
    const plan = copilotContext.plan;
    const isInfantil = plan.audience_type === 'infantil';
    const space = copilotContext.validationContext.space;
    const materialsKnown = copilotContext.validationContext.materialsKnown;
    const confirmedMaterials = new Set(
      (copilotContext.validationContext.materials || []).map((m) => normalizeMaterialKey(m))
    );

    // 1. Prompt injection / arbitrary DB/code/adult-FIU-for-kids guard
    if (
      copilotContext.injectionSignals.length > 0 ||
      /\b(firestore|eval\(|exec\(|borrar\s+colecci[oó]n|escrib(?:e|ir)\s+en\s+bd|curr[ií]culo\s+adulto\s+(?:a|para)\s+infantil|asignar\s+corda\s+infantil)\b/i.test(
        msg
      )
    ) {
      return {
        rawOutput: {
          mode: 'conflict',
          assistant_message:
            'No puedo ejecutar instrucciones sobre base de datos ni asignar graduaciones oficiales de Adulto FIU a un grupo infantil.',
          pedagogical_notes: [
            'Las operaciones permitidas se limitan estrictamente a propuestas tipadas sobre el borrador abierto.',
            'Para Infantil se mantienen referencias técnicas no curriculares (technical_movement_refs) sin corda oficial adulta.',
          ],
          conflict_reason:
            'Solicitud fuera de contrato seguro o incompatible con la protección curricular infantil.',
          safe_alternative:
            'Puedo adaptar progresiones técnicas de Ginga, Armada o Aú para Infantil o incorporar un recurso de tu Pizarra.',
          operations: [],
        },
        usage: { inputTokens: 480, outputTokens: 160, estimatedCostUsd: 0 },
      };
    }

    // 2. Reject unconfirmed materials requested explicitly for implementation
    const matChecks = [
      { key: 'colchoneta', re: /\bcolchonetas?\b/i, alt: 'progresiones bajas de control corporal (Aú rasante, Cocorinha y Rolê lateral controlado)' },
      { key: 'silla', re: /\b(?:usar|con|pon|coloca)\s+sillas?\b/i, alt: 'juego de reflejos y Ginga por parejas con marcas visuales imaginarias en el suelo' },
      { key: 'cono', re: /\b(?:usar|con|pon|coloca)\s+conos?\b/i, alt: 'carriles paralelos con referencias visuales de líneas o marcas del salón' },
      { key: 'berimbau', re: /\b(?:tocar|usar|con)\s+(?:el\s+)?berimbau\b/i, alt: 'palmas de 3 tiempos, voz y canto responsorial si el berimbau no está disponible' },
    ];
    for (const mc of matChecks) {
      const wantsModify = !/^(?:qu[eé]|cu[aá]l|explica|por\s+qu[eé]|puedo)/i.test(msgAscii);
      if (wantsModify && mc.re.test(msgAscii)) {
        const isConfirmed =
          mc.key === 'colchoneta'
            ? space.availableMats === true || confirmedMaterials.has('colchonetas')
            : confirmedMaterials.has(mc.key) || confirmedMaterials.has(`${mc.key}s`);
        if (!isConfirmed) {
          return {
            rawOutput: {
              mode: 'conflict',
              assistant_message: `No puedo exigir '${mc.key}' en la clase porque no figura confirmado en las condiciones reales del espacio/materiales.`,
              pedagogical_notes: [
                `Condición actual: piso=${space.floorType || 'desconocido'}, colchonetas=${space.availableMats ?? 'no confirmadas'}, materiales confirmados=${materialsKnown ? [...confirmedMaterials].join(', ') || 'ninguno' : 'no declarados'}.`,
              ],
              conflict_reason: `Material '${mc.key}' no disponible ni confirmado en el borrador actual.`,
              safe_alternative: `Como alternativa ejecutable inmediata, te propongo trabajar con ${mc.alt}.`,
              operations: [],
            },
            usage: { inputTokens: 510, outputTokens: 175, estimatedCostUsd: 0 },
          };
        }
      }
    }

    // 3. Reject unsafe progressions on Infantil / unconfirmed floor / single-instructor group
    const unsafeRe = /\b(bananeira|parada\s+de\s+m[aã]o|ponte|queda\s+de\s+rim|mortal|parafuso|s-?dobrado|voltereta|maroma|rodar\s+hacia\s+adelante)\b/i;
    if (unsafeRe.test(msgAscii) && !/\b(por\s+qu[eé]\s+no|explica|evitar)\b/i.test(msgAscii)) {
      const safeFloorConfirmed = space.floorType === 'tatami' && space.availableMats === true;
      if (isInfantil || !safeFloorConfirmed) {
        return {
          rawOutput: {
            mode: 'conflict',
            assistant_message:
              'Esta progresión implica inversión vertical, impacto o rodada insegura para el perfil infantil y la superficie actual no confirmada.',
            pedagogical_notes: [
              `Riesgo detectado con floor_type='${space.floorType}', colchonetas=${space.availableMats ?? 'sin confirmar'} e instructores=${copilotContext.validationContext.instructorsAvailable}.`,
            ],
            conflict_reason:
              'Progresión insegura para las condiciones actuales de edad, piso sin tatami/colchonetas o supervisión.',
            safe_alternative:
              'Podemos reforzar preparación de Aú con apoyos bajos de manos alternando pies o salida lateral en Rolê desde Negativa sin impacto.',
            operations: [],
          },
          usage: { inputTokens: 520, outputTokens: 180, estimatedCostUsd: 0 },
        };
      }
    }

    // 4. Informative consultation (Mode A: zero plan mutations!)
    const isExplicitMutationVerb =
      /\b(modifica|cambia|sustituye|reemplaza|anade|añade|agrega|incorpora|inserta|elimina|quita|redistribuye|ajusta|adapta|reduce|amplia|amplía|vincula|actualiza|pon|usa|convierte)\b/i.test(
        msgAscii
      );
    const isConsult =
      !isExplicitMutationVerb ||
      /^(?:explica|dime|c[oó]mo|cu[aá]les|qu[eé]\s+errores|sugiere|recomienda|consulta)/i.test(msgAscii);

    if (isConsult) {
      const selEx = copilotContext.selectedExercise;
      const selBlk = copilotContext.selectedBlock;
      const resNames = copilotContext.availableResourcesCompact.map((r) => `${r.title} (${r.category})`).join('; ');
      const focusTarget = selEx ? `"${selEx.nombre}" (${selEx.duracion_min} min)` : selBlk ? `el bloque "${selBlk.fase}"` : 'la clase abierta';
      const fiuNote =
        copilotContext.curriculumSlice.length > 0
          ? `Movimientos FIU pertinentes: ${copilotContext.curriculumSlice.map((m) => m.canonical_name).slice(0, 5).join(', ')}.`
          : 'Para grupo infantil no se vinculan cordas oficiales adultas FIU; trabajamos progresiones técnicas base por niveles.';

      return {
        rawOutput: {
          mode: 'consult',
          assistant_message:
            `Sobre ${focusTarget}: prioriza postura equilibrada en base de Ginga (mirada al frente y pies al ancho de hombros), entrada progresiva antes de acelerar giros de Armada y apoyos firmes con dedos separados en Aú. ${
              selEx?.sugerencias_ia ? `Punto clave actual: ${selEx.sugerencias_ia} ` : ''
            }Errores frecuentes: cruzar los pies en el retorno y flexionar codos al apoyar las manos. ${fiuNote}`,
          pedagogical_notes: [
            resNames ? `Recursos disponibles en Pizarra: ${resNames}.` : 'Sin recursos de Pizarra adicionales cargados.',
            'Esta consulta es exclusivamente orientativa y no modifica tu borrador.',
          ],
          conflict_reason: null,
          safe_alternative: null,
          operations: [],
        },
        usage: { inputTokens: 490, outputTokens: 210, estimatedCostUsd: 0 },
      };
    }

    // 5. Controlled Modification Mode (Mode B)

    // 5A. Redistribute total duration (e.g. "60 a 45 minutos" or "reducir clase a 45 min")
    const durMatch = msgAscii.match(/\b(?:a|en|de)\s*(\d{2,3})\s*min/i) || msgAscii.match(/\bredistribu\w*\b.*?(\d{2,3})\b/i);
    if (/redistribu|duraci[oó]n\s+total|reducir\s+(?:la\s+)?clase|ajustar\s+(?:la\s+)?clase\s+a/i.test(msgAscii) && durMatch) {
      const targetDur = Math.max(20, Math.min(180, Number(durMatch[1])));
      return {
        rawOutput: {
          mode: 'propose_changes',
          assistant_message: `Propongo redistribuir proporcionalmente toda la clase a ${targetDur} minutos exactos conservando todos tus bloques, movimientos, recursos y etapas internas.`,
          pedagogical_notes: [
            `La suma de bloques y ejercicios quedará exactamente igual a ${targetDur} min sin perder progresiones ni rueda de cierre.`,
          ],
          conflict_reason: null,
          safe_alternative: null,
          operations: [
            {
              type: 'redistribute_duration',
              block_id: null,
              exercise_id: null,
              target_duration_min: targetDur,
              resource_id: null,
              resource_usage_note: null,
              fase: null,
              fase_tipo: null,
              duracion_min: null,
              nombre: null,
              tipo_actividad: null,
              detalle: null,
              organizacion: null,
              seguridad: null,
              diferenciacion_principiantes: null,
              diferenciacion_intermedios: null,
              diferenciacion_avanzados: null,
              sugerencias_ia: null,
              technical_movement_refs: null,
              curriculum_movement_ids: null,
              materiales: null,
              tiempos_internos: null,
            },
          ],
        },
        usage: { inputTokens: 540, outputTokens: 190, estimatedCostUsd: 0 },
      };
    }

    // 5B. Incorporate Pizarra resource into the class
    if (/recurso|pizarra|vincular/i.test(msgAscii) || copilotContext.availableResourcesCompact.some((r) => msgAscii.includes(normalizeMaterialKey(r.title)))) {
      const matchedRes =
        copilotContext.availableResourcesCompact.find((r) => msgAscii.includes(normalizeMaterialKey(r.title))) ||
        copilotContext.availableResourcesCompact.find((r) => msgAscii.includes(normalizeMaterialKey(r.resource_id))) ||
        copilotContext.availableResourcesCompact[0];
      if (!matchedRes) {
        return {
          rawOutput: {
            mode: 'conflict',
            assistant_message: 'No encontré ningún recurso de tu Pizarra disponible en la sesión para vincular.',
            pedagogical_notes: [],
            conflict_reason: 'No hay recursos de Pizarra disponibles en el contexto enviado.',
            safe_alternative: 'Selecciona o crea primero un recurso en Pizarra y vuelve a pedirme incorporarlo.',
            operations: [],
          },
          usage: { inputTokens: 450, outputTokens: 140, estimatedCostUsd: 0 },
        };
      }
      const targetBlk =
        copilotContext.selectedBlock ||
        plan.bloques.find((b) => b.fase_tipo === 'juegos' || b.fase_tipo === 'tecnica') ||
        plan.bloques[0];
      const targetEx = copilotContext.selectedExercise || targetBlk.ejercicios[0];
      return {
        rawOutput: {
          mode: 'propose_changes',
          assistant_message: `Propongo incorporar el recurso de Pizarra "${matchedRes.title}" en "${targetEx.nombre}" (${targetBlk.fase}), manteniendo la duración y los demás ejercicios intactos.`,
          pedagogical_notes: [
            matchedRes.has_external_video
              ? 'El recurso incluye enlace de video externo: se integrará únicamente según sus notas escritas (no se analiza el video).'
              : 'Se actualizará la procedencia a teacher_resource conservando el resto de la clase.',
          ],
          conflict_reason: null,
          safe_alternative: null,
          operations: [
            {
              type: 'link_resource',
              block_id: targetBlk.block_id,
              exercise_id: targetEx.exercise_id,
              target_duration_min: null,
              resource_id: matchedRes.resource_id,
              resource_usage_note: `Aplicar "${matchedRes.title}" respetando las reglas y rotación del bloque.`,
              fase: null,
              fase_tipo: null,
              duracion_min: null,
              nombre: null,
              tipo_actividad: null,
              detalle: null,
              organizacion: null,
              seguridad: null,
              diferenciacion_principiantes: null,
              diferenciacion_intermedios: null,
              diferenciacion_avanzados: null,
              sugerencias_ia: null,
              technical_movement_refs: null,
              curriculum_movement_ids: null,
              materiales: null,
              tiempos_internos: null,
            },
          ],
        },
        usage: { inputTokens: 560, outputTokens: 205, estimatedCostUsd: 0 },
      };
    }

    // 5C. Replace a game exercise with a Capoeira Armada game
    if (/sustitu|reemplaza|cambia.*juego/i.test(msgAscii) && /armada/i.test(msgAscii)) {
      const gameBlk =
        (copilotContext.selectedBlock && /juego/i.test(copilotContext.selectedBlock.fase_tipo)
          ? copilotContext.selectedBlock
          : plan.bloques.find((b) => b.fase_tipo === 'juegos')) ||
        copilotContext.selectedBlock ||
        plan.bloques[1] ||
        plan.bloques[0];
      const targetEx =
        (copilotContext.selectedExercise && (gameBlk.ejercicios || []).some((e) => e.exercise_id === copilotContext.selectedExercise.exercise_id)
          ? copilotContext.selectedExercise
          : (gameBlk.ejercicios || []).find((e) => !(e.linked_resource_ids || []).length) || gameBlk.ejercicios[0]);
      const d = Number(targetEx.duracion_min || 6);
      const p1 = Math.max(1, Math.floor(d / 3));
      const p2 = Math.max(1, d - p1);
      return {
        rawOutput: {
          mode: 'propose_changes',
          assistant_message: `Propongo sustituir "${targetEx.nombre}" por un juego técnico específico de Armada con rotación simultánea sin eliminar al resto del bloque.`,
          pedagogical_notes: [
            'Se conservan intactos los demás ejercicios, el recurso obligatorio de Pizarra y la duración exacta del bloque.',
          ],
          conflict_reason: null,
          safe_alternative: null,
          operations: [
            {
              type: 'replace_exercise',
              block_id: gameBlk.block_id,
              exercise_id: targetEx.exercise_id,
              target_duration_min: null,
              resource_id: null,
              resource_usage_note: null,
              fase: null,
              fase_tipo: null,
              duracion_min: d,
              nombre: 'Juego Técnico de Armada y Esquiva por Señales',
              tipo_actividad: 'juego_dinamico',
              detalle:
                'Objetivo: aplicar giro controlado de Armada con esquiva de respuesta en juego cooperativo. Preparación: parejas frente a frente en carriles con 2 metros libres. Reglas y señales: con palmas del profesor, un alumno ejecuta Armada controlada al aire y la pareja responde con Esquiva o Cocorinha sin contacto. Rondas y rotación: rotación continua cada 90 segundos sin filas ni eliminaciones.',
              organizacion: 'Rotación por parejas',
              seguridad: 'Cero contacto físico; mantener distancia de pierna extendida y mirada sobre el compañero.',
              diferenciacion_principiantes: 'Ginga base y media rotación de cadera preparando la pierna de Armada a altura baja.',
              diferenciacion_intermedios: 'Armada continua completa retornando a base trasera antes de esquivar.',
              diferenciacion_avanzados: 'Enlazar Armada limpia con salida directa en Esquiva lateral al pulso.',
              sugerencias_ia: 'Cuidar que mantengan la mirada al frente durante todo el giro de la Armada.',
              technical_movement_refs: ['Ginga', 'Armada', 'Esquiva', 'Cocorinha'],
              curriculum_movement_ids: null,
              materiales: [],
              tiempos_internos: [
                { etapa: 'Preparación y postura de Armada', minutos: p1 },
                { etapa: 'Rondas activas Armada y Esquiva', minutos: p2 },
              ],
            },
          ],
        },
        usage: { inputTokens: 590, outputTokens: 250, estimatedCostUsd: 0 },
      };
    }

    // 5D. Adapt Aú by levels
    if (/\bau\b/i.test(msgAscii) && /nivel|principiante|intermedio|avanzado|diferencia|adapta/i.test(msgAscii)) {
      let targetBlk = copilotContext.selectedBlock;
      let targetEx = copilotContext.selectedExercise;
      if (!targetEx || !/\bau\b/i.test(normalizeMaterialKey(`${targetEx.nombre} ${targetEx.detalle}`))) {
        for (const b of plan.bloques) {
          const hit = (b.ejercicios || []).find((e) => /\bau\b/i.test(normalizeMaterialKey(`${e.nombre} ${e.detalle}`)));
          if (hit) {
            targetBlk = b;
            targetEx = hit;
            break;
          }
        }
      }
      targetBlk = targetBlk || plan.bloques[0];
      targetEx = targetEx || targetBlk.ejercicios[0];
      return {
        rawOutput: {
          mode: 'propose_changes',
          assistant_message: `Propongo refinar la diferenciación por 3 niveles del ejercicio "${targetEx.nombre}" sin alterar su duración ni los demás ejercicios.`,
          pedagogical_notes: [
            'Principiantes trabajan apoyos seguros con cadera baja; intermedios Aú lateral controlado; avanzados enlace fluido hacia Ginga/Rolê.',
          ],
          conflict_reason: null,
          safe_alternative: null,
          operations: [
            {
              type: 'update_exercise',
              block_id: targetBlk.block_id,
              exercise_id: targetEx.exercise_id,
              target_duration_min: null,
              resource_id: null,
              resource_usage_note: null,
              fase: null,
              fase_tipo: null,
              duracion_min: null,
              nombre: null,
              tipo_actividad: null,
              detalle: null,
              organizacion: null,
              seguridad: 'Verificar manos firmes con dedos separados y caída suave sobre la punta de los pies.',
              diferenciacion_principiantes:
                'Preparación de Aú con apoyos progresivos de manos en el suelo, pasando un pie a la vez con cadera baja.',
              diferenciacion_intermedios:
                'Aú lateral controlado elevando caderas de forma simétrica y aterrizando estable.',
              diferenciacion_avanzados:
                'Perfeccionamiento de Aú fluido y amplio enlazando el aterrizaje con Ginga o salida en Rolê.',
              sugerencias_ia: 'Corregir brazos extendidos al apoyar las palmas y evitar que miren al techo al pasar.',
              technical_movement_refs: ['Aú', 'Ginga'],
              curriculum_movement_ids: null,
              materiales: null,
              tiempos_internos: null,
            },
          ],
        },
        usage: { inputTokens: 560, outputTokens: 225, estimatedCostUsd: 0 },
      };
    }

    // 5E. Default targeted single-exercise enhancement (respects selected block/exercise and leaves all others intact)
    const blk = copilotContext.selectedBlock || plan.bloques[0];
    const ex = copilotContext.selectedExercise || blk.ejercicios[0];
    const d = Number(ex.duracion_min || 5);
    const s1 = Math.max(1, Math.floor(d / 3));
    const s2 = Math.max(1, d - s1);
    const wantsSimultaneous = /simult[aá]ne|parejas|estaciones|fila/i.test(msgAscii);

    return {
      rawOutput: {
        mode: 'propose_changes',
        assistant_message: `Propongo ajustar únicamente "${ex.nombre}" en "${blk.fase}" manteniendo intactos todos los demás ejercicios, movimientos y recursos.`,
        pedagogical_notes: [
          'Se conserva la duración exacta del ejercicio y el desglose interno en etapas ejecutables.',
        ],
        conflict_reason: null,
        safe_alternative: null,
        operations: [
          {
            type: 'update_exercise',
            block_id: blk.block_id,
            exercise_id: ex.exercise_id,
            target_duration_min: null,
            resource_id: null,
            resource_usage_note: null,
            fase: null,
            fase_tipo: null,
            duracion_min: null,
            nombre: null,
            tipo_actividad: null,
            detalle: `${ex.detalle.replace(/\s*Tiempos internos\s*\([^)]*\)\.?/gi, '').trim()} Ajuste guiado en parejas activas y participación simultánea al ritmo de palmas sin esperas en fila.`,
            organizacion: wantsSimultaneous && /pareja/i.test(msgAscii) ? 'Rotación por parejas' : 'Todos simultáneamente',
            seguridad: null,
            diferenciacion_principiantes: null,
            diferenciacion_intermedios: null,
            diferenciacion_avanzados: null,
            sugerencias_ia: 'Reforzar postura equilibrada de Ginga y pausas breves de corrección visual sin detener al grupo.',
            technical_movement_refs: null,
            curriculum_movement_ids: null,
            materiales: null,
            tiempos_internos:
              Array.isArray(ex.tiempos_internos) && ex.tiempos_internos.length >= 2
                ? ex.tiempos_internos
                : [
                    { etapa: 'Preparación y demo guiada', minutos: s1 },
                    { etapa: 'Práctica simultánea con ajuste', minutos: s2 },
                  ],
          },
        ],
      },
      usage: { inputTokens: 540, outputTokens: 210, estimatedCostUsd: 0 },
    };
  }
}

module.exports = {
  SimulatedCopilotProvider,
};
