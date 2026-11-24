#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const CATALOG_PATH = path.resolve(__dirname, '../data/curriculum/fiu_adulto_v1.json');

function validateCatalogData(data) {
  const errors = [];
  const check = (cond, msg) => {
    if (!cond) errors.push(msg);
  };

  // 1. Claves raíz obligatorias
  const requiredKeys = [
    'schema_version',
    'catalog_id',
    'status',
    'pedagogical_decisions_applied',
    'pending_technical_review_movement_ids',
    'source',
    'tracks',
    'category_taxonomy',
    'movements',
    'curriculum_blocks',
    'cordas',
    'tutorial_mapping',
    'glossary_crosswalk',
    'review_flags',
  ];
  for (const key of requiredKeys) {
    check(Object.prototype.hasOwnProperty.call(data, key), `Falta clave raíz obligatoria: ${key}`);
  }
  check(data.status === 'consolidated_v1_ped03a', `Status esperado 'consolidated_v1_ped03a', actual '${data.status}'`);

  // 2. Categorías válidas (REV-09)
  const validCategories = new Set(
    (data.category_taxonomy || []).map((c) => c.category_id)
  );
  check(validCategories.size === 5, `Se esperan 5 categorías oficiales; encontradas: ${validCategories.size}`);

  // 3. Movimientos canónicos únicos (97) y convenciones de ID + revisión técnica / IA
  const movementMap = new Map();
  const movements = data.movements || [];
  check(movements.length === 97, `Se esperan 97 movimientos canónicos únicos en Cordas 1-6; encontrados: ${movements.length}`);

  const expectedPending = new Set(['desequilibrante', 'espelho_cruz', 'au_chibata_pulado']);
  const actualPending = new Set();

  for (const mov of movements) {
    check(/^[a-z0-9_]+$/.test(mov.movement_id), `movement_id inválido: ${mov.movement_id}`);
    check(!movementMap.has(mov.movement_id), `movement_id duplicado: ${mov.movement_id}`);
    check(validCategories.has(mov.category_id), `Categoría inválida en ${mov.movement_id}: ${mov.category_id}`);
    check(Array.isArray(mov.appears_in_adulto_cordas) && mov.appears_in_adulto_cordas.length > 0,
      `Movimiento sin apariciones: ${mov.movement_id}`);
    check(['approved', 'pending_technical_review'].includes(mov.review_status),
      `review_status inválido en ${mov.movement_id}: ${mov.review_status}`);
    check(typeof mov.is_ambiguous === 'boolean', `Falta is_ambiguous booleano en ${mov.movement_id}`);
    check(typeof mov.ai_planner_eligible === 'boolean', `Falta ai_planner_eligible booleano en ${mov.movement_id}`);
    check(Array.isArray(mov.unconfirmed_equivalences), `Falta unconfirmed_equivalences en ${mov.movement_id}`);

    // Ningún movimiento ambiguo o pendiente puede ser elegible para el planificador IA
    if (mov.is_ambiguous || mov.review_status !== 'approved') {
      check(mov.ai_planner_eligible === false,
        `Movimiento ambiguo/pendiente NO puede tener ai_planner_eligible=true: ${mov.movement_id}`);
      actualPending.add(mov.movement_id);
    }

    if (expectedPending.has(mov.movement_id)) {
      check(mov.review_status === 'pending_technical_review',
        `${mov.movement_id} debe tener review_status='pending_technical_review'`);
      check(mov.is_ambiguous === true, `${mov.movement_id} debe tener is_ambiguous=true`);
      check(mov.ai_planner_eligible === false, `${mov.movement_id} debe tener ai_planner_eligible=false`);
    }

    // Corrección obligatoria 1: eliminar equivalencias automáticas no confirmadas
    if (mov.movement_id === 'flick') {
      const lowerAliases = (mov.aliases || []).map((a) => String(a).toLowerCase());
      check(!lowerAliases.includes('flip'), `REV-10: 'Flip' no debe figurar en aliases confirmados de 'flick'`);
      check(mov.unconfirmed_equivalences.some((u) => String(u.term).toLowerCase() === 'flip' && u.status === 'unconfirmed'),
        `REV-10: 'flick' debe registrar 'Flip' en unconfirmed_equivalences`);
    }
    if (mov.movement_id === 'espelho_cruz') {
      const lowerAliases = (mov.aliases || []).map((a) => String(a).toLowerCase());
      check(!lowerAliases.includes('espelho') && !lowerAliases.includes('cruz'),
        `Corrección 1: 'Espelho' y 'Cruz' no deben figurar en aliases confirmados de 'espelho_cruz'`);
      check(mov.unconfirmed_equivalences.length >= 2,
        `'espelho_cruz' debe registrar 'Espelho' y 'Cruz' en unconfirmed_equivalences`);
    }

    movementMap.set(mov.movement_id, mov);
  }

  check(actualPending.size === expectedPending.size &&
    [...expectedPending].every((id) => actualPending.has(id)),
    `Los IDs pendientes de revisión técnica deben ser exactamente ${[...expectedPending].join(', ')}; encontrados: ${[...actualPending].join(', ')}`);

  // Validar referencias internas en combinaciones y páginas
  for (const mov of movements) {
    if (Array.isArray(mov.component_movement_ids)) {
      for (const compId of mov.component_movement_ids) {
        check(movementMap.has(compId), `component_movement_id inexistente '${compId}' en ${mov.movement_id}`);
      }
    }
    for (const app of mov.appears_in_adulto_cordas || []) {
      check(/^adulto_corda_\d{2}$/.test(app.corda_id), `corda_id inválido en aparición de ${mov.movement_id}: ${app.corda_id}`);
      check(Number.isInteger(app.printed_page) && Number.isInteger(app.pdf_page),
        `Página inválida en ${mov.movement_id}`);
      if (app.printed_page >= 2) {
        check(app.pdf_page === app.printed_page + 1,
          `Offset de página inconsistente en ${mov.movement_id}: impresa=${app.printed_page}, pdf=${app.pdf_page}`);
      }
    }
  }

  // REV-01: Negativa consolidado como 1 movimiento preservando 2 apariciones en Módulo II B. SAIDAS
  const negativa = movementMap.get('negativa');
  check(Boolean(negativa), 'Falta movimiento negativa');
  if (negativa) {
    const mod2Apps = (negativa.appears_in_adulto_cordas || []).filter(
      (a) => a.corda_id === 'adulto_corda_01' && String(a.module_or_section).includes('B. SAIDAS')
    );
    check(mod2Apps.length === 2, `REV-01: negativa debe preservar 2 apariciones en Módulo II B. SAIDAS; encontradas: ${mod2Apps.length}`);
  }

  // 4. Tracks Adulto e Infantil (separación estricta)
  const adultoSummary = (data.tracks && data.tracks.adulto && data.tracks.adulto.cordas_index_summary) || [];
  check(adultoSummary.length === 17, `Adulto debe catalogar 17 cordas totales; encontradas: ${adultoSummary.length}`);

  const infantilCordas = (data.tracks && data.tracks.infantil && data.tracks.infantil.cordas) || [];
  check(infantilCordas.length === 12, `Infantil debe catalogar 12 cordas; encontradas: ${infantilCordas.length}`);
  for (const inf of infantilCordas) {
    check(/^infantil_corda_\d{2}$/.test(inf.corda_id), `ID infantil inválido: ${inf.corda_id}`);
  }

  // 5. Bloques compartidos (5 y 6 agrupadas)
  const blockMap = new Map();
  const blocks = data.curriculum_blocks || [];
  check(blocks.length === 1, `Se espera exactamente 1 bloque compartido (adulto_bloque_05_06); encontrados: ${blocks.length}`);

  const referencedMovements = new Set();
  for (const block of blocks) {
    check(/^adulto_bloque_\d{2}_\d{2}$/.test(block.block_id), `block_id inválido: ${block.block_id}`);
    check(!blockMap.has(block.block_id), `block_id duplicado: ${block.block_id}`);
    blockMap.set(block.block_id, block);
    for (const secKey of ['golpes_de_ataque', 'movimentos_de_solo', 'golpes_desequilibrantes']) {
      const items = (block.sections && block.sections[secKey]) || [];
      check(items.length > 0, `Bloque ${block.block_id} sin ítems en ${secKey}`);
      for (const item of items) {
        check(movementMap.has(item.movement_id), `Bloque ${block.block_id} referencia movement_id inexistente: ${item.movement_id}`);
        check(item.pdf_page === item.printed_page + 1, `Offset página inválido en ${block.block_id}:${item.movement_id}`);
        referencedMovements.add(item.movement_id);
      }
    }
  }

  // 6. Cordas extraídas (1..6) e integridad bidireccional
  const cordaMap = new Map();
  const cordas = data.cordas || [];
  check(cordas.length === 6, `Se esperan 6 cordas adultas extraídas; encontradas: ${cordas.length}`);

  for (const corda of cordas) {
    check(/^adulto_corda_\d{2}$/.test(corda.corda_id), `corda_id inválido: ${corda.corda_id}`);
    check(!cordaMap.has(corda.corda_id), `corda_id duplicado: ${corda.corda_id}`);
    cordaMap.set(corda.corda_id, corda);

    if (corda.index === 5 || corda.index === 6) {
      check(corda.shared_block_id === 'adulto_bloque_05_06',
        `${corda.corda_id} debe referenciar shared_block_id 'adulto_bloque_05_06'`);
      check(!corda.sections && !corda.modules,
        `${corda.corda_id} no debe duplicar ni dividir secciones fuera del bloque compartido`);
      check(Boolean(corda.avaliacao && corda.avaliacao.fisico),
        `${corda.corda_id} debe conservar su evaluación física diferenciada`);
    }

    if (Array.isArray(corda.modules)) {
      for (const mod of corda.modules) {
        for (const id of mod.movement_ids || []) {
          check(movementMap.has(id), `${corda.corda_id}/${mod.module_id} referencia inexistente: ${id}`);
          referencedMovements.add(id);
        }
        if (mod.sections) {
          for (const secItems of Object.values(mod.sections)) {
            if (Array.isArray(secItems)) {
              for (const item of secItems) {
                check(movementMap.has(item.movement_id), `${corda.corda_id}/${mod.module_id} referencia inexistente: ${item.movement_id}`);
                referencedMovements.add(item.movement_id);
              }
            }
          }
        }
      }
    }

    if (corda.sections) {
      for (const secItems of Object.values(corda.sections)) {
        if (Array.isArray(secItems)) {
          for (const item of secItems) {
            check(movementMap.has(item.movement_id), `${corda.corda_id} referencia inexistente: ${item.movement_id}`);
            referencedMovements.add(item.movement_id);
          }
        }
      }
    }
  }

  for (const mov of movements) {
    check(referencedMovements.has(mov.movement_id),
      `Movimiento huérfano (no referenciado por ninguna corda o bloque): ${mov.movement_id}`);
    for (const app of mov.appears_in_adulto_cordas) {
      check(cordaMap.has(app.corda_id), `Aparición de ${mov.movement_id} apunta a corda no cargada: ${app.corda_id}`);
      if (app.block_id) {
        check(blockMap.has(app.block_id), `Aparición de ${mov.movement_id} apunta a bloque inexistente: ${app.block_id}`);
      }
    }
  }

  // 7. Tutorial mapping (21 docs vivos, 5 videos reales, relaciones múltiples movement_ids)
  const tutorialMap = new Set();
  const tutorials = data.tutorial_mapping || [];
  check(tutorials.length === 21, `Se esperan exactamente 21 tutoriales de producción; encontrados: ${tutorials.length}`);
  const realVideos = tutorials.filter((t) => t.has_real_video === true);
  check(realVideos.length === 5, `Se esperan exactamente 5 tutoriales con video real; encontrados: ${realVideos.length}`);

  for (const t of tutorials) {
    check(Boolean(t.tutorial_doc_id) && !tutorialMap.has(t.tutorial_doc_id), `tutorial_doc_id duplicado o vacío: ${t.tutorial_doc_id}`);
    tutorialMap.add(t.tutorial_doc_id);
    check(t.preserve_legacy_permissions === true, `Tutorial ${t.tutorial_doc_id} debe preservar permisos actuales`);
    check(Array.isArray(t.movement_ids) && t.movement_ids.length >= 1,
      `Tutorial ${t.tutorial_doc_id} debe definir movement_ids no vacío`);
    for (const mid of t.movement_ids || []) {
      check(movementMap.has(mid), `Tutorial ${t.tutorial_doc_id} referencia movement_id inexistente: ${mid}`);
    }
    check(Array.isArray(t.curriculum_corda_ids) && t.curriculum_corda_ids.length >= 1,
      `Tutorial ${t.tutorial_doc_id} debe definir curriculum_corda_ids`);
    for (const cid of t.curriculum_corda_ids || []) {
      check(cordaMap.has(cid), `Tutorial ${t.tutorial_doc_id} referencia corda inexistente: ${cid}`);
    }
    if (Array.isArray(t.pending_movement_ids)) {
      for (const pid of t.pending_movement_ids) {
        check(movementMap.has(pid), `Tutorial ${t.tutorial_doc_id} referencia pending_movement_id inexistente: ${pid}`);
      }
    }
    if (t.tutorial_doc_id === 'WH4bG3SQ3CSd8ozb1619') {
      check(t.movement_ids.includes('cocorinha') && !t.movement_ids.includes('ginga'),
        `REV-04: WH4bG3SQ3CSd8ozb1619 debe asociarse a cocorinha sin incluir ginga en movement_ids confirmados`);
      check((t.pending_movement_ids || []).includes('ginga'),
        `REV-04: WH4bG3SQ3CSd8ozb1619 debe mantener ginga en pending_movement_ids`);
    }
  }

  // 8. Glossary crosswalk (26 términos: 18 específicos + 2 genéricos + 6 culturales)
  const glossarySet = new Set();
  const glossary = data.glossary_crosswalk || [];
  check(glossary.length === 26, `Se esperan 26 términos en el glosario; encontrados: ${glossary.length}`);
  const culturalCount = glossary.filter((g) => g.entry_kind === 'cultura').length;
  check(culturalCount === 6, `Se esperan 6 términos culturales en el glosario; encontrados: ${culturalCount}`);
  const genericCount = glossary.filter((g) => g.is_generic_term === true).length;
  check(genericCount === 2, `REV-08: Se esperan 2 términos genéricos en el glosario; encontrados: ${genericCount}`);

  for (const g of glossary) {
    check(Boolean(g.termino_glosario) && !glossarySet.has(g.termino_glosario), `Término de glosario duplicado/vacío: ${g.termino_glosario}`);
    glossarySet.add(g.termino_glosario);
    check(Array.isArray(g.movement_ids), `Glosario '${g.termino_glosario}' debe definir movement_ids`);
    check(Array.isArray(g.related_variant_movement_ids), `Glosario '${g.termino_glosario}' debe definir related_variant_movement_ids`);

    if (g.entry_kind === 'cultura') {
      check(g.movement_ids.length === 0 && g.mapped_movement_id === null,
        `Término cultural no debe mapear a movimiento: ${g.termino_glosario}`);
    } else if (g.is_generic_term === true) {
      check(g.movement_ids.length === 0 && g.mapped_movement_id === null,
        `Término genérico '${g.termino_glosario}' no debe auto-asignarse a un único movimiento`);
      check(g.related_variant_movement_ids.length >= 2,
        `Término genérico '${g.termino_glosario}' debe mantener relaciones con sus variantes`);
      for (const vid of g.related_variant_movement_ids) {
        check(movementMap.has(vid), `Variante inexistente '${vid}' en glosario '${g.termino_glosario}'`);
      }
    } else {
      check(g.movement_ids.length >= 1, `Glosario '${g.termino_glosario}' debe tener movement_ids`);
      for (const mid of g.movement_ids) {
        check(movementMap.has(mid), `Glosario '${g.termino_glosario}' mapea a movement_id inexistente: ${mid}`);
      }
    }
  }

  return errors;
}

