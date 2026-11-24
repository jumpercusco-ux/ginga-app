# Revisión Pedagógica — Currículo Oficial FIU Adulto V1 (Cordas 1 a 6)

> **Estado:** Borrador estructurado listo para revisión pedagógica del propietario (sin escrituras en Firestore ni cambios en la app).  
> **Fuente oficial:** [apostila.pdf](file:///Users/jumper/ginga_app/scratch/apostila.pdf) — *Manual de Treinamento FIU e História de Capoeira ("Família Irmãos Unidos do Mestre Natal")*, Mestre Sidney Santos Dias da Cruz, São Paulo, 2020 (68 págs. PDF).  
> **Catálogo JSON:** [fiu_adulto_v1.json](file:///Users/jumper/ginga_app/data/curriculum/fiu_adulto_v1.json)  
> **Validador offline:** [validate_curriculum_catalog.js](file:///Users/jumper/ginga_app/scripts/validate_curriculum_catalog.js)

---

## 1. Decisiones estructurales aplicadas (PED-01 + PED-02)

- **Biblioteca técnica unificada:** Diseñada para alumnos y profesores bajo el mismo catálogo canónico de movimientos (`curriculum_movements`), sin módulo paralelo de entrenamiento personal.
- **Separación estricta Adulto vs. Infantil desde los IDs:**
  - Adulto: `adulto_corda_01` .. `adulto_corda_17` (extraído en V1: `01` a `06`).
  - Infantil: `infantil_corda_01` .. `infantil_corda_12` (estructura registrada en metadata para evitar mezcla futura).
  - Bloques agrupados: `adulto_bloque_05_06` para Cordas 5 y 6.
- **Cero divisiones inventadas:** En el manual, **Corda Laranja (5)** y **Corda Laranja e Amarelo (6)** comparten un único bloque técnico y cronograma semanal (pp. 42–44 / PDF 43–45). Se conservan agrupadas en `adulto_bloque_05_06`, preservando aparte sus requisitos físicos y musicales diferenciados (p. 49 / PDF 50).
- **Verificación visual de columnas:** Se renderizaron e inspeccionaron visualmente las páginas PDF de Cordas 1–6, Evaluaciones y Graduación Infantil para evitar los errores de mezcla de columnas del extractor de texto plano.
- **Convención de páginas:** Desde la página impresa 2 en adelante se cumple `pdf_page = printed_page + 1`.

---

## 2. Currículo Adulto por Corda (Cordas 1 a 6)

### Corda 1 — `adulto_corda_01`: Corda Crua
- **Simbolismo (p. 26 / PDF 27):** *"Simboliza Universo. A corda crua é a corda de todo iniciante e o ingresso para o mundo da Capoeira."*
- **Páginas de entrenamiento:** pp. 31–32 impresas / PDF 32–33.
- **Módulo I (`um mês`):**
  - Prerrequisito literal: *"Antes de qualquer movimento, ensinamento e correção de ginga."* (`ginga`)
  - Movimientos base (8): `A benção`, `martelo`, `passa-pé`, `cocorinha`, `negativa`, `esquiva lateral`, `rolamento na ginga`, `au`.
- **Módulo II (`6 meses a 1 ano`) — Repeticiones mínimas: 10 veces cada lado por treino:**

| Sección manual | Ítems impresos en el manual | IDs canónicos | Página |
| :--- | :--- | :--- | :--- |
| **A. GOLPES** | 1. Benção · 2. Martelo · 3. Chapa de frente · 4. Passa pé · 5. Queixada · 6. Armada · 7. Meia lua de compasso | `bencao`, `martelo`, `chapa_de_frente`, `passa_pe`, `queixada`, `armada`, `meia_lua_de_compasso` | p. 31 / PDF 32 |
| **B. SAIDAS** | 1. Cocorinha · 2. Esquiva lateral · 3. Negativa · 4. Negativa de angola · 5. **Negativa *(duplicado literal)*** · 6. Rolamento na ginga · 7. Esquiva básica | `cocorinha`, `esquiva_lateral`, `negativa`, `negativa_de_angola`, *(dup)*, `rolamento_na_ginga`, `esquiva_basica` | p. 31 / PDF 32 |
| **C- MOVIMENTOS DE SOLO** | 1. Au · 2. Bananeira · 3. Au com negativa e rolamento na ginga · 4. Troca de negativa · 5. Ponte | `au`, `bananeira`, `au_com_negativa_e_rolamento_na_ginga`, `troca_de_negativa`, `ponte` | p. 32 / PDF 33 |

- **D- Musicalidade:** aprender a bater palmas e responder o coro.
- **Avaliação (p. 48 / PDF 49):** realizar movimientos de la graduación, bananeira 10 segundos, 10 flexões, dedicación/atención, palmas y coro.
- **Sabedoria do Mestre Natal:** *"Todo cuidado é pouco."*

---

### Corda 2 — `adulto_corda_02`: Corda Crua e Verde
- **Duración:** `de 6 meses a 1 ano` · **Repeticiones mínimas:** `06 vezes para cada lado` · **Páginas:** pp. 33–35 / PDF 34–36.

| Sección manual | Ítems impresos en el manual | Página |
| :--- | :--- | :--- |
| **A -GOLPES DE ATAQUES.** (9) | 1. Benção · 2. Passa pé · 3. Queixada · 4. Martelo · 5. Chapa de frente · 6. Armada · 7. Meia lua de frente · 8. Meia lua de compasso · 9. Chapéu de couro em pé | p. 33 / PDF 34 |
| **B-SAÍDAS BÁSICAS** (6) | 1. Cocorinha · 2. Negativa de angola · 3. Negativa de frente · 4. Mola · 5. Rolamento na ginga · 6. Esquiva básica | p. 33 / PDF 34 |
| **C MOVIMENTOS DE SOLO** (9) | 1. Aú · 2. Aú agulha · 3. Aú role · 4. Aú com negativa e rolamento na ginga · 5. Aú com negativa e rasteira no chão · 6. Bananeira · 7. Chibata de chão · 8. Macaco · 9. Ponte | p. 33 / PDF 34 |
| **D -GOLPES DESEQUILIBRANTES** (3) | 1. Rasteira em pé · 2. Rasteira no chão · 3. Arpão | p. 34 / PDF 35 |

- **E - Exemplos de Sequência (p. 34 / PDF 35):** `Sequência da esquiva básica: esquiva básica, negativa da frente, rolamento na ginga`.
- **F- Musicalidade:** aprender a tocar o pandeiro no ritmo de Angola e São Bento pequeno, responder o coro e bater palma.
- **Cronograma Semanal (pp. 34–35 / PDF 35–36):**
  - *Treino 1 (7):* `Armada x Chapéu de coro em pé` *(sic)*, `Queixada x Chapéu de couro em pé`, `Martelo x Chapéu de couro em pé`, `Chapéu de couro x Martelo`, `Passa pé x rasteira em pé`, `Benção x meia lua de compasso`, `Passa pé x Martelo`.
  - *Treino 2 (11):* `Benção saída de Negativa de angola`, `Benção saída de Mola`, `Queixada saída de Cocorinha`, `Martelo saída de Cocorinha`, `Meia lua de compasso saída de rolamento na ginga`, `Benção x Benção`, `Benção x Martelo`, `Benção x Rasteira em pé`, `Queixada x Armada`, `Armada x Benção`, `Armada x martelo`.
  - *Treino 3 (8):* `Martelo x Rasteira no chão`, `Martelo x Martelo`, `Martelo x Benção`, `Benção x Rasteira no chão`, `Armada x Rasteira em pé`, `Martelo x Chapa de frente`, `Armada x Chapa de frente`, `Benção x Chapéu de couro em pé`.
- **Avaliação (p. 48 / PDF 49):** movimientos de la graduación, parada de mão 10 segundos, 20 flexões, pandeiro (Angola y São Bento pequeno), coro y palmas.
- **Sabedoria do Mestre Natal:** *"Quem presta atenção aprende mais."*

---

### Corda 3 — `adulto_corda_03`: Corda Verde
- **Simbolismo (p. 26 / PDF 27):** *"Simboliza o Oxigênio. É quando o aluno/a passa ganhar mais resistência durante os treinos. Transmite harmonia e equilíbrio."*
- **Herencia explícita (p. 36 / PDF 37):** *"Os movimentos aplicados a corda crua e verde serão aplicados à corda verde. Caso o aluno/a corda verde esteja um pouco mais avançado poderá receber movimentos do próximo grau."*
- **Duración:** `de 6 meses a 1 ano` · **Repeticiones mínimas:** `6 vezes para cada lado` · **Páginas:** pp. 36–38 / PDF 37–39.

| Sección manual | Ítems impresos en el manual | Página |
| :--- | :--- | :--- |
| **A- GOLPES DE ATAQUE** (8) | 1. Benção pulada · 2. Benção caminhada · 3. Martelo giratório · 4. Meia lua solta · 5. Armada pulada · 6. Meia lua de frente · 7. Chapa de lado · 8. Chapéu de couro no chão | p. 36 / PDF 37 |
| **B- MOVIMENTOS DE SOLO** (8) | 1. Canguru · 2. Aú aranha · 3. Parada de mão · 4. Queda de rim · 5. Macaco · 6. Macaco solto · 7. Aú por dentro · 8. Aú de costas | p. 36 / PDF 37 |
| **C- GOLPES DESEQUILIBRANTES** (4) | 1. Tesoura numa perna só · 2. Puxada com as mãos · 3. Trava na ginga · 4. Arpão | p. 36 / PDF 37 |
| **D - GOLPES E CONTRA GOLPES** | Encabezado impreso sin lista debajo | p. 37 / PDF 38 |

- **E- Exemplos de Sequências (p. 37 / PDF 38):** `Sequência da rasteira no chão: rasteira no chão, negativa da regional, troca de perna, negativa, rolamento na ginga, au`.
- **F- Musicalidade + regla acumulativa (p. 37 / PDF 38):** tocar pandeiro y atabaque (Angola, São Bento pequeno, São Bento grande de Angola), berimbau (Angola, São Bento pequeno), palmas y coro. **Desde esta graduación en adelante:** saber tocar **berimbau, atabaque, pandeiro, reco-reco y agogô** en los ritmos de Angola, São Bento pequeno y São Bento grande de Angola.
- **Cronograma Semanal (pp. 37–38 / PDF 38–39):** Treino 1 (9 combinaciones), Treino 2 (8 combinaciones), Treino 3 (10 combinaciones) registrados íntegramente en el JSON.
- **Avaliação (p. 48 / PDF 49):** movimientos de la graduación, 20 segundos parada de mão, 30 flexões, 30 abdominais, musicalidad completa.
- **Sabedoria do Mestre Natal:** *"Treinando com dedicação hoje, bom mestre amanhã"*

---

### Corda 4 — `adulto_corda_04`: Corda Verde e Laranja
- **Duración:** `de 6 meses a 1 ano` · **Repeticiones mínimas:** `6 vezes para cada lado` · **Páginas:** pp. 39–41 / PDF 40–42.

| Sección manual | Ítems impresos en el manual | Página |
| :--- | :--- | :--- |
| **A- GOLPES DE ATAQUE** (12) | 1. Chapa pulada · 2. Chapa presa · 3. Ponteira · 4. Martelo por dentro · 5. Martelo voador · 6. Queixada de frente · 7. Escala · 8. Parafuso · 9. Cabeçada · 10. Au chibata · 11. Puxada presa · 12. Meia lua solta | p. 39 / PDF 40 |
| **B-MOVIMENTOS DE SOLO** (11) | 1. Au batendo · 2. Corta capim · 3. Pião de cabeça · 4. Au giratório · 5. Flick · 6. Aú por dentro · 7. Aú de costas · 8. Aú coluna · 9. Aú por dentro na meia lua · 10. Aú fechado · 11. Macaco solto | p. 39 / PDF 40 |
| **C-GOLPES DESEQUILIBRANTES** (5) | 1. Tesoura de lado · 2. Rasteira baiana · 3. Rasteira de costas · 4. Vingativa · 5. Banda de costas | p. 39 / PDF 40 |
| **D-GOLPES E CONTRA GOLPES** | Encabezado impreso sin lista debajo | p. 39 / PDF 40 |

- **E- Musicalidade (p. 40 / PDF 41):** tocar pandeiro, atabaque, agogô, reco-reco y berimbau (São Bento pequeno y São Bento grande de Angola) y **cantar 1 música en ritmo Angola, 1 en São Bento pequeno y 1 en São Bento grande de Angola**.
- **Cronograma Semanal (pp. 40–41 / PDF 41–42):** Treino 1 (10 combinaciones), Treino 2 (8 combinaciones), Treino 3 (7 combinaciones) registrados íntegramente en el JSON.
- **Avaliação (p. 49 / PDF 50):** movimientos de la graduación, 50 flexões, 50 abdominais, **1 volta na roda na parada de mão**, musicalidad y cantos anteriores.
- **Sabedoria do Mestre Natal:** *"Respeite os alunos/as/as para ser respeitado."*

---

### Cordas 5 y 6 (Bloque Compartido `adulto_bloque_05_06`) — Corda Laranja y Corda Laranja e Amarelo
- **Simbolismo Corda Laranja (p. 27 / PDF 28):** *"Simboliza o Despertar do Sol..."* (agilidad mental y corporal, reflejos, voluntad y dedicación).
- **Duración:** `de 6 meses a 1 ano` · **Repeticiones mínimas:** `ao menos 6 vezes para cada lado` · **Páginas:** pp. 42–44 / PDF 43–45.

| Sección manual (compartida 5 y 6) | Ítems impresos en el manual | Página |
| :--- | :--- | :--- |
| **A-GOLPES DE ATAQUES** (12) | 1. Ponteira pulada · 2. Ponteira rasante · 3. Açoite · 4. Chapa rodada · 5. Chapa presa · 6. Chapa de costas · 7. Chapa de gancho · 8. Chapa cruzada · 9. Chapa voada · 10. Chapa giratória pulada · 11. Joelhada · 12. Queixada de frente | p. 42 / PDF 43 |
| **B-MOVIMENTOS DE SOLO** (9) | 1. Santo amaro · 2. **Aú chibata pulado x** *(+ `0` suelto debajo)* · 3. Aú cortado · 4. Aú quebrado · 5. Corrupio saída · 6. Fugitiva saída · 7. Aú coluna · 8. Aú por dentro na meia lua · 9. Aú trançado | p. 42 / PDF 43 |
| **C-GOLPES DESEQUILIBRANTES** (9) | 1. Banda de costas · 2. Banda de frente · 3. Tesoura de costas · 4. Tesoura pulada · 5. Tombo na ladeira · 6. **Desequilibrante** *(genérico)* · 7. **Espelho - cruz** · 8. Calço · 9. Rasteira paulista | p. 42 / PDF 43 |
| **D-GOLPES E CONTRA GOLPES** | Encabezado impreso sin lista debajo | p. 43 / PDF 44 |

- **Cronograma Semanal compartido (pp. 43–44 / PDF 44–45):** Treino 1 (8), Treino 2 (9), Treino 3 (13) registrados íntegramente en el JSON.
- **Diferenciación explícita dentro del manual (p. 43 / PDF 44 y p. 49 / PDF 50):**
  - **`adulto_corda_05` (Corda Laranja):** 50 flexões, 50 abdominais, **2 voltas na parada de mão na roda**, **envergar os berimbaus gunga, médio e viola**.
  - **`adulto_corda_06` (Corda Laranja e Amarelo):** 50 flexões **de mãos fechadas**, 50 abdominais, **3 voltas na parada de mão em volta da roda**, **armar/arrumar os três berimbaus e afinar**.

---

## 3. Inventario consolidado de los 97 movimientos canónicos únicos

- **Fundamento (1):** `ginga` (C1)
- **Golpes de Ataque (37):** `bencao` (C1, C2), `martelo` (C1, C2), `chapa_de_frente` (C1, C2), `passa_pe` (C1, C2), `queixada` (C1, C2), `armada` (C1, C2), `meia_lua_de_compasso` (C1, C2), `meia_lua_de_frente` (C2, C3), `chapeu_de_couro_em_pe` (C2), `bencao_pulada` (C3), `bencao_caminhada` (C3), `martelo_giratorio` (C3), `meia_lua_solta` (C3, C4), `armada_pulada` (C3), `chapa_de_lado` (C3), `chapeu_de_couro_no_chao` (C3), `chapa_pulada` (C4), `chapa_presa` (C4, B5-6), `ponteira` (C4), `martelo_por_dentro` (C4), `martelo_voador` (C4), `queixada_de_frente` (C4, B5-6), `escala` (C4), `parafuso` (C4), `cabecada` (C4), `au_chibata` (C4), `puxada_presa` (C4), `ponteira_pulada` (B5-6), `ponteira_rasante` (B5-6), `acoite` (B5-6), `chapa_rodada` (B5-6), `chapa_de_costas` (B5-6), `chapa_de_gancho` (B5-6), `chapa_cruzada` (B5-6), `chapa_voada` (B5-6), `chapa_giratoria_pulada` (B5-6), `joelhada` (B5-6).
- **Saídas y Esquivas (8):** `cocorinha` (C1, C2), `esquiva_lateral` (C1), `negativa` (C1), `negativa_de_angola` (C1, C2), `rolamento_na_ginga` (C1, C2), `esquiva_basica` (C1, C2), `negativa_de_frente` (C2), `mola` (C2).
- **Movimentos de Solo (32, incl. 2 combinaciones):** `au` (C1, C2), `bananeira` (C1, C2), `au_com_negativa_e_rolamento_na_ginga` (C1, C2), `troca_de_negativa` (C1), `ponte` (C1, C2), `au_agulha` (C2), `au_role` (C2), `au_com_negativa_e_rasteira_no_chao` (C2), `chibata_de_chao` (C2), `macaco` (C2, C3), `canguru` (C3), `au_aranha` (C3), `parada_de_mao` (C3), `queda_de_rim` (C3), `macaco_solto` (C3, C4), `au_por_dentro` (C3, C4), `au_de_costas` (C3, C4), `au_batendo` (C4), `corta_capim` (C4), `piao_de_cabeca` (C4), `au_giratorio` (C4), `flick` (C4), `au_coluna` (C4, B5-6), `au_por_dentro_na_meia_lua` (C4, B5-6), `au_fechado` (C4), `santo_amaro` (B5-6), `au_chibata_pulado` (B5-6), `au_cortado` (B5-6), `au_quebrado` (B5-6), `corrupio_saida` (B5-6), `fugitiva_saida` (B5-6), `au_trancado` (B5-6).
- **Golpes Desequilibrantes (19):** `rasteira_em_pe` (C2), `rasteira_no_chao` (C2), `arpao` (C2, C3), `tesoura_numa_perna_so` (C3), `puxada_com_as_maos` (C3), `trava_na_ginga` (C3), `tesoura_de_lado` (C4), `rasteira_baiana` (C4), `rasteira_de_costas` (C4), `vingativa` (C4), `banda_de_costas` (C4, B5-6), `banda_de_frente` (B5-6), `tesoura_de_costas` (B5-6), `tesoura_pulada` (B5-6), `tombo_na_ladeira` (B5-6), `desequilibrante` (B5-6), `espelho_cruz` (B5-6), `calco` (B5-6), `rasteira_paulista` (B5-6).

---

## 4. Mapeo de los 21 tutoriales vivos en producción (`/tutoriales`)

> **Preservación obligatoria:** Todos los documentos actuales y en especial los **5 videos reales** se conservan intactos. Ningún caso dudoso se auto-asigna sin aprobación.

| Doc ID | Título prod | Video real | Corda prod | Cat prod | Movimiento canónico propuesto | Estado de mapeo | Revisión |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- | :---: |
| `zU1Yy0dvgbZsw0eVTZHL` | **Ginga** | **Sí** | `""` | Fundamentos | `ginga` | `exacto_sin_corda_asignada` | Sí |
| `9rPLVAirz74XNwLRcKsc` | **Passape** | **Sí** | `""` | Ataques | `passa_pe` | `exacto_sin_corda_asignada` | Sí |
| `IoTCEDVpKXD1kYKnbPly` | **Martelo** | **Sí** | `""` | Ataques | `martelo` | `exacto_sin_corda_asignada` | Sí |
| `WH4bG3SQ3CSd8ozb1619` | **Cocorinha + base** | **Sí** | `""` | Esquivas | *Sin auto-asignar* (cand.: `cocorinha`, `ginga`) | `pendiente_revision_compuesto` | **Sí** |
| `YCl6qjc3PEN2qARrMop6` | **Aú** | **Sí** | `Crua e Verde` | Floreos | `au` | `exacto_discrepancia_corda` (manual: C1 Crua y C2) | Sí |
| `BP0MxpEzC8Fb57vtu1vP` | Benção | No | `Crua` | Ataques | `bencao` | `exacto` | No |
| `inZLbDJ8FECufveANcit` | Esquiva Lateral | No | `Crua` | Esquivas | `esquiva_lateral` | `exacto` | No |
| `YDXnpOzx2sLICotXh0Hz` | Queixada | No | `Crua e Verde` | Ataques | `queixada` | `discrepancia_corda` (manual: C1 Crua y C2) | Sí |
| `oszFmBO9qRKMzi8ZcKwv` | Armada | No | `Crua e Verde` | Ataques | `armada` | `discrepancia_corda` (manual: C1 Crua y C2) | Sí |
| `oowDGWSQEbe1LzVHYre0` | Meia Lua de Compasso | No | `Crua e Verde` | Ataques | `meia_lua_de_compasso` | `discrepancia_corda` (manual: C1 Crua y C2) | Sí |
| `sYHmAZq134p07y9crD5Q` | Macaco | No | `Crua e Verde` | Floreos | `macaco` | `exacto` | No |
| `xHmh6mH6KqlLzHp3uyis` | Rasteira no Chão | No | `Crua e Verde` | Defensas | `rasteira_no_chao` | `exacto_discrepancia_categoria` (manual: Desequilibrante) | No |
| `EboUiMSVsdnrncndyS2w` | Benção Pulada | No | `Verde` | Ataques | `bencao_pulada` | `exacto` | No |
| `pe4clTyJFqxB83rksa3s` | Tesoura numa perna só | No | `Verde` | Defensas | `tesoura_numa_perna_so` | `exacto_discrepancia_categoria` (manual: Desequilibrante) | No |
| `PFJfTDht7MLuc7S5FGw2` | Queda de Rim | No | `Verde` | Floreos | `queda_de_rim` | `exacto` | No |
| `sjz2g7NTwvZUp0kP7fpJ` | Ponteira | No | `Verde e Laranja` | Ataques | `ponteira` | `exacto` | No |
| `C6jMTH95A5C3V93Lb1ml` | Tesoura de Lado | No | `Verde e Laranja` | Defensas | `tesoura_de_lado` | `exacto_discrepancia_categoria` (manual: Desequilibrante) | No |
| `n3zQzpHJFOTWtTlZYbmC` | Corta Capim | No | `Verde e Laranja` | Floreos | `corta_capim` | `exacto` | No |
| `lPtQaauMOTSvczvylsMD` | Cabeçada | No | `Laranja` | Defensas | `cabecada` | `discrepancia_corda` (manual: C4 Verde e Laranja) | Sí |
| `JB520IBZLg1Z4rMqiHIR` | Banda de Frente | No | `Amarela` | Defensas | `banda_de_frente` | `discrepancia_corda` (manual: Bloque 5-6 Laranja / Laranja e Amarelo) | Sí |
| `nPc9AUD2ynr4JssiV0ys` | Vingativa | No | `Azul` | Defensas | `vingativa` | `discrepancia_corda` (manual: C4 Verde e Laranja) | Sí |

---

## 5. Cruce con el Glosario actual (`glosario_screen.dart` — 26 términos)

- **14 mapeos exactos y consistentes en categoría:** `Bênção`, `Martelo`, `Queixada`, `Armada`, `Meia-lua de compasso`, `Meia-lua de frente`, `Cocorinha`, `Negativa`, `Negativa de Angola`, `Rolamento na ginga`, `Esquiva básica`, `Arpão`, `Vingativa`, `Banda de costas`.
- **4 mapeos exactos con discrepancia de categoría:** `Aú`, `Bananeira`, `Macaco`, `Queda de rim` aparecen en el glosario bajo `Esquivas`, pero en el manual oficial pertenecen a `Movimentos de Solo`.
- **2 términos genéricos sin auto-asignar (pendientes de revisión):**
  - `Chapéu de couro` → candidatos: `chapeu_de_couro_em_pe` (C2) y `chapeu_de_couro_no_chao` (C3).
  - `Rasteira` → candidatos: `rasteira_em_pe` (C2), `rasteira_no_chao` (C2), `rasteira_baiana` (C4), `rasteira_de_costas` (C4), `rasteira_paulista` (B5-6).
- **6 términos culturales no técnicos:** `Apelido`, `Bateria`, `Batizado`, `Mestre`, `Axé`, `Roda`.
- **Nota adicional:** `Ginga` no está actualmente en `glosario_screen.dart`.

---

## 6. Estructura identificada del Currículo Infantil (12 cordas — pp. 13–25 / PDF 14–26)

Se deja modelada en `tracks.infantil` con prefijo separado `infantil_corda_01..12` para nunca mezclarse con Adulto:
- **Regla oficial:** Todas las cordas infantiles son de colores claros; inicia a los **3 años** y pasa a graduación adulta próximo a los **15 años** (cordas 1–3 para 3, 4 y 5 años; desde los 6 años toma la 4ª corda en adelante). En la **12ª corda**, el responsable evalúa qué grado adulto recibirá.
- **Dimensiones por corda infantil:** `comportamento`, `presenca` (75%), `movimentos_e_sequencias` *(cumulativo)*, `musicalidade`, `historia`.
- **Listado de las 12 cordas infantiles:**
  1. `infantil_corda_01`: Crua / Amarelo (3 anos) — pp. 15–16 / PDF 16–17
  2. `infantil_corda_02`: Crua / Laranja (4 anos) — p. 16 / PDF 17
  3. `infantil_corda_03`: Crua / Azul (5 anos) — pp. 16–17 / PDF 17–18
  4. `infantil_corda_04`: Crua / Verde (6–13 anos) — p. 17 / PDF 18
  5. `infantil_corda_05`: Verde — p. 18 / PDF 19
  6. `infantil_corda_06`: Verde / Amarelo — pp. 18–19 / PDF 19–20
  7. `infantil_corda_07`: Amarelo — p. 19 / PDF 20
  8. `infantil_corda_08`: Amarelo / Laranja — p. 20 / PDF 21
  9. `infantil_corda_09`: Laranja — p. 21 / PDF 22
  10. `infantil_corda_10`: Laranja / Azul — p. 22 / PDF 23
  11. `infantil_corda_11`: Azul — pp. 23–24 / PDF 24–25
  12. `infantil_corda_12`: Azul / Verde Escuro *(en currículo p.24: "AZUL E VERDE")* — pp. 24–25 / PDF 25–26

---

## 7. Puntos pendientes de aprobación pedagógica (`review_flags`)

1. **`REV-01` — Duplicado literal en Corda Crua B. SAIDAS (p. 31/PDF 32):** `Negativa` aparece en posiciones 3 y 5 (6 salidas únicas vs "7 saídas básicas"). ¿Se consolida en 6 o falta un 7º nombre?
2. **`REV-02` — Ítems dudosos en Bloque 5–6 (p. 42/PDF 43):** `C.6 Desequilibrante`, `C.7 Espelho - cruz` (¿1 o 2 técnicas?) y `B.2 Aú chibata pulado x` (+ `0` suelto).
3. **`REV-03` — Técnicas citadas solo en Cronogramas Semanales y encabezados `D-GOLPES E CONTRA GOLPES` vacíos:** Confirmar si `Puxada presa` (en drill de C3), `Ponteira de frente/lado` (drills C4), y `Banda trançada / Cutila com Tapona / Arrastão / Arqueada / Chapa de chão / Agodeme` (drills B5-6) quedan solo como contexto de drills o se promocionan al catálogo.
4. **`REV-04` — Video real compuesto `Cocorinha + base` (`WH4bG3SQ3CSd8ozb1619`):** Confirmar si se enlaza principalmente a `cocorinha` (con referencia a `ginga`) en `Crua`.
5. **`REV-05` — Videos reales con corda vacía (`Ginga`, `Passape`, `Martelo`):** Confirmar su asignación a Corda 1 `Crua`.
6. **`REV-06` — Discrepancias de corda en `/tutoriales` existentes (`Aú`, `Queixada`, `Armada`, `Meia Lua de Compasso`, `Cabeçada`, `Banda de Frente`, `Vingativa`):** Confirmar corrección al currículo oficial sin borrar los docs multimedia actuales.
7. **`REV-07` — Seed `tutoriales_service.dart`:** Confirmar deprecación de datos semilla desfasados respecto a los 21 docs reales en PED-03.
8. **`REV-08` — Glosario genérico (`Chapéu de couro` y `Rasteira`):** Decidir si enlazan a sus variantes o se expanden fichas individuales.
9. **`REV-09` — Taxonomía oficial:** Confirmar adopción de las 5 categorías del manual (`fundamento`, `golpe_de_ataque`, `saida_esquiva`, `movimento_de_solo`, `golpe_desequilibrante`) en UI y planificador.
10. **`REV-10` — Alias `Flick` vs `Flip`:** Confirmar equivalencia entre Adulto C4 (`Flick`) e Infantil C10–C12 (`flip`).

---

## 8. Propuesta técnica para PED-03 (Siguiente etapa tras aprobación)

1. **Aprobar respuestas de `REV-01`..`REV-10`:** Aplicar ajustes finales al catálogo JSON y re-ejecutar `validate_curriculum_catalog.js`.
2. **Importador idempotente controlado (Node.js Admin SDK, dry-run por defecto):**
   - Poblar colecciones separadas y limpias sin borrar `/tutoriales`:
     - `curriculum_movements/{movement_id}` (97+ movimientos canónicos compartibles entre Adulto e Infantil, con `glossary_ref` y `tutorial_doc_ids`).
     - `curriculum_cordas/{corda_id}` (`adulto_corda_01..06`, con orden, duración, evaluación, musicalidad, herencia y `shared_block_id`).
     - `curriculum_blocks/{block_id}` (`adulto_bloque_05_06`, con secciones y cronograma semanal).
   - Actualizar de forma no destructiva los 21 `/tutoriales` existentes solo con campos puente (`canonical_movement_id`, `curriculum_corda_ids`, `curriculum_synced_at`) preservando videos, vistas y likes.
3. **Reglas de lectura y consumo unificado (PED-04+):**
   - **Biblioteca única (alumnos + profesores):** Vista por corda (adulto actual + exploración de próximas cordas y graduaciones de profesor), buscador por movimiento canónico, ficha unificada (técnica + definición de glosario + video real si existe + secuencias/drills donde participa).
   - **Planificador IA de clases:** Inyectar desde `curriculum_cordas` / `curriculum_blocks` los movimientos y cronogramas exactos de la corda del grupo en `generarPlanClaseIA` para que las clases propuestas respondan fielmente al programa FIU.
