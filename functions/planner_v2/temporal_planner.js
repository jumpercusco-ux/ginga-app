'use strict';

/**
 * Deterministic Flexible Temporal Blueprint Planner (`PED-04C2-D`).
 *
 * Allocates blocks and exercise slots whose durations are mathematically guaranteed
 * to match `durationMin` BEFORE creative pedagogical content is requested from OpenAI,
 * while remaining flexible across durations (45/60/75/90+ min), focuses, audiences,
 * space constraints, and teacher resources (zero rigid 5-block template).
 */

function distributeExactMinutes(totalMinutes, weights) {
  const safeTotal = Math.max(2, Number(totalMinutes || 60));
  const safeWeights = Array.isArray(weights) && weights.length > 0 ? weights : [1, 1];
  const weightSum = safeWeights.reduce((acc, w) => acc + Math.max(1, Number(w || 1)), 0);

  const allocs = safeWeights.map((w) =>
    Math.max(2, Math.floor((safeTotal * Math.max(1, Number(w || 1))) / weightSum))
  );

  let diff = safeTotal - allocs.reduce((a, b) => a + b, 0);
  let idx = 0;
  while (diff > 0) {
    allocs[idx % allocs.length] += 1;
    diff -= 1;
    idx += 1;
  }
  while (diff < 0) {
    // Reduce from largest slot (> 2 min) first
    let maxIdx = 0;
    for (let i = 1; i < allocs.length; i++) {
      if (allocs[i] > allocs[maxIdx]) maxIdx = i;
    }
    if (allocs[maxIdx] <= 2) break;
    allocs[maxIdx] -= 1;
    diff += 1;
  }
  return allocs;
}

function buildInternalStageTemplate(duracionMin) {
  const safeDur = Math.max(1, Number(duracionMin || 1));
  if (safeDur < 4) {
    return {
      min_internal_stages: 1,
      suggested_stage_minutes: [safeDur],
    };
  }
  if (safeDur <= 6) {
    const s1 = 2;
    return {
      min_internal_stages: 2,
      suggested_stage_minutes: [s1, safeDur - s1],
    };
  }
  const s1 = 2;
  const s3 = Math.max(2, Math.floor(safeDur * 0.28));
  const s2 = safeDur - s1 - s3;
  return {
    min_internal_stages: 2,
    suggested_stage_minutes: [s1, s2, s3],
  };
}

function splitBlockIntoExerciseSlots(blockId, blockDurationMin, desiredCount) {
  const maxSlotsPossible = Math.max(1, Math.min(5, Math.floor(blockDurationMin / 2)));
  const count = Math.max(1, Math.min(desiredCount, maxSlotsPossible));
  const weights = Array.from({ length: count }, () => 1);
  const durs = distributeExactMinutes(blockDurationMin, weights);
  return durs.map((dur, idx) => ({
    exercise_id: `${blockId}_ex_${idx + 1}`,
    duracion_min: dur,
    ...buildInternalStageTemplate(dur),
    assigned_resource_ids: [],
    assigned_movement_ids: [],
  }));
}

