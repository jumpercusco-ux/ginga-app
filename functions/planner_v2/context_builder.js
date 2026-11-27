'use strict';

const { PlannerV2Error } = require('./errors');
const {
  getMovement,
  isEligibleAdultoMovement,
  getCordaMeta,
  getCompactCatalogSlice,
} = require('./curriculum_catalog_loader');
const {
  sanitizeFreeTextServer,
  sanitizeStringListServer,
  detectPromptInjection,
  inspectPayloadForForbiddenKeysOrUrls,
} = require('./pii_and_injection_guard');
const { buildFlexibleTemporalBlueprint } = require('./temporal_planner');

const FORBIDDEN_TOP_LEVEL_CLIENT_KEYS = [
  'provider',
  'provider_mode',
  'model',
  'fallback_model',
  'max_repair_attempts',
  'max_tokens',
  'budget',
  'quota',
  'permissions',
  'roles',
  'custom_claims',
  'bypass_auth',
  'allow_local_bypass',
];

const FORBIDDEN_GENERATION_OPTION_KEYS = [
  'provider',
  'provider_mode',
  'model',
  'fallback_model',
  'max_repair_attempts',
  'max_tokens',
  'budget',
  'quota',
  'permissions',
  'bypass_auth',
];

const VALID_AUDIENCES = new Set(['adultos', 'infantil', 'mixto']);
const VALID_SCOPES = new Set([
  'adulto_fiu',
  'infantil_fiu_pending',
  'mixed_no_official_track',
  'none_manual',
]);
const VALID_FLOOR_TYPES = new Set(['tatami', 'madera', 'cemento', 'exterior', 'pasto', 'desconocido']);
const VALID_SPACE_SIZES = new Set(['amplio', 'mediano', 'reducido', 'desconocido']);

const CAPOEIRA_MOVEMENT_EXTRACTORS = [
  { name: 'Ginga', re: /\bginga\b/i },
  { name: 'Armada', re: /\barmada\b/i },
  { name: 'Aú', re: /\bau\b/i },
  { name: 'Cocorinha', re: /\bcocorinha\b/i },
  { name: 'Esquiva lateral', re: /\besquiva\s+lateral\b/i },
  { name: 'Esquiva básica', re: /\besquiva\s+basica\b/i },
  { name: 'Esquiva baixa', re: /\besquiva\s+baixa\b/i },
  { name: 'Esquiva', re: /\besquivas?\b/i },
  { name: 'Queixada', re: /\bqueixada\b/i },
  { name: 'Meia-lua de frente', re: /\bmeia[-\s]?lua\s+de\s+frente\b/i },
  { name: 'Meia-lua de compasso', re: /\bmeia[-\s]?lua\s+de\s+compasso\b/i },
  { name: 'Rolê', re: /\brole\b/i },
  { name: 'Negativa', re: /\bnegativa\b/i },
  { name: 'Bênção', re: /\bbencao\b/i },
  { name: 'Martelo', re: /\bmartelo\b/i },
  { name: 'Chapa', re: /\bchapa\b/i },
  { name: 'Macaco', re: /\bmacaco\b/i },
];

function extractRequestedTechnicalMovements(objectives, freeInstructions) {
  const combined = [...(Array.isArray(objectives) ? objectives : []), String(freeInstructions || '')].join(' ');
  // Normalize diacritics to ASCII so JS \b word boundaries work reliably on "Aú", "Rolê", "Bênção".
  const asciiCombined = combined
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
  const found = [];
  for (const item of CAPOEIRA_MOVEMENT_EXTRACTORS) {
    if (item.name === 'Esquiva' && found.some((m) => m.startsWith('Esquiva '))) {
      continue;
    }
    if (item.re.test(asciiCombined)) {
      found.push(item.name);
    }
  }
  return found;
}

function detectSimultaneousParticipationRequested(audienceType, objectives, freeInstructions) {
  if (audienceType === 'infantil') return true;
  const combined = [...(Array.isArray(objectives) ? objectives : []), String(freeInstructions || '')].join(' ');
  return /simult[aá]ne|sin\s+filas?|sin\s+esperas?|sin\s+colas?|sin\s+elimin/i.test(combined);
}

