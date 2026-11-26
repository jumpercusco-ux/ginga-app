'use strict';

const HEURISTIC_PRIVACY_DISCLAIMER =
  'La sanitización heurística reduce el riesgo de exposición de datos personales, pero NO garantiza ausencia absoluta de PII en texto libre.';

const SAFE_CAPOEIRA_OR_DOMAIN_TERMS = new Set([
  'Adultos',
  'Angola',
  'Armada',
  'Atabaque',
  'Avanzado',
  'Avanzados',
  'Aú',
  'Au',
  'Bananeira',
  'Base',
  'Benguela',
  'Bento',
  'Berimbau',
  'Bloque',
  'Bênção',
  'Benção',
  'Cabecada',
  'Cabeçada',
  'Calentamiento',
  'Capoeira',
  'Cavalaria',
  'Chapa',
  'Clase',
  'Cocorinha',
  'Cru',
  'Crua',
  'Amarela',
  'Amarelo',
  'Domingo',
  'Ejercicio',
  'Entreno',
  'Esquiva',
  'Estaciones',
  'FIU',
  'Frente',
  'GINGA',
  'Ginga',
  'Grande',
  'Grupo',
  'Infantil',
  'Intermedio',
  'Intermedios',
  'Iúna',
  'Juego',
  'Juegos',
  'Jueves',
  'Kids',
  'Laranja',
  'Lua',
  'Lunes',
  'Macaco',
  'Martelo',
  'Martes',
  'Meia',
  'Miércoles',
  'Mixto',
  'Movilidad',
  'Musicalidad',
  'Negativa',
  'Niños',
  'Pandeiro',
  'Parejas',
  'Pizarra',
  'Plan',
  'Ponte',
  'Principiante',
  'Principiantes',
  'Queixada',
  'Rasteira',
  'Roda',
  'Rolê',
  'Role',
  'Secuencias',
  'Sábado',
  'São',
  'Tatami',
  'Terreiro',
  'Todos',
  'Técnica',
  'Verde',
  'Viernes',
  'Vuelta',
]);