function scoreBlockForResource(block, resource) {
  const catTypeTitle = `${resource?.category || ''} ${resource?.type || ''} ${resource?.title || ''}`.toLowerCase();
  const usageNote = String(resource?.usage_note || '').toLowerCase();

  const isExplicitMusicCategory = /\b(musicalidad|m[uú]sica|roda|canto|coro|toques|instrumentos?|ladainha|corrido)\b/i.test(
    catTypeTitle
  );
  const isWarmup = /\b(calentamiento|activaci[oó]n|movilidad)\b/i.test(`${catTypeTitle} ${usageNote}`);
  const isFloor = /\b(suelo|acrobacia|a[uú]|rol[eê]|bananeira|macaco)\b/i.test(`${catTypeTitle} ${usageNote}`);
  const isExplicitGame = /\b(juego|juegos|din[aá]mica|l[uú]dic)\b/i.test(catTypeTitle);
  const isExplicitTech = /\b(t[eé]cnica|drill|secuencia|combate|parejas)\b/i.test(catTypeTitle);
  const isGameOrTech =
    isExplicitGame ||
    isExplicitTech ||
    /\b(esquiva|central|principal|aplicaci[oó]n)\b/i.test(`${catTypeTitle} ${usageNote}`);

  if (block.fase_tipo === 'recurso_profesor') return 100;
  if (isExplicitMusicCategory) {
    if (block.fase_tipo === 'musicalidad' || block.fase_tipo === 'roda_musicalidad') return 98;
    return 15;
  }
  if (isWarmup && block.fase_tipo === 'calentamiento') return 92;
  if (isFloor && block.fase_tipo === 'acrobacias_suelo') return 90;
  if (isExplicitGame && !isExplicitTech) {
    if (block.fase_tipo === 'juegos') return 98;
    if (block.fase_tipo === 'tecnica' || block.fase_tipo === 'angola') return 88;
    if (block.fase_tipo === 'roda_musicalidad') return 15;
  }
  if (isExplicitTech) {
    if (block.fase_tipo === 'tecnica' || block.fase_tipo === 'angola') return 98;
    if (block.fase_tipo === 'juegos') return 88;
    if (block.fase_tipo === 'roda_musicalidad') return 15;
  }
  if (isGameOrTech) {
    if (block.fase_tipo === 'juegos' || block.fase_tipo === 'tecnica' || block.fase_tipo === 'angola') return 96;
    if (block.fase_tipo === 'roda_musicalidad') return 15;
  }
  if (block.fase_tipo === 'juegos' || block.fase_tipo === 'tecnica' || block.fase_tipo === 'angola') return 82;
  if (block.fase_tipo === 'acrobacias_suelo') return 45;
  if (block.fase_tipo === 'calentamiento') return 35;
  return 20;
}

function scoreBlockForMovement(block) {
  if (block.fase_tipo === 'tecnica' || block.fase_tipo === 'angola') return 100;
  if (block.fase_tipo === 'recurso_profesor') return 90;
  if (block.fase_tipo === 'juegos') return 80;
  if (block.fase_tipo === 'acrobacias_suelo') return 60;
  if (block.fase_tipo === 'calentamiento') return 40;
  return 25;
}

function assignResourcesAndMovementsToSlots(blocks, context) {
  if (!Array.isArray(blocks) || blocks.length === 0) return;

  const selectedResources = Array.isArray(context.selectedResources) ? context.selectedResources : [];
  if (selectedResources.length > 0) {
    const orderedResources = [
      ...selectedResources.filter((r) => r.priority !== 'optional'),
      ...selectedResources.filter((r) => r.priority === 'optional'),
    ];
    const usedSlots = new Set();
    for (const res of orderedResources) {
      const sortedBlocks = [...blocks].sort(
        (a, b) => scoreBlockForResource(b, res) - scoreBlockForResource(a, res)
      );
      const targetBlock = sortedBlocks[0];
      if (!targetBlock || !Array.isArray(targetBlock.exercise_slots) || targetBlock.exercise_slots.length === 0) {
        continue;
      }
      const candidates = targetBlock.exercise_slots;
      let chosenSlot = candidates.find((s) => !usedSlots.has(s.exercise_id));
      if (!chosenSlot) {
        chosenSlot = [...candidates].sort(
          (a, b) => a.assigned_resource_ids.length - b.assigned_resource_ids.length
        )[0];
      }
      chosenSlot.assigned_resource_ids.push(res.resource_id);
      usedSlots.add(chosenSlot.exercise_id);
    }
  }

  const curriculumScope = String(context.curriculumScope || '');
  const selectedMovements = Array.isArray(context.selectedMovements) ? context.selectedMovements : [];
  if (curriculumScope === 'adulto_fiu' && selectedMovements.length > 0) {
    const orderedMovements = [
      ...selectedMovements.filter((m) => m.priority !== 'optional'),
      ...selectedMovements.filter((m) => m.priority === 'optional'),
    ];
    const sortedBlocks = [...blocks].sort(
      (a, b) => scoreBlockForMovement(b) - scoreBlockForMovement(a)
    );
    const primarySlots = [];
    for (const blk of sortedBlocks) {
      for (const s of blk.exercise_slots || []) {
        primarySlots.push(s);
      }
    }
    if (primarySlots.length > 0) {
      const preferredBlockSlots = (sortedBlocks[0]?.exercise_slots || []).length > 0
        ? sortedBlocks[0].exercise_slots
        : primarySlots;
      orderedMovements.forEach((mov, idx) => {
        const slot = preferredBlockSlots[idx % preferredBlockSlots.length];
        slot.assigned_movement_ids.push(mov.movement_id);
      });
    }
  }
}

