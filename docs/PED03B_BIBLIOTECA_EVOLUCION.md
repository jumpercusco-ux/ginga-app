# PED-03B / PED-03C — Evolución y Cierre Técnico de la Biblioteca Curricular FIU

> **Estado:** Implementación local **aprobada visualmente** (PED-03B-FINAL) y validada contra **Firebase Firestore Emulator (JDK 21)** en **PED-03C** usando exclusivamente `demo-ginga-test`.  
> **Fuente local:** Catálogo validado [fiu_adulto_v1.json](file:///Users/jumper/ginga_app/data/curriculum/fiu_adulto_v1.json). No importado aún a Firestore de producción.

---

## 1. Revisión previa de componentes existentes (Qué se conservó, refactorizó o sustituyó)

| Archivo / Componente | Estado | Decisión y justificación |
| :--- | :--- | :--- |
| [biblioteca_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/biblioteca_screen.dart) | **Evolucionado** | Se conservó como punto único de entrada en `HomeScreen` (y se conectó para profesores desde `InstructorClaseScreen` y `/biblioteca`), agregando el **Centro Curricular FIU** arriba y convirtiendo los 6 módulos clásicos (`Música`, `Tutoriales`, `Cultura`, `Glosario`, `Graduaciones`, `Nuestros Mestres`) a grid responsive (`1/2/3` cols). Se limpiaron imports no usados y código comentado muerto (`_LeccionCard`). |
| [glosario_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/glosario_screen.dart) | **Reutilizado / Refactor menor** | Se mantuvo íntegra la pantalla actual y se expuso `terminosOficiales` + `buscarPorTermino()` para que las fichas curriculares reutilicen las definiciones, pronunciación y *Tip del Mestre* reales sin duplicar datos. |
| [tutoriales_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/tutoriales_screen.dart) | **Conservado íntegro** | Se preservaron las reglas de visibilidad y bloqueo por corda para los 21 documentos vivos y los 5 videos reales. |
| [tutor_detail_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/tutor_detail_screen.dart) | **Reutilizado** | Se reutilizan `TutorialDetailLoader` y el reproductor `VideoPlayerController` + `TtsService` desde las fichas de movimiento (`MovimientoDetallePanel`). |
| [graduaciones_screen.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/graduaciones_screen.dart) | **Conservado + patrón extraído** | Se mantiene la pantalla completa de simbolismo/asistencias; el diseño de cintas trenzadas se extrajo al widget reutilizable `CordaRibbonBar`. |
| [tutorial_thumbnail.dart](file:///Users/jumper/ginga_app/lib/features/biblioteca/widgets/tutorial_thumbnail.dart) | **Conservado** | Sigue dando miniaturas por categoría en `TutorialesScreen` y `HomeScreen`. |
| `TutorialesService.inicializarTutorialesMockupSiVacia()` | **Deprecado seguro (PED-03A)** | Deshabilitado con `legacyMockSeedEnabled = false` sin romper la llamada existente en `InstructorClaseScreen`. |

---

## 2. Arquitectura unificada, Responsive y Perfiles

- **Móvil (`< 720px`) y Tablet (`720–1099px`):** [CurriculoBibliotecaScreen](file:///Users/jumper/ginga_app/lib/features/biblioteca/curriculo_biblioteca_screen.dart) usa selector superior `Adulto` / `Infantil`, barra horizontal de cordas `1..6` + hoja informativa `7..17`, toggle `Solo corda` vs `Acumulado 1..N`, buscador por nombre y alias confirmados, chips de las 5 categorías técnicas aprobadas y 3 pestañas (`Movimientos`, `Secuencias y Cronograma`, `Musicalidad y Eval.`). Al tocar un movimiento abre [MovimientoDetalleScreen](file:///Users/jumper/ginga_app/lib/features/biblioteca/movimiento_detalle_screen.dart).
- **Escritorio (`>= 1100px`):** Layout de 3 columnas: rail izquierdo de graduaciones (con accesos docentes para profesor), zona central en grid de 2 columnas, y panel derecho fijo (`MovimientoDetallePanel`) sin perder contexto.
- **Experiencia por perfil ([BibliotecaUserContext](file:///Users/jumper/ginga_app/lib/features/biblioteca/widgets/biblioteca_user_context.dart)):**
  - **Alumno:** visualiza su corda actual, su repertorio acumulado, próximas graduaciones disponibles y respeta exactamente las restricciones existentes sobre tutoriales.
  - **Profesor / Instructor / Admin:** consulta su propia graduación como practicante (incluso si es `Azul` o superior al bloque `1–6`), navega todo el catálogo y accede desde el mismo hub a `Gestionar Tutoriales` (`/instructor-tutoriales`) y `Pizarra y Planificador` (`/instructor-pizarra`).

---

## 3. Seguridad de reglas curriculares (`firestore.rules`)

Durante la auditoría se detectó que `match /users/{userId}` permite escritura autenticada, por lo que depender de `get(...users/$(request.auth.uid)).data.rol` en `isCurriculumAdmin()` exponía un vector de auto-elevación de rol.
- Se endureció [firestore.rules](file:///Users/jumper/ginga_app/firestore.rules) para validar únicamente **Custom Claims firmados** (`request.auth.token.admin == true || request.auth.token.curriculum_admin == true`).
- Se actualizó [test_curriculum_firestore_rules.js](file:///Users/jumper/ginga_app/scripts/test_curriculum_firestore_rules.js) agregando el test `07_auto_elevacion_en_users_rol_admin_sin_claim_es_rechazada` (sin desplegar reglas todavía).

---

## 4. Estado Técnico y Limitaciones Actuales (`PED-03C`)

1. **Gate de Firebase Firestore Emulator (APROBADO en PED-03C):** Desbloqueado mediante `/opt/homebrew/opt/openjdk@21` sin alterar el JDK global; reglas curriculares (`7/7 PASS`), reglas generales (`test_firestore_rules.js`) e importador idempotente (`6/6 PASS` en `demo-ginga-test` preservando 21 tutoriales y 5 videos reales) verificados. La importación a Firestore de **producción** sigue bloqueada por seguridad hasta aprobación expresa.
2. **Digitalización parcial oficial:** El contenido técnico detallado cubre Adulto Cordas `1` a `6` (`97` movimientos, 94 elegibles IA y 3 en revisión técnica). Adulto Cordas `7–17` e Infantil (`12` cordas) muestran estructura oficial e indicador explícito *"Pendiente de digitalización"*.
3. **Multimedia pendiente:** De los 21 tutoriales existentes, 5 tienen video real y 16 son fichas sin video grabado; la UI añade el filtro `Con video (N)` y conserva *"Pendiente de digitalización"* sin texto inventado.
4. **Contrato listo para PED-04:** Se completó [PED-03B-FINAL] incluyendo `CurriculumSelectionContract` y `CurriculumMovementSelectionItem` en [curriculum_models.dart](file:///Users/jumper/ginga_app/lib/core/models/curriculum_models.dart) para selección manual opt-in sin implementar todavía generación IA.

---

## 5. Propuesta concreta de integración con el Planificador IA (`PED-04`)

1. **Pre-carga contextual desde la Biblioteca hacia Pizarra:** Permitir pasar argumentos opcionales (`initialCordaId`, `initialMovementId`) al navegar desde `BibliotecaScreen`/`CurriculoBibliotecaScreen` hacia `InstructorPizarraScreen` (`/instructor-pizarra`), de modo que el profesor pueda abrir una clase ya enfocada en una corda o técnica elegida mientras consulta la biblioteca.
2. **Inyección de repertorio oficial en `generarPlanClaseIA`:**
   - Usar `CurriculumRepository.buildAiPlannerCurriculumPayload(track, upToCordaIndex)` descrito en [CURRICULUM_AI_PLANNER_CONTRACT.md](file:///Users/jumper/ginga_app/docs/CURRICULUM_AI_PLANNER_CONTRACT.md).
   - Garantizar que las sugerencias de la IA solo utilicen los 94 movimientos `ai_planner_eligible == true` (excluyendo `Desequilibrante`, `Espelho - cruz`, `Aú chibata pulado` y equivalencias no confirmadas), respeten el bloque compartido 5–6 y tomen en cuenta las combinaciones y `cronograma_semanal` reales de FIU.
3. **Verificación previa obligatoria:** Ejecutar el gate de Firebase Emulator con JDK 21 antes de poblar Firestore y conectar la lectura remota (`FirestoreCurriculumDataSource`).
