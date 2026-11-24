# Contrato Curricular para el Futuro Planificador de Clases IA (`generarPlanClaseIA`)

> **Versión:** Contrato v1.1.0 (actualizado en **PED-03C** tras cierre de **PED-03B-FINAL**; sin modificar todavía `functions/index.js`).  
> **Origen de datos:** Colecciones Firestore `curriculum_*`, `CurriculumRepository.buildAiPlannerCurriculumPayload(...)` ([curriculum_repository.dart](file:///Users/jumper/ginga_app/lib/core/services/curriculum_repository.dart)) y contrato de selección UI `CurriculumSelectionContract` ([curriculum_models.dart](file:///Users/jumper/ginga_app/lib/core/models/curriculum_models.dart)).

---

## 1. Propósito del contrato

Garantizar que, cuando se actualice `generarPlanClaseIA`, el modelo reciba **exclusivamente** repertorio curricular oficial FIU verificado, filtrado por sistema de graduación (`adulto` o `infantil`) y corda objetivo, excluyendo cualquier entrada ambigua, pendiente de revisión o equivalencia no confirmada.

---

## 2. Reglas de selección obligatorias para el planificador IA

1. **Separación estricta de sistema (`track_id`):**
   - Nunca mezclar `adulto` (`adulto_corda_01..17`) con `infantil` (`infantil_corda_01..12`).
2. **Filtro estricto de elegibilidad IA:**
   - Seleccionar únicamente documentos de `curriculum_movements` que cumplan simultáneamente:
     - `review_status == "approved"`
     - `is_ambiguous == false`
     - `ai_planner_eligible == true`
   - **Movimientos excluidos en V1 (`pending_technical_review`):** `desequilibrante`, `espelho_cruz`, `au_chibata_pulado`.
3. **Prohibición de inferir equivalencias no confirmadas:**
   - Ignorar `unconfirmed_equivalences[]` (e.g., `Flick` vs `Flip`, `Espelho` vs `Cruz`, o `ginga` en el video compuesto `WH4bG3SQ3CSd8ozb1619`) hasta aprobación explícita.
4. **Resolución de bloque compartido (`shared_block_id`):**
   - Cuando la corda objetivo sea `adulto_corda_05` (`Corda Laranja`) o `adulto_corda_06` (`Corda Laranja e Amarelo`), consultar `curriculum_blocks/adulto_bloque_05_06` para movimientos y cronograma semanal, manteniendo de `curriculum_cordas/{corda_id}` su `avaliacao` y `musicalidade` diferenciadas.
5. **Diferenciación por `entry_kind`:**
   - `movimiento_base`: fundamentos previos de entrada (`ginga`).
   - `movimiento`: técnicas individuales clasificadas en las 5 categorías oficiales.
   - `combinacao_solo`: encadenamientos oficiales numerados (`component_movement_ids`).
6. **Uso de `drill_only_mentions` y `cronograma_semanal`:**
   - Pueden usarse como contexto de dinámicas en parejas para esa corda, sin convertir términos solo de drill en movimientos oficiales del catálogo.

---

## 3. Estructura del payload de entrada al Planificador IA

Generado por `CurriculumRepository.buildAiPlannerCurriculumPayload(track: CurriculumTrack.adulto, upToCordaIndex: N)`:

```json
{
  "contract_version": "1.0.0",
  "track_id": "adulto",
  "target_corda_id": "adulto_corda_05",
  "target_corda_index": 5,
  "shared_block_id": "adulto_bloque_05_06",
  "eligible_movements_count": 94,
  "excluded_ambiguous_ids": [
    "au_chibata_pulado",
    "desequilibrante",
    "espelho_cruz"
  ],
  "movements_by_category": {
    "fundamento": [{ "movement_id": "ginga", "canonical_name": "Ginga", "entry_kind": "movimiento_base" }],
    "golpe_de_ataque": ["..."],
    "saida_esquiva": ["..."],
    "movimento_de_solo": ["..."],
    "golpe_desequilibrante": ["..."]
  },
  "target_sequences": [],
  "target_weekly_schedule": {
    "repeticoes_minimas": "ao menos 6 vezes para cada lado",
    "treino_1": ["..."],
    "treino_2": ["..."],
    "treino_3": ["..."]
  },
  "target_musicality": {
    "raw": "...",
    "especifico_corda": "envergar os berimbaus gunga, médio e viola"
  },
  "target_evaluation": {
    "fisico": { "flexoes": 50, "abdominais": 50, "parada_de_mao_voltas_na_roda": 2 },
    "musical": ["envergar os berimbaus gunga, médio e viola"]
  }
}
```

---

## 4. Colecciones Firestore de lectura curricular

| Colección | Propósito | Regla de lectura | Regla de escritura (`firestore.rules`) |
| :--- | :--- | :--- | :--- |
| `curriculum_meta` | Metadatos, taxonomía y banderas | Usuario autenticado | Solo Custom Claim firmado (`admin == true \|\| curriculum_admin == true`) |
| `curriculum_movements` | Movimientos canónicos compartidos | Usuario autenticado | Solo Custom Claim firmado (`admin == true \|\| curriculum_admin == true`) |
| `curriculum_cordas` | Cordas `adulto_*` e `infantil_*` | Usuario autenticado | Solo Custom Claim firmado (`admin == true \|\| curriculum_admin == true`) |
| `curriculum_blocks` | Bloques compartidos (`adulto_bloque_05_06`) | Usuario autenticado | Solo Custom Claim firmado (`admin == true \|\| curriculum_admin == true`) |
| `curriculum_tutorial_links` | Vínculos múltiples a `/tutoriales` | Usuario autenticado | Solo Custom Claim firmado (`admin == true \|\| curriculum_admin == true`) |
| `curriculum_glossary_links` | Cruce con glosario y variantes | Usuario autenticado | Solo Custom Claim firmado (`admin == true \|\| curriculum_admin == true`) |

> **Nota de seguridad (PED-03A/03C):** `firestore.rules` prohíbe `delete` en todas las colecciones `curriculum_*` incluso para administradores, y rechaza auto-elevaciones vía `users/{uid}.rol` si no existe Custom Claim firmado en el token JWT.

---

## 5. Contrato UI de Selección Manual para PED-04 (`CurriculumSelectionContract`)

Además del payload global por corda (`buildAiPlannerCurriculumPayload`), **PED-03B-FINAL** dejó implementado un contrato opt-in de selección manual en [curriculum_models.dart](file:///Users/jumper/ginga_app/lib/core/models/curriculum_models.dart), conectado en [curriculo_biblioteca_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/curriculo_biblioteca_screen.dart) y [movimiento_detalle_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/movimiento_detalle_screen.dart).

### 5.1. Modelos y firmas exactas

```dart
typedef CurriculumSelectionCallback = void Function(
  List<CurriculumMovementSelectionItem> selectedItems,
);

class CurriculumSelectionContract {
  final bool enabled;
  final Set<String> initialSelectedMovementIds;
  final bool excludePendingTechnicalReview; // default: true
  final String confirmLabel;                // default: 'Usar en planificador'
  final CurriculumSelectionCallback? onSelectionChanged;
  final CurriculumSelectionCallback? onConfirmSelection;
}

class CurriculumMovementSelectionItem {
  final String movementId;
  final String canonicalName;
  final TechnicalCategory category;
  final String? firstIntroducedAdulto;
  final bool isCombination;
  final bool isSelectableForAiPlanner;
  final bool hasRealVideo;

  Map<String, dynamic> toPlannerMap();
}
```

### 5.2. Formato serializado por movimiento (`toPlannerMap()`)

```json
{
  "movement_id": "cocorinha",
  "canonical_name": "Cocorinha",
  "category": "saida_esquiva",
  "first_introduced_adulto": "adulto_corda_01",
  "is_combination": false,
  "selectable_for_ai_planner": true,
  "has_real_video": true
}
```

### 5.3. Comportamiento y reglas de integración para PED-04

1. **Opt-in sin impacto en la Biblioteca:** Si `selectionContract` es `null` o `enabled == false`, la Biblioteca opera exclusivamente como consulta.
2. **Pre-selección y barra inferior:** Al abrir `CurriculoBibliotecaScreen(selectionContract: ...)` desde `InstructorPizarraScreen`, pueden pasarse `initialSelectedMovementIds`, `initialCordaIndex` y `initialCumulativeMode`. La pantalla muestra toggles en cada tarjeta y ficha técnica, más una barra inferior con conteo, `Limpiar` y botón `confirmLabel`.
3. **Bloqueo automático de entradas ambiguas:** Cuando `excludePendingTechnicalReview == true`, los movimientos con `isSelectableForAiPlanner == false` (`desequilibrante`, `espelho_cruz`, `au_chibata_pulado`) muestran estado bloqueado y no pueden enviarse al planificador automático.
4. **Uso previsto en PED-04:** `InstructorPizarraScreen` podrá abrir la Biblioteca en modo selector, recibir `List<CurriculumMovementSelectionItem>` en `onConfirmSelection`, convertirlos con `.toPlannerMap()` y pasarlos como foco explícito de clase junto con el contexto del grupo real (edad, asistencia, corda objetivo) hacia `generarPlanClaseIA`.

---

## 6. Requisitos Pendientes para Incorporar el Currículo Infantil al Planificador (`PED-04+`)

Actualmente `data/curriculum/fiu_adulto_v1.json` cataloga la **estructura oficial Infantil** (`infantil_corda_01..infantil_corda_12`) como `structure_mapped_content_pending` (resumen en pp. 13–14 y entrenamiento en pp. 15–25 impresas / 16–26 PDF de `scratch/apostila.pdf`), pero **no** contiene aún la extracción técnica por corda. Para incorporar Infantil al futuro planificador sin mezclar tracks se requiere:

1. **Extracción visual verificada del manual (`scratch/apostila.pdf`, pp. 15–25):**
   - Digitalizar página por página las 12 cordas infantiles (`infantil_corda_01` *Crua / Amarelo* a `infantil_corda_12` *Azul / Verde Escuro*), preservando nombres exactos impresos, referencias de página y variantes terminológicas.
2. **Mapeo al catálogo canónico compartido (`curriculum_movements`):**
   - Vincular cada técnica infantil al `movement_id` canónico existente cuando coincida, o crear nuevas entradas específicas con `tracks_supported: ["infantil"]` y `appears_in_infantil_cordas[]` sin contaminar `appears_in_adulto_cordas[]`.
3. **Modelado de reglas por edad y transición:**
   - Respetar los tramos reales de la apostila: cordas `1–3` por edad (`3`, `4` y `5` años), cordas `4–12` (`6 a 13 años`) y criterio de transición a Adulto cerca de los `15 años` o al completar la 12ª corda.
   - Integrar la edad real de los alumnos inscritos en la clase/grupo de Firestore para filtrar o adaptar dinámicamente intensidad, volumen físico y secuencias apropiadas para niños.
4. **Criterios de evaluación infantil diferenciados:**
   - Soportar explícitamente las 5 dimensiones infantiles definidas en metadata (`comportamento`, `presenca_min_75_pct`, `movimentos_e_sequencias_cumulativo`, `musicalidade`, `historia`), distintas de las flexiones/abdominais/parada de mão del bloque adulto.
5. **Revisión pedagógica del propietario e importador:**
   - Pasar un ciclo análogo de revisión (`REVIEW.md` con decisiones `REV-*`) antes de marcar `ai_planner_eligible: true` en técnicas infantiles, y ampliar `validate_curriculum_catalog.js`, `CurriculumRepository.getAccumulatedRepertoire(track: CurriculumTrack.infantil, ...)` y `buildAiPlannerCurriculumPayload`.
6. **Seguridad y soporte en Biblioteca Infantil:**
   - Definir si los tutoriales/videos existentes (orientados hoy a cordas adultas) pueden sugerirse como apoyo docente en clases infantiles o requieren etiqueta/filtro explícito de aptitud infantil.