function assertNoClientPolicyOverrides(request) {
  const violated = [];
  for (const key of FORBIDDEN_TOP_LEVEL_CLIENT_KEYS) {
    if (Object.prototype.hasOwnProperty.call(request, key)) {
      violated.push(key);
    }
  }
  if (request.generation_options && typeof request.generation_options === 'object') {
    for (const key of FORBIDDEN_GENERATION_OPTION_KEYS) {
      if (Object.prototype.hasOwnProperty.call(request.generation_options, key)) {
        violated.push(`generation_options.${key}`);
      }
    }
  }
  if (violated.length > 0) {
    throw new PlannerV2Error(
      'FORBIDDEN_CLIENT_POLICY_OVERRIDE',
      `El cliente no puede definir ni sobrescribir políticas del motor (${violated.join(', ')}).`,
      { httpStatus: 403, details: { rejected_fields: violated } }
    );
  }
}

function defaultScopeForAudience(audience) {
  if (audience === 'adultos') return 'adulto_fiu';
  if (audience === 'infantil') return 'infantil_fiu_pending';
  return 'mixed_no_official_track';
}

function normalizeSpaceAndConditions(request) {
  const rawSpace = request.space_context && typeof request.space_context === 'object' ? request.space_context : {};
  const rawFloor = typeof rawSpace.floor_type === 'string' ? rawSpace.floor_type.trim().toLowerCase() : '';
  const floorType = VALID_FLOOR_TYPES.has(rawFloor) ? rawFloor : 'desconocido';

  const rawSize = typeof rawSpace.space_size === 'string' ? rawSpace.space_size.trim().toLowerCase() : '';
  const spaceSize = VALID_SPACE_SIZES.has(rawSize) ? rawSize : 'desconocido';

  // Never assume colchonetas or tatami when unknown
  const availableMats = typeof rawSpace.available_mats === 'boolean' ? rawSpace.available_mats : null;

  const rawInstructors =
    rawSpace.instructors_available !== undefined
      ? rawSpace.instructors_available
      : request.session_config?.instructors_available;

  let instructorsAvailable = 1;
  let instructorsSource = 'conservative_default';
  if (rawInstructors !== undefined && rawInstructors !== null) {
    const parsed = Number(rawInstructors);
    if (!Number.isInteger(parsed) || parsed < 1 || parsed > 10) {
      throw new PlannerV2Error(
        'INVALID_REQUEST',
        'instructors_available debe ser un entero entre 1 y 10.',
        { httpStatus: 400 }
      );
    }
    instructorsAvailable = parsed;
    instructorsSource = 'explicit';
  }

  return {
    spaceSize,
    floorType,
    availableMats,
    instructorsAvailable,
    instructorsSource,
    spaceNotesRaw: typeof rawSpace.space_notes === 'string' ? rawSpace.space_notes : '',
  };
}

/**
 * Validates client request against server FIU catalog & resource repository,
 * applies PII minimization + prompt injection defense, and emits a clean context
 * with zero internal user/group IDs and zero raw URLs in `llmPayloadContext`.
 */