function buildFlexibleTemporalBlueprint(context) {
  const durationMin = Number(context.durationMin || 60);
  const audience = String(context.audienceType || 'adultos');
  const focuses = Array.isArray(context.focuses) ? context.focuses : [];
  const focusesJoined = focuses.join(' ').toLowerCase();
  const resourcesCount = Array.isArray(context.selectedResources) ? context.selectedResources.length : 0;
  const includeRoda = context.includeMusicalityRoda !== false;

  const isMusicalityOnly =
    focuses.length > 0 &&
    focuses.every((f) => /musicalidad|roda/i.test(f));
  const isAngolaFocus = /angola/i.test(focusesJoined) || /angola/i.test(context.freeInstructions || '');
  const hasAcrobaciasFocus = /acrobacia/i.test(focusesJoined);
  const safeGroundSurface = context.space?.floorType === 'tatami' || context.space?.availableMats === true;

  let blockSpecs = [];

  if (context.allowAiComplementaryProposals === false && resourcesCount > 0) {
    // Strict teacher-resource-only blueprint (2..6 blocks)
    const blockCount = resourcesCount === 1 ? 2 : Math.min(6, Math.max(2, resourcesCount));
    const weights = Array.from({ length: blockCount }, (_, i) => (i === 0 ? 2 : 3));
    const durs = distributeExactMinutes(durationMin, weights);
    blockSpecs = durs.map((dur, idx) => {
      const res = context.selectedResources[Math.min(idx, resourcesCount - 1)];
      const isMusic = /musica|roda|canto/i.test(`${res.category || ''} ${res.title || ''}`);
      return {
        fase_tipo: isMusic ? 'musicalidad' : 'recurso_profesor',
        role_hint: `Bloque centrado en recurso de Pizarra (${res.title})`,
        duracion_min: dur,
        slots: 1,
      };
    });
  } else if (isMusicalityOnly) {
    // Flexible 3-4 block structure dedicated to Musicality & Roda (no forced combat/acrobatics)
    const rawSpecs =
      durationMin <= 45
        ? [
            { fase_tipo: 'musicalidad', role_hint: 'Pulso corporal, palmas y escucha de toques', weight: 12, slots: 1 },
            { fase_tipo: 'musicalidad', role_hint: 'Práctica instrumental guiada (Berimbau/Pandeiro/Atabaque)', weight: 18, slots: 2 },
            { fase_tipo: 'roda_musicalidad', role_hint: 'Roda cantada con rotación vocal', weight: 15, slots: 1 },
          ]
        : [
            { fase_tipo: 'calentamiento', role_hint: 'Activación rítmica y voz', weight: 10, slots: 1 },
            { fase_tipo: 'musicalidad', role_hint: 'Toques y cambios de ritmo', weight: 20, slots: 2 },
            { fase_tipo: 'musicalidad', role_hint: 'Canto coral y juego rítmico', weight: 18, slots: 2 },
            { fase_tipo: 'roda_musicalidad', role_hint: 'Roda aplicada con rotación musical', weight: 17, slots: 1 },
          ];
    const durs = distributeExactMinutes(durationMin, rawSpecs.map((s) => s.weight));
    blockSpecs = rawSpecs.map((s, i) => ({ ...s, duracion_min: durs[i] }));
  } else if (audience === 'infantil') {
    // Infantil: several brief dynamic exercises per main block, safe by surface/age
    if (durationMin <= 45) {
      const rawSpecs = includeRoda
        ? [
            { fase_tipo: 'calentamiento', role_hint: 'Calentamiento lúdico breve con movimiento simultáneo', weight: 9, slots: 2 },
            { fase_tipo: 'juegos', role_hint: 'Juegos motores y progresiones técnicas breves por niveles', weight: 18 + resourcesCount * 2, slots: Math.min(4, 2 + (resourcesCount > 0 ? 1 : 0)) },
            { fase_tipo: hasAcrobaciasFocus || safeGroundSurface ? 'acrobacias_suelo' : 'juegos', role_hint: 'Control corporal seguro y desplazamientos bajos', weight: 9, slots: 1 },
            { fase_tipo: 'roda_musicalidad', role_hint: 'Canción infantil y mini-roda dialogada', weight: 9, slots: 1 },
          ]
        : [
            { fase_tipo: 'calentamiento', role_hint: 'Calentamiento lúdico con reglas claras', weight: 10, slots: 2 },
            { fase_tipo: 'juegos', role_hint: 'Juegos motores y progresiones técnicas breves por niveles', weight: 23 + resourcesCount * 2, slots: Math.min(4, 2 + (resourcesCount > 0 ? 1 : 0)) },
            { fase_tipo: 'vuelta_calma', role_hint: 'Juego rítmico suave y cierre infantil', weight: 12, slots: 1 },
          ];
      const durs = distributeExactMinutes(durationMin, rawSpecs.map((s) => s.weight));
      blockSpecs = rawSpecs.map((s, i) => ({ ...s, duracion_min: durs[i] }));
    } else if (durationMin >= 80) {
      const rawSpecs = [
        { fase_tipo: 'calentamiento', role_hint: 'Calentamiento lúdico y activación simultánea', weight: 12, slots: 2 },
        { fase_tipo: 'juegos', role_hint: 'Juegos motores por niveles y progresión técnica independiente', weight: 26 + resourcesCount * 3, slots: Math.min(4, 2 + resourcesCount) },
        { fase_tipo: 'juegos', role_hint: 'Dinámica cooperativa o aplicación del enfoque / recurso', weight: 20, slots: 2 },
        { fase_tipo: 'acrobacias_suelo', role_hint: 'Movilidad en suelo segura acorde al espacio confirmado', weight: 16, slots: 2 },
        {
          fase_tipo: includeRoda ? 'roda_musicalidad' : 'vuelta_calma',
          role_hint: includeRoda ? 'Musicalidad infantil, canción real y mini-roda cuidada' : 'Juego calmo, respiración y refuerzo positivo',
          weight: 16,
          slots: 1,
        },
      ];
      const durs = distributeExactMinutes(durationMin, rawSpecs.map((s) => s.weight));
      blockSpecs = rawSpecs.map((s, i) => ({ ...s, duracion_min: durs[i] }));
    } else {
      // 50-79 min Infantil (default 60 / 75 min)
      const requestedMovHint =
        Array.isArray(context.requestedTechnicalMovements) && context.requestedTechnicalMovements.length > 0
          ? ` (${context.requestedTechnicalMovements.join(', ')})`
          : '';
      const hasTecnicaFocus =
        /t[eé]cnic/i.test(focusesJoined) ||
        (Array.isArray(context.requestedTechnicalMovements) && context.requestedTechnicalMovements.length >= 2);
      const hasJuegosFocus = /juego/i.test(focusesJoined);
      const rawSpecs = includeRoda
        ? hasTecnicaFocus && hasJuegosFocus
          ? [
              {
                fase_tipo: 'calentamiento',
                role_hint: 'Calentamiento lúdico de capoeira (ginga base, movilidad articular y señales simultáneas sin filas)',
                weight: 10,
                slots: 2,
              },
              {
                fase_tipo: 'tecnica',
                role_hint: `Progresiones técnicas reales de capoeira${requestedMovHint} diferenciadas por nivel sin filas (no usar progresion_suelo ni juegos genéricos)`,
                weight: 16,
                slots: 2,
              },
              {
                fase_tipo: 'juegos',
                role_hint: 'Juegos de capoeira aplicados sin filas ni eliminaciones + recurso obligatorio del profesor',
                weight: 12,
                slots: Math.min(3, Math.max(2, resourcesCount + 1)),
              },
              {
                fase_tipo: 'acrobacias_suelo',
                role_hint: 'Movimientos de suelo de capoeira seguros según superficie (preparación progresiva de Aú con apoyos de manos, Cocorinha y Rolê; cero volteretas)',
                weight: 11,
                slots: 2,
              },
              {
                fase_tipo: 'roda_musicalidad',
                role_hint: 'Musicalidad ejecutable (canto responsorial con canción real, palmas/pulso y mini-roda dialogada) + cierre positivo',
                weight: 11,
                slots: 1,
              },
            ]
          : [
              {
                fase_tipo: 'calentamiento',
                role_hint: 'Calentamiento lúdico de capoeira (ginga base, movilidad y señales simultáneas)',
                weight: 12,
                slots: 2,
              },
              {
                fase_tipo: 'juegos',
                role_hint: `Progresiones técnicas independientes de capoeira${requestedMovHint} + juegos técnicos aplicados sin filas y recurso del profesor`,
                weight: 24 + resourcesCount * 3,
                slots: Math.min(4, 2 + (resourcesCount > 0 ? 1 : 0)),
              },
              {
                fase_tipo: 'acrobacias_suelo',
                role_hint: 'Movimientos de suelo de capoeira seguros según superficie (Cocorinha, Rolê, Negativa, progresiones bajas de Aú)',
                weight: 12,
                slots: 2,
              },
              {
                fase_tipo: 'roda_musicalidad',
                role_hint: 'Musicalidad ejecutable (canto responsorial, palmas y mini-roda dialogada) + cierre positivo',
                weight: 12,
                slots: 1,
              },
            ]
        : [
            {
              fase_tipo: 'calentamiento',
              role_hint: 'Calentamiento lúdico de capoeira y activación simultánea',
              weight: 14,
              slots: 2,
            },
            {
              fase_tipo: 'juegos',
              role_hint: `Progresiones técnicas breves de capoeira${requestedMovHint} y juegos técnicos por niveles`,
              weight: 30 + resourcesCount * 3,
              slots: Math.min(4, 3),
            },
            {
              fase_tipo: 'vuelta_calma',
              role_hint: 'Control corporal en suelo seguro, estiramiento y cierre positivo',
              weight: 16,
              slots: 2,
            },
          ];
      const durs = distributeExactMinutes(durationMin, rawSpecs.map((s) => s.weight));
      blockSpecs = rawSpecs.map((s, i) => ({ ...s, duracion_min: durs[i] }));
    }
  } else {
    // Adultos / Mixto
    const mainFase = isAngolaFocus ? 'angola' : 'tecnica';
    if (durationMin <= 45) {
      const rawSpecs = includeRoda
        ? [
            { fase_tipo: 'calentamiento', role_hint: 'Movilidad articular y ginga progresiva', weight: 10, slots: 1 },
            { fase_tipo: mainFase, role_hint: 'Progresión técnica independiente y aplicación en parejas', weight: 20, slots: 2 },
            { fase_tipo: 'roda_musicalidad', role_hint: 'Roda cadenciada y canto', weight: 15, slots: 1 },
          ]
        : [
            { fase_tipo: 'calentamiento', role_hint: 'Movilidad articular y activación de base', weight: 10, slots: 1 },
            { fase_tipo: mainFase, role_hint: 'Progresión técnica y secuencias en parejas', weight: 25, slots: 2 },
            { fase_tipo: 'vuelta_calma', role_hint: 'Control técnico y vuelta a la calma', weight: 10, slots: 1 },
          ];
      const durs = distributeExactMinutes(durationMin, rawSpecs.map((s) => s.weight));
      blockSpecs = rawSpecs.map((s, i) => ({ ...s, duracion_min: durs[i] }));
    } else if (durationMin >= 85) {
      const thirdFase = hasAcrobaciasFocus && safeGroundSurface ? 'acrobacias_suelo' : 'juegos';
      const rawSpecs = [
        { fase_tipo: 'calentamiento', role_hint: 'Movilidad articular y ginga activa', weight: 14, slots: 1 },
        { fase_tipo: mainFase, role_hint: 'Progresiones técnicas independientes y secuencias en parejas', weight: 32, slots: 2 },
        { fase_tipo: thirdFase, role_hint: hasAcrobaciasFocus ? 'Progresión corporal en suelo segura' : 'Juego técnico estratégico y transiciones', weight: 18, slots: 2 },
        { fase_tipo: includeRoda ? 'roda_musicalidad' : 'musicalidad', role_hint: 'Musicalidad aplicada y roda continua', weight: 18, slots: 1 },
        { fase_tipo: 'vuelta_calma', role_hint: 'Recuperación y retroalimentación final', weight: 8, slots: 1 },
      ];
      const durs = distributeExactMinutes(durationMin, rawSpecs.map((s) => s.weight));
      blockSpecs = rawSpecs.map((s, i) => ({ ...s, duracion_min: durs[i] }));
    } else {
      const thirdFase = hasAcrobaciasFocus && safeGroundSurface ? 'acrobacias_suelo' : 'juegos';
      const rawSpecs = includeRoda
        ? [
            { fase_tipo: 'calentamiento', role_hint: 'Activación articular y base de ginga', weight: 12, slots: 1 },
            { fase_tipo: mainFase, role_hint: 'Progresión técnica y trabajo en parejas/secuencias', weight: 24, slots: 2 },
            { fase_tipo: thirdFase, role_hint: hasAcrobaciasFocus ? 'Control en suelo seguro según espacio' : 'Dinámica complementaria o autonomía', weight: 12, slots: 1 },
            { fase_tipo: 'roda_musicalidad', role_hint: 'Musicalidad tradicional y roda de treino', weight: 12, slots: 1 },
          ]
        : [
            { fase_tipo: 'calentamiento', role_hint: 'Movilidad articular y ginga progresiva', weight: 14, slots: 1 },
            { fase_tipo: mainFase, role_hint: 'Progresiones técnicas independientes y secuencias', weight: 30, slots: 2 },
            { fase_tipo: 'vuelta_calma', role_hint: 'Control corporal y estiramiento de cierre', weight: 16, slots: 1 },
          ];
      const durs = distributeExactMinutes(durationMin, rawSpecs.map((s) => s.weight));
      blockSpecs = rawSpecs.map((s, i) => ({ ...s, duracion_min: durs[i] }));
    }
  }

  const blocks = blockSpecs.map((spec, bi) => {
    const blockId = `blk_${bi + 1}`;
    return {
      block_id: blockId,
      fase_tipo: spec.fase_tipo,
      role_hint: spec.role_hint,
      duracion_min: spec.duracion_min,
      include_cancionero: spec.fase_tipo === 'musicalidad' || spec.fase_tipo === 'roda_musicalidad',
      exercise_slots: splitBlockIntoExerciseSlots(blockId, spec.duracion_min, spec.slots || 1),
    };
  });

  assignResourcesAndMovementsToSlots(blocks, context);

  return {
    total_duration_min: durationMin,
    blocks_count: blocks.length,
    blocks,
  };
}

module.exports = {
  distributeExactMinutes,
  buildFlexibleTemporalBlueprint,
};