function main() {
  if (!fs.existsSync(CATALOG_PATH)) {
    console.error(`FAIL: No existe el archivo ${CATALOG_PATH}`);
    process.exit(1);
  }

  let data;
  try {
    data = JSON.parse(fs.readFileSync(CATALOG_PATH, 'utf8'));
  } catch (err) {
    console.error(`FAIL: JSON inválido: ${err.message}`);
    process.exit(1);
  }

  const errors = validateCatalogData(data);
  if (errors.length > 0) {
    console.error(`FAIL: Se encontraron ${errors.length} error(es) de validación:`);
    for (const e of errors) {
      console.error(`  - ${e}`);
    }
    process.exit(1);
  }

  const realVideos = (data.tutorial_mapping || []).filter((t) => t.has_real_video === true).length;
  const aiEligible = (data.movements || []).filter((m) => m.ai_planner_eligible === true).length;
  const aiExcluded = (data.movements || []).length - aiEligible;

  console.log('PASS: Catálogo curricular FIU consolidado y validado correctamente.');
  console.log(`  - Status: ${data.status}`);
  console.log(`  - Movimientos canónicos únicos (Cordas 1-6): ${data.movements.length} (elegibles IA: ${aiEligible}, excluidos/pendientes: ${aiExcluded})`);
  console.log(`  - Cordas adulto extraídas: ${data.cordas.length} (total catalogado: ${data.tracks.adulto.cordas_index_summary.length})`);
  console.log(`  - Bloques compartidos: ${data.curriculum_blocks.length} (${data.curriculum_blocks.map((b) => b.block_id).join(', ')})`);
  console.log(`  - Cordas infantil catalogadas en metadata: ${data.tracks.infantil.cordas.length}`);
  console.log(`  - Tutoriales mapeados: ${data.tutorial_mapping.length} (videos reales: ${realVideos})`);
  console.log(`  - Términos de glosario cruzados: ${data.glossary_crosswalk.length}`);
}

if (require.main === module) {
  main();
}

module.exports = { validateCatalogData, CATALOG_PATH };