async function buildValidatedContext({
  request,
  actor,
  catalog,
  resourceRepository,
}) {
  if (!request || typeof request !== 'object') {
    throw new PlannerV2Error('INVALID_REQUEST', 'El cuerpo de la solicitud es inválido.', { httpStatus: 400 });
  }

  assertNoClientPolicyOverrides(request);

  const groupCtx = request.group_context || {};
  const sessionCfg = request.session_config || {};
  const currCtx = request.curriculum_context || {};

  const audienceType = String(groupCtx.audience_type || 'adultos').trim().toLowerCase();
  if (!VALID_AUDIENCES.has(audienceType)) {
    throw new PlannerV2Error('INVALID_REQUEST', `audience_type inválido: ${audienceType}`, { httpStatus: 400 });
  }

  const curriculumScope = currCtx.scope
    ? String(currCtx.scope).trim()
    : defaultScopeForAudience(audienceType);
  if (!VALID_SCOPES.has(curriculumScope)) {
    throw new PlannerV2Error('INVALID_REQUEST', `curriculum_context.scope inválido: ${curriculumScope}`, {
      httpStatus: 400,
    });
  }

  // Enforce non-automatic adult curriculum fallback for Infantil / Mixto
  if (audienceType !== 'adultos' && curriculumScope === 'adulto_fiu') {
    throw new PlannerV2Error(
      'INVALID_REQUEST',
      'No se permite aplicar el currículo Adulto FIU a grupos infantil o mixto.',
      { httpStatus: 400 }
    );
  }

  const durationMin = Number(sessionCfg.duration_min ?? 60);
  if (!Number.isInteger(durationMin) || durationMin < 20 || durationMin > 180) {
    throw new PlannerV2Error('INVALID_REQUEST', 'duration_min debe ser un entero entre 20 y 180 minutos.', {
      httpStatus: 400,
    });
  }

  const participants = Number(groupCtx.estimated_participants ?? 10);
  if (!Number.isInteger(participants) || participants < 1 || participants > 80) {
    throw new PlannerV2Error('INVALID_REQUEST', 'estimated_participants debe ser un entero entre 1 y 80.', {
      httpStatus: 400,
    });
  }

  const ageMin = Number(groupCtx.age_min ?? (audienceType === 'infantil' ? 6 : 18));
  const ageMax = Number(groupCtx.age_max ?? (audienceType === 'infantil' ? 12 : 45));

  const rawExp = groupCtx.experience_distribution || {};
  const expDist = {
    principiantes: Math.max(0, Number(rawExp.principiantes ?? participants) || 0),
    intermedios: Math.max(0, Number(rawExp.intermedios ?? 0) || 0),
    avanzados: Math.max(0, Number(rawExp.avanzados ?? 0) || 0),
    manually_confirmed: rawExp.manually_confirmed === true,
  };

  const space = normalizeSpaceAndConditions(request);

  // Materials: do NOT assume materials if client omitted them
  const materialsKnown = Array.isArray(sessionCfg.materials);
  const materials = materialsKnown
    ? [...new Set(sessionCfg.materials.map((m) => String(m).trim()).filter(Boolean))]
    : [];

  const focuses = Array.isArray(sessionCfg.focuses) && sessionCfg.focuses.length > 0
    ? sessionCfg.focuses.map((f) => String(f).trim()).filter(Boolean)
    : sessionCfg.focus
      ? [String(sessionCfg.focus).trim()]
      : ['Técnica'];

  const targetCordaIndex =
    curriculumScope === 'adulto_fiu'
      ? Math.max(1, Math.min(6, Number(currCtx.target_corda_index ?? 1) || 1))
      : null;

  // Validate selected FIU movements
  const rawMovements = Array.isArray(request.selected_movements) ? request.selected_movements : [];
  const validatedMovements = [];
  const excludedOptionalInputs = [];

  for (const item of rawMovements) {
    const movId = String(item?.movement_id || '').trim();
    const priority = item?.priority === 'optional' ? 'optional' : 'required';

    if (curriculumScope !== 'adulto_fiu') {
      if (priority === 'required') {
        throw new PlannerV2Error(
          'INVALID_REQUIRED_MOVEMENT',
          `El movimiento FIU obligatorio '${movId || 'sin_id'}' no puede usarse con el alcance curricular '${curriculumScope}'.`,
          { httpStatus: 400, details: { movement_id: movId, curriculum_scope: curriculumScope } }
        );
      }
      excludedOptionalInputs.push({ kind: 'movement', id: movId, reason: 'scope_not_adulto_fiu' });
      continue;
    }

    const catalogMov = getMovement(catalog, movId);
    const eligible = isEligibleAdultoMovement(catalog, movId);
    if (!catalogMov || !eligible) {
      if (priority === 'required') {
        throw new PlannerV2Error(
          'INVALID_REQUIRED_MOVEMENT',
          `El movimiento curricular obligatorio '${movId || 'desconocido'}' no existe o no es elegible para el planificador IA.`,
          {
            httpStatus: 400,
            details: {
              movement_id: movId,
              exists: Boolean(catalogMov),
              ai_planner_eligible: catalogMov ? catalogMov.ai_planner_eligible : false,
            },
          }
        );
      }
      excludedOptionalInputs.push({
        kind: 'movement',
        id: movId,
        reason: catalogMov ? 'not_ai_planner_eligible' : 'not_found',
      });
      continue;
    }

    validatedMovements.push({
      movement_id: catalogMov.movement_id,
      canonical_name: catalogMov.canonical_name,
      category_id: catalogMov.category_id,
      entry_kind: catalogMov.entry_kind,
      first_introduced_adulto: catalogMov.first_introduced_adulto,
      priority,
    });
  }

  // Validate selected teacher Pizarra resources via repository (existence + ownership)
  const rawResources = Array.isArray(request.selected_resources) ? request.selected_resources : [];
  const requestedResourceIds = rawResources.map((r) => String(r?.resource_id || '').trim()).filter(Boolean);
  const storedResourcesMap =
    requestedResourceIds.length > 0 && resourceRepository
      ? await resourceRepository.getResourcesByIds(requestedResourceIds, actor.actorId)
      : new Map();

  let totalRedactions = 0;
  const redactionCategories = new Set();
  const injectionSignals = new Set();

  const cleanText = (value, maxLength = 450) => {
    const pii = sanitizeFreeTextServer(value, { maxLength });
    totalRedactions += pii.redactionsCount;
    for (const c of pii.redactionCategories) redactionCategories.add(c);
    const inj = detectPromptInjection(pii.text);
    for (const s of inj.signals) injectionSignals.add(s);
    return inj.neutralizedText;
  };

  const cleanList = (arr, maxLength = 200) => {
    const san = sanitizeStringListServer(arr, { maxLength });
    totalRedactions += san.redactionsCount;
    for (const c of san.redactionCategories) redactionCategories.add(c);
    return san.items.map((item) => {
      const inj = detectPromptInjection(item);
      for (const s of inj.signals) injectionSignals.add(s);
      return inj.neutralizedText;
    });
  };

  const validatedResources = [];
  for (const reqRes of rawResources) {
    const resId = String(reqRes?.resource_id || '').trim();
    const priority = reqRes?.priority === 'optional' ? 'optional' : 'required';

    if (!resId) {
      if (priority === 'required') {
        throw new PlannerV2Error(
          'INVALID_OR_UNAUTHORIZED_REQUIRED_RESOURCE',
          'Se recibió un recurso obligatorio sin resource_id válido.',
          { httpStatus: 400 }
        );
      }
      excludedOptionalInputs.push({ kind: 'resource', id: '', reason: 'missing_id' });
      continue;
    }

    const stored = storedResourcesMap instanceof Map ? storedResourcesMap.get(resId) : storedResourcesMap?.[resId];

    if (!stored) {
      if (priority === 'required') {
        throw new PlannerV2Error(
          'INVALID_OR_UNAUTHORIZED_REQUIRED_RESOURCE',
          `El recurso obligatorio '${resId}' no existe o no está disponible para este instructor.`,
          { httpStatus: 404, details: { resource_id: resId } }
        );
      }
      excludedOptionalInputs.push({ kind: 'resource', id: resId, reason: 'not_found' });
      continue;
    }

    const isOwner = stored.ownerId === actor.actorId || stored.shared === true;
    if (!isOwner) {
      throw new PlannerV2Error(
        'UNAUTHORIZED_RESOURCE',
        `No tienes autorización para usar el recurso '${resId}'.`,
        { httpStatus: 403, details: { resource_id: resId } }
      );
    }

    const hasExternalVideo =
      stored.mediaKind === 'video' ||
      stored.mediaKind === 'enlace' ||
      reqRes.has_external_video === true ||
      Boolean(stored.url && String(stored.url).trim());

    validatedResources.push({
      resource_id: resId,
      title: cleanText(stored.title || reqRes.title || 'Recurso de Pizarra', 140),
      type: String(stored.type || reqRes.type || 'nota'),
      category: String(stored.category || reqRes.category || 'General'),
      notes: cleanText(stored.notes ?? reqRes.notes ?? '', 400),
      usage_note: cleanText(reqRes.usage_note || '', 240),
      has_external_video: hasExternalVideo,
      // Explicitly record that external videos are NOT visually inspected
      video_visual_inspected: false,
      priority,
    });
  }

  // Build sanitized continuity context without internal IDs
  let sanitizedContinuity = null;
  if (request.continuity_context && typeof request.continuity_context === 'object') {
    const cc = request.continuity_context;
    sanitizedContinuity = {
      audience_type: cc.audience_type || audienceType,
      completed_exercises: cleanList(cc.completed_exercises, 180),
      skipped_exercises: cleanList(cc.skipped_exercises, 180),
      pending_exercises: cleanList(cc.pending_exercises, 180),
      worked_movements: cleanList(cc.worked_movements, 100),
      group_response: cleanText(cc.group_response || '', 240),
      difficulties: cleanText(cc.difficulties || '', 360),
      teacher_observations: cleanText(cc.teacher_observations || '', 360),
      reinforce_content: cleanText(cc.reinforce_content || '', 300),
      continuity_proposal: cleanText(cc.continuity_proposal || '', 360),
    };
  }

  const sanitizedRecentHistory = Array.isArray(request.recent_history_summary)
    ? request.recent_history_summary.slice(0, 3).map((h) => ({
        session_recency: cleanText(h.session_recency || h.session_date_bucket || 'reciente', 30),
        worked_movements: cleanList(h.worked_movements, 80),
        focuses: cleanList(h.focuses, 60),
      }))
    : [];

  const allowAiComplementaryProposals = sessionCfg.allow_ai_complementary_proposals !== false;
  const includeMusicalityRoda =
    sessionCfg.include_musicality_roda === undefined
      ? focuses.some((f) => /roda|musicalidad|angola/i.test(f)) || audienceType !== 'mixto'
      : sessionCfg.include_musicality_roda === true;

  const cordaMeta = targetCordaIndex ? getCordaMeta(catalog, targetCordaIndex) : null;
  const compactCatalogSlice =
    curriculumScope === 'adulto_fiu' ? getCompactCatalogSlice(catalog, targetCordaIndex, 24) : [];

  const sanitizedFreeInstructions = cleanText(sessionCfg.free_instructions || '', 600);
  const sanitizedObjectives = cleanList(sessionCfg.objectives, 200);
  const sanitizedGroupLabel = cleanText(groupCtx.group_label || `Grupo ${audienceType}`, 80);
  const sanitizedSpaceNotes = cleanText(space.spaceNotesRaw || '', 240);
  const sanitizedContinuitySummary = cleanText(request.continuity_summary || '', 300);
  const requestedTechnicalMovements = extractRequestedTechnicalMovements(
    sanitizedObjectives,
    sanitizedFreeInstructions
  );
  const simultaneousParticipationRequested = detectSimultaneousParticipationRequested(
    audienceType,
    sanitizedObjectives,
    sanitizedFreeInstructions
  );

  // LLM-safe payload strictly stripped of internal UIDs, group IDs, session IDs, request IDs, and raw URLs
  const llmPayloadContext = {
    contract_version: '2.1.0',
    group_profile: {
      group_label: sanitizedGroupLabel,
      audience_type: audienceType,
      age_min: ageMin,
      age_max: ageMax,
      estimated_participants: participants,
      experience_distribution: expDist,
      observed_cordas_summary:
        groupCtx.observed_cordas_summary && typeof groupCtx.observed_cordas_summary === 'object'
          ? groupCtx.observed_cordas_summary
          : {},
    },
    curriculum_context: {
      scope: curriculumScope,
      ...(targetCordaIndex
        ? {
            target_corda_index: targetCordaIndex,
            target_corda_id: cordaMeta?.corda_id || `adulto_corda_0${targetCordaIndex}`,
            target_corda_name: cordaMeta?.nombre_manual || `Corda ${targetCordaIndex}`,
          }
        : {}),
      auto_adult_fallback_blocked: true,
      fiu_catalog_slice: compactCatalogSlice,
    },
    space_conditions: {
      space_size: space.spaceSize,
      floor_type: space.floorType,
      available_mats: space.availableMats,
      instructors_available: space.instructorsAvailable,
      instructors_source: space.instructorsSource,
      ...(sanitizedSpaceNotes ? { space_notes: sanitizedSpaceNotes } : {}),
    },
    session_config: {
      duration_min: durationMin,
      focuses,
      focus: focuses.join(' · '),
      objectives: sanitizedObjectives,
      requested_technical_movements: requestedTechnicalMovements,
      simultaneous_participation_requested: simultaneousParticipationRequested,
      materials_known: materialsKnown,
      materials,
      include_musicality_roda: includeMusicalityRoda,
      allow_ai_complementary_proposals: allowAiComplementaryProposals,
    },
    selected_movements: validatedMovements,
    selected_resources: validatedResources,
    ...(sanitizedContinuity ? { continuity_context: sanitizedContinuity } : {}),
    ...(sanitizedContinuitySummary ? { continuity_summary: sanitizedContinuitySummary } : {}),
    ...(sanitizedRecentHistory.length > 0 ? { recent_history_summary: sanitizedRecentHistory } : {}),
    untrusted_teacher_input: {
      free_instructions: sanitizedFreeInstructions,
    },
  };

  const temporalBlueprint = buildFlexibleTemporalBlueprint({
    durationMin,
    audienceType,
    curriculumScope,
    focuses,
    requestedTechnicalMovements,
    selectedMovements: validatedMovements,
    selectedResources: validatedResources,
    includeMusicalityRoda,
    allowAiComplementaryProposals,
    freeInstructions: sanitizedFreeInstructions,
    space,
  });

  llmPayloadContext.temporal_blueprint = temporalBlueprint;

  const payloadViolations = inspectPayloadForForbiddenKeysOrUrls(llmPayloadContext, 'llmPayloadContext');
  if (payloadViolations.length > 0) {
    throw new PlannerV2Error(
      'INVALID_REQUEST',
      'Se detectaron identificadores internos o URLs no permitidos en el payload hacia IA.',
      { httpStatus: 500, details: { payloadViolations } }
    );
  }

  return {
    requestId: String(request.request_id || '').trim(),
    creationMode: request.creation_mode === 'rápida' ? 'rápida' : 'avanzada',
    audienceType,
    curriculumScope,
    targetCordaIndex,
    cordaMeta,
    durationMin,
    temporalBlueprint,
    participants,
    ageMin,
    ageMax,
    expDist,
    focuses,
    focusLabel: focuses.join(' · '),
    objectives: sanitizedObjectives,
    requestedTechnicalMovements,
    simultaneousParticipationRequested,
    materialsKnown,
    materials,
    includeMusicalityRoda,
    allowAiComplementaryProposals,
    freeInstructions: sanitizedFreeInstructions,
    space,
    instructorsAvailable: space.instructorsAvailable,
    selectedMovements: validatedMovements,
    selectedResources: validatedResources,
    excludedOptionalInputs,
    continuityContext: sanitizedContinuity,
    continuitySummary: sanitizedContinuitySummary,
    recentHistory: sanitizedRecentHistory,
    catalogSlice: compactCatalogSlice,
    sanitizationMeta: {
      piiRedactionsCount: totalRedactions,
      redactionCategories: [...redactionCategories],
      injectionSignals: [...injectionSignals],
    },
    llmPayloadContext,
  };
}

module.exports = {
  assertNoClientPolicyOverrides,
  buildValidatedContext,
  extractRequestedTechnicalMovements,
  detectSimultaneousParticipationRequested,
};