const EMAIL_RE = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
const HANDLE_RE = /(?<!\w)@[A-Za-z0-9_.-]{2,}/g;
const EXPLICIT_ID_RE =
  /\b(?:uid|user_id|alumno_id|dni|ce|pasaporte|doc(?:umento)?)(?:\s*[:=#]\s*[A-Za-z0-9_-]{4,}|\s+(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]{4,})\b/gi;
const DATE_RE = /\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b/g;
const PHONE_RE = /(?:\+?\d[\d\s().-]{6,}\d)/g;
const URL_RE = /\bhttps?:\/\/[^\s"'<>]+/gi;

const NICKNAME_PHRASE_RE =
  /\b(?:le\s+dicen|apodo|apodado|apodada|alias)\s+["'“”«]?([A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9_-]{2,}(?:\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9_-]{2,})?)["'“”»]?/gi;

const ROLE_NAMED_PERSON_RE =
  /\b([Ee]l\s+alumno|[Ll]a\s+alumna|[Aa]lumno|[Aa]lumna|[Ee]studiante|[Nn]iño|[Nn]iña|[Mm]enor|[Cc]hico|[Cc]hica|[Hh]ijo|[Hh]ija|[Mm]amá|[Pp]apá|[Mm]adre|[Pp]adre|[Aa]poderado|[Tt]utor|[Ss]r\.?|[Ss]ra\.?)\s+(?:de\s+)?([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}(?:\s+[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}){0,2})\b/g;

const MULTI_WORD_CAP_RE =
  /\b([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}(?:\s+(?:de|del|la|y)\s+)?(?:\s+[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}){1,2})\b/g;

const PREP_SINGLE_NAME_RE =
  /\b([Cc]on|[Pp]ara|[Ss]obre|[Jj]unto\s+a)\s+([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{2,})\b/g;

const SUBJECT_VERB_NAME_RE =
  /\b([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{2,})\s+(necesita|tuvo|mejoró|avanzó|logró|presentó|faltó|mostró|mantuvo|perdió|debe|pidió|llegó|tiene|está|hizo|entrenó|lloró|se\s+cansó)\b/g;

const NON_NAME_LOWERCASE_SUBJECTS = new Set([
  'grupo',
  'clase',
  'todos',
  'algunos',
  'varios',
  'nadie',
  'quien',
  'cada',
  'ninguno',
  'principiantes',
  'intermedios',
  'avanzados',
  'niños',
  'adultos',
  'alumnos',
  'parejas',
  'gente',
  'equipo',
  'bloque',
  'ejercicio',
]);

function isSafeTerm(word) {
  if (!word) return true;
  if (SAFE_CAPOEIRA_OR_DOMAIN_TERMS.has(word)) return true;
  const normalizedCap = word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
  return SAFE_CAPOEIRA_OR_DOMAIN_TERMS.has(normalizedCap) || NON_NAME_LOWERCASE_SUBJECTS.has(word.toLowerCase());
}

function sanitizeFreeTextServer(raw, { maxLength = 600 } = {}) {
  let out = String(raw || '').replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, ' ').trim();
  if (!out) {
    return {
      text: '',
      redactionsCount: 0,
      redactionCategories: [],
      truncated: false,
      heuristicDisclaimer: HEURISTIC_PRIVACY_DISCLAIMER,
    };
  }

  let redactionsCount = 0;
  const categories = new Set();
  const track = (cat) => {
    redactionsCount += 1;
    categories.add(cat);
  };

  out = out.replace(URL_RE, () => {
    track('url');
    return '[enlace_omitido]';
  });
  out = out.replace(EMAIL_RE, () => {
    track('email');
    return '[correo_omitido]';
  });
  out = out.replace(HANDLE_RE, () => {
    track('handle');
    return '[cuenta_omitida]';
  });
  out = out.replace(EXPLICIT_ID_RE, () => {
    track('explicit_id');
    return '[id_omitido]';
  });
  out = out.replace(DATE_RE, () => {
    track('date');
    return '[fecha_omitida]';
  });
  out = out.replace(PHONE_RE, (token) => {
    const digits = (token.match(/\d/g) || []).length;
    if (digits >= 7) {
      track('phone');
      return '[telefono_omitido]';
    }
    return token;
  });

  out = out.replace(NICKNAME_PHRASE_RE, (full, nick) => {
    if (isSafeTerm(nick)) return full;
    track('nickname');
    return '[apodo_omitido]';
  });

  out = out.replace(ROLE_NAMED_PERSON_RE, (full, role, name) => {
    const first = String(name || '').trim().split(/\s+/)[0];
    if (isSafeTerm(first)) return full;
    track('role_named_person');
    return `${role} [participante]`;
  });

  out = out.replace(MULTI_WORD_CAP_RE, (full, phrase) => {
    const capWords = phrase.match(/[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]{1,}/g) || [];
    if (capWords.length < 2) return phrase;
    const unsafeCount = capWords.filter((w) => !SAFE_CAPOEIRA_OR_DOMAIN_TERMS.has(w)).length;
    if (unsafeCount >= 2) {
      track('multi_word_name');
      return '[participante]';
    }
    return phrase;
  });

  out = out.replace(PREP_SINGLE_NAME_RE, (full, prep, word) => {
    if (isSafeTerm(word)) return full;
    track('preposition_name');
    return `${prep} [participante]`;
  });

  out = out.replace(SUBJECT_VERB_NAME_RE, (full, word, verb) => {
    if (isSafeTerm(word)) return full;
    track('subject_verb_name');
    return `[participante] ${verb}`;
  });

  let truncated = false;
  if (out.length > maxLength) {
    out = out.slice(0, maxLength).trim();
    truncated = true;
  }

  return {
    text: out,
    redactionsCount,
    redactionCategories: [...categories],
    truncated,
    heuristicDisclaimer: HEURISTIC_PRIVACY_DISCLAIMER,
  };
}

function sanitizeStringListServer(items, opts = {}) {
  const results = [];
  let totalRedactions = 0;
  const categories = new Set();

  for (const item of Array.isArray(items) ? items : []) {
    const res = sanitizeFreeTextServer(item, opts);
    if (res.text) {
      results.push(res.text);
    }
    totalRedactions += res.redactionsCount;
    for (const c of res.redactionCategories) categories.add(c);
  }

  return {
    items: results,
    redactionsCount: totalRedactions,
    redactionCategories: [...categories],
  };
}

const INJECTION_PATTERNS = [
  { code: 'ignore_instructions', re: /ignora(?:r)?\s+(?:todas?\s+)?(?:las\s+)?(?:reglas|instrucciones|sistema)/i },
  { code: 'ignore_previous_en', re: /ignore\s+(?:all\s+)?(?:previous|prior)\s+instructions/i },
  { code: 'role_override', re: /\b(?:act\s+as|eres\s+ahora|olvida\s+tu\s+rol|system\s*prompt)\b/i },
  { code: 'curriculum_override', re: /\b(?:usa|agrega|incluye)\s+(?:desequilibrante|espelho_cruz|au_chibata_pulado|curr[ií]culo\s+adulto\s+para\s+ni[ñn]os)\b/i },
  { code: 'json_schema_override', re: /\b(?:no\s+devuelvas\s+json|devuelve\s+markdown|omitir\s+validaci[oó]n)\b/i },
];

function detectPromptInjection(text) {
  const source = String(text || '');
  const signals = [];
  for (const pat of INJECTION_PATTERNS) {
    if (pat.re.test(source)) {
      signals.push(pat.code);
    }
  }
  const neutralized = source
    .replace(/```/g, "'''")
    .replace(/<\/?(?:system|assistant|developer|tool)[^>]*>/gi, '[etiqueta_neutralizada]');

  return {
    hasInjectionSignal: signals.length > 0,
    signals,
    neutralizedText: neutralized,
  };
}

const FORBIDDEN_LLM_KEY_NAMES = new Set([
  'uid',
  'user_id',
  'instructor_id',
  'actor_id',
  'clase_id',
  'group_id',
  'request_id',
  'source_session_id',
  'plan_id',
  'email',
  'telefono',
  'phone',
  'url',
]);

function inspectPayloadForForbiddenKeysOrUrls(node, pathPrefix = 'root', violations = []) {
  if (node === null || node === undefined) return violations;
  if (typeof node === 'string') {
    if (/\bhttps?:\/\//i.test(node)) {
      violations.push(`${pathPrefix}:contains_raw_url`);
    }
    return violations;
  }
  if (Array.isArray(node)) {
    for (let i = 0; i < node.length; i++) {
      inspectPayloadForForbiddenKeysOrUrls(node[i], `${pathPrefix}[${i}]`, violations);
    }
    return violations;
  }
  if (typeof node === 'object') {
    for (const [k, v] of Object.entries(node)) {
      if (FORBIDDEN_LLM_KEY_NAMES.has(k)) {
        violations.push(`${pathPrefix}.${k}:forbidden_internal_or_url_key`);
      }
      inspectPayloadForForbiddenKeysOrUrls(v, `${pathPrefix}.${k}`, violations);
    }
  }
  return violations;
}

function scanResidualPiiHeuristic(text) {
  const s = String(text || '');
  const hits = [];
  if (EMAIL_RE.test(s)) hits.push('email');
  EMAIL_RE.lastIndex = 0;
  if (EXPLICIT_ID_RE.test(s)) hits.push('explicit_id');
  EXPLICIT_ID_RE.lastIndex = 0;
  if (DATE_RE.test(s)) hits.push('date');
  DATE_RE.lastIndex = 0;
  const phoneMatches = s.match(PHONE_RE) || [];
  if (phoneMatches.some((t) => (t.match(/\d/g) || []).length >= 7)) {
    hits.push('phone');
  }
  return {
    cleanHeuristic: hits.length === 0,
    hits,
    disclaimer: HEURISTIC_PRIVACY_DISCLAIMER,
  };
}

module.exports = {
  HEURISTIC_PRIVACY_DISCLAIMER,
  SAFE_CAPOEIRA_OR_DOMAIN_TERMS,
  sanitizeFreeTextServer,
  sanitizeStringListServer,
  detectPromptInjection,
  inspectPayloadForForbiddenKeysOrUrls,
  scanResidualPiiHeuristic,
};
