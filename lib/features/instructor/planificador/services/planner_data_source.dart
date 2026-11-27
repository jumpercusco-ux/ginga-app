import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_plan_models.dart';

/// Fuente de datos desacoplada para el Planificador V2 (fixtures locales aislados o Firestore).
abstract class PlannerDataSource {
  bool get isPersistentRemote => false;

  Future<List<PlannerGroupProfile>> loadGroups();
  Future<List<ClassPlanModel>> loadPlans();
  Future<List<PlannerResourceItem>> loadResources();
  Future<List<TaughtSessionRecord>> loadHistory();

  /// Carga individual por ID (útil para resolver conflictos entre dispositivos).
  Future<ClassPlanModel?> loadPlanById(String planId) async {
    final all = await loadPlans();
    for (final p in all) {
      if (p.id == planId) return p;
    }
    return null;
  }

  /// Guarda un plan o borrador aplicando control de concurrencia optimista si se pasa [expectedRevision].
  Future<ClassPlanModel> savePlan(
    ClassPlanModel plan, {
    int? expectedRevision,
    String? deviceId,
  }) async {
    await saveLocalDraft(plan);
    return plan;
  }

  /// Compatibilidad retroactiva: guarda un borrador sin retornar revisión.
  Future<void> saveLocalDraft(ClassPlanModel draft);

  /// Transiciona explícitamente el ciclo de vida validando [ClassPlanStatus.canTransitionTo].
  Future<ClassPlanModel> updatePlanStatus(
    String planId,
    ClassPlanStatus nextStatus, {
    int? expectedRevision,
    String? deviceId,
  }) async {
    final current = await loadPlanById(planId);
    if (current == null) {
      throw StateError('No se encontró el plan $planId.');
    }
    if (!current.planStatus.canTransitionTo(nextStatus)) {
      throw StateError(
        'Transición inválida de ${current.planStatus.label} a ${nextStatus.label}.',
      );
    }
    return savePlan(
      current.copyWith(planStatus: nextStatus, updatedAt: DateTime.now()),
      expectedRevision: expectedRevision ?? current.revision,
      deviceId: deviceId,
    );
  }

  /// Crea o actualiza un recurso de Pizarra sin marcarlo como usado automáticamente.
  Future<PlannerResourceItem> saveResource(PlannerResourceItem resource) async =>
      resource;

  /// Registra una sesión finalizada en Historial y contabiliza recursos solo de ejercicios completados.
  /// Devuelve `true` si se registró por primera vez o `false` si [session.sessionId] ya había sido contabilizado.
  Future<bool> recordCompletedLiveSession(
    TaughtSessionRecord session, {
    required Set<String> taughtResourceIds,
  });
}

/// Almacén compartido en memoria para simular múltiples clientes/dispositivos en pruebas deterministas.
class InMemoryPlannerBackingStore {
  final List<PlannerGroupProfile> groups;
  final List<ClassPlanModel> plans;
  final List<PlannerResourceItem> resources;
  final List<TaughtSessionRecord> history;
  final Set<String> recordedSessionIds = {};

  InMemoryPlannerBackingStore({
    required List<PlannerGroupProfile> groups,
    required List<ClassPlanModel> plans,
    required List<PlannerResourceItem> resources,
    required List<TaughtSessionRecord> history,
  })  : groups = List.of(groups),
        plans = List.of(plans),
        resources = List.of(resources),
        history = List.of(history) {
    for (final s in history) {
      recordedSessionIds.add(s.sessionId);
    }
  }
}

/// Implementación local aislada con fixtures realistas libres de PII para pruebas y vista previa.
class InMemoryPlannerDataSource implements PlannerDataSource {
  final InMemoryPlannerBackingStore _store;
  final String? instructorUid;
  final String? defaultDeviceId;
  bool simulateConnectionError = false;
  Object? nextWriteError;

  @override
  bool get isPersistentRemote => false;

  InMemoryPlannerDataSource({
    required List<PlannerGroupProfile> groups,
    required List<ClassPlanModel> plans,
    required List<PlannerResourceItem> resources,
    required List<TaughtSessionRecord> history,
    this.instructorUid,
    this.defaultDeviceId,
  }) : _store = InMemoryPlannerBackingStore(
          groups: groups,
          plans: plans,
          resources: resources,
          history: history,
        );

  InMemoryPlannerDataSource.shared({
    required InMemoryPlannerBackingStore store,
    this.instructorUid,
    this.defaultDeviceId,
  }) : _store = store;

  InMemoryPlannerBackingStore get backingStore => _store;

  factory InMemoryPlannerDataSource.demoFixtures() =>
      _buildDemoFixtures(includeCopilot8of8: false);

  factory InMemoryPlannerDataSource.copilotDemoFixtures() =>
      _buildDemoFixtures(includeCopilot8of8: true);

  static InMemoryPlannerDataSource _buildDemoFixtures({
    required bool includeCopilot8of8,
  }) {
    return InMemoryPlannerDataSource(
      groups: const [
        PlannerGroupProfile(
          id: 'clase_adultos_mj_1900',
          name: 'Adultos M/J 19:00',
          source: PlannerGroupSource.realClass,
          audienceType: PlannerAudienceType.adultos,
          scheduleSummary: 'Martes y Jueves · 19:00',
          ageMin: 16,
          ageMax: 40,
          participantsCount: 12,
          observedCordasSummary: {
            'Corda Crua': 4,
            'Corda Crua e Verde': 4,
            'Corda Verde': 4,
          },
          defaultDistribution: ExperienceDistribution(
            principiantes: 5,
            intermedios: 5,
            avanzados: 2,
            manuallyConfirmed: false,
          ),
          suggestedTargetAdultoCordaIndex: 2,
        ),
        PlannerGroupProfile(
          id: 'clase_kids_mj_1800',
          name: 'Infantil M/J 18:00',
          source: PlannerGroupSource.realClass,
          audienceType: PlannerAudienceType.infantil,
          scheduleSummary: 'Martes y Jueves · 18:00',
          ageMin: 5,
          ageMax: 11,
          participantsCount: 10,
          observedCordasSummary: {'Sin graduación FIU validada': 10},
          defaultDistribution: ExperienceDistribution(
            principiantes: 6,
            intermedios: 2,
            avanzados: 2,
            manuallyConfirmed: false,
          ),
        ),
        PlannerGroupProfile(
          id: 'clase_roda_sabado_mixto',
          name: 'Entreno & Roda Mixto Sábado',
          source: PlannerGroupSource.realClass,
          audienceType: PlannerAudienceType.mixto,
          scheduleSummary: 'Sábado · 14:30',
          ageMin: 8,
          ageMax: 42,
          participantsCount: 18,
          observedCordasSummary: {'Grupo variado': 18},
          defaultDistribution: ExperienceDistribution(
            principiantes: 8,
            intermedios: 6,
            avanzados: 4,
            manuallyConfirmed: false,
          ),
        ),
      ],
      plans: [
        // Plan V1 legacy real (sin schema_version) para validar compatibilidad hacia atrás
        ClassPlanModel.fromMap('legacy_plan_01', {
          'titulo': 'Base de Ginga, Bênção y Esquiva (Plan V1)',
          'duracion_total': 60,
          'nivel': 'Adultos',
          'enfoque': 'Técnica & Movilidad',
          'objetivo': 'Consolidar postura de base y protección facial en parejas.',
          'veces_impartida': 2,
          'created_at': '2026-11-12T15:00:00Z',
          'ultima_ejecucion': '2026-11-19T20:00:00Z',
          'bloques': [
            {
              'fase': 'Movilidad Articular & Activación Funcional',
              'duracion_min': 12,
              'ejercicios': [
                {
                  'nombre': 'Movilidad articular + ginga progresiva',
                  'detalle': 'Trabajo continuo sin filas por 12 minutos.',
                  'recurso_relacionado': null,
                },
              ],
            },
            {
              'fase': 'Técnica Marcial & Secuencias en Parejas',
              'duracion_min': 28,
              'ejercicios': [
                {
                  'nombre': 'Bênção con salida en cocorinha',
                  'detalle': 'Parejas alternando ataque frontal y esquiva baja.',
                  'recurso_relacionado': 'Drill esquiva en parejas',
                },
              ],
            },
            {
              'fase': 'Roda de Treino & Jogo Guiado',
              'duracion_min': 20,
              'ejercicios': [
                {
                  'nombre': 'Roda cadenciada São Bento Grande',
                  'detalle': 'Rotación cada 60 segundos con énfasis en diálogo.',
                },
              ],
            },
          ],
        }),
        // Plan V2 Adulto con orígenes diferenciados
        ClassPlanModel.fromMap('v2_plan_adulto_01', {
          'schema_version': 2,
          'plan_status': 'saved',
          'creation_mode': 'avanzada',
          'titulo': 'Esquivas bajas y transición a rolê continuo',
          'duracion_total': 60,
          'nivel': 'Adultos',
          'audience_type': 'adultos',
          'curriculum_scope': 'adulto_fiu',
          'enfoque': 'Técnica · Secuencias',
          'objetivo': 'Conectar cocorinha y rolê evitando tiempos muertos.',
          'objetivos': [
            'Conectar cocorinha y rolê evitando tiempos muertos.',
            'Mantener cobertura facial y base estable en parejas.',
          ],
          'veces_impartida': 1,
          'created_at': '2026-11-20T18:00:00Z',
          'ultima_ejecucion': '2026-11-23T20:00:00Z',
          'group_snapshot': {
            'group_name': 'Adultos M/J 19:00',
            'age_min': 16,
            'age_max': 38,
            'participants': 12,
            'experience_distribution': {
              'principiantes': 5,
              'intermedios': 5,
              'avanzados': 2,
              'manually_confirmed': true,
            },
          },
          'bloques': [
            {
              'block_id': 'blk_1',
              'fase': 'Movilidad Articular & Activación',
              'duracion_min': 12,
              'ejercicios': [
                {
                  'exercise_id': 'ex_1_1',
                  'nombre': 'Juego espejo de esquivas en parejas',
                  'detalle_paso_a_paso': '6 parejas simultáneas alternando marcas alta/baja.',
                  'duracion_min': 12,
                  'organizacion': 'Rotación por parejas',
                  'materiales': ['Conos'],
                  'seguridad': 'Mantener 2 metros entre parejas al desplazar.',
                  'content_origin': 'teacher_resource',
                  'linked_resource_ids': ['idea_res_02'],
                  'resource_usage_notes': {
                    'idea_res_02': 'Aplicar en 2 rondas de 90s antes de pasar a cocorinha.',
                  },
                },
              ],
            },
            {
              'block_id': 'blk_2',
              'fase': 'Técnica & Secuencias',
              'duracion_min': 28,
              'ejercicios': [
                {
                  'exercise_id': 'ex_2_1',
                  'nombre': 'Cocorinha + salida en Rolê',
                  'detalle_paso_a_paso': 'Progresión en 3 ritmos con cambio de pareja cada 2 minutos.',
                  'duracion_min': 28,
                  'organizacion': 'Rotación por parejas',
                  'diferenciacion_principiantes': 'Pausa breve en cocorinha verificando apoyo de mano.',
                  'diferenciacion_intermedios': 'Mantener mirada continua hacia la pareja durante todo el rolê.',
                  'diferenciacion_avanzados': 'Enlazar con negativa corta y entrada de meia lua.',
                  'seguridad': 'Evitar apoyar rodillas al girar en rolê.',
                  'observaciones_profesor': 'Corregir mirada hacia el compañero durante el giro.',
                  'content_origin': 'official_fiu_curriculum',
                  'curriculum_movement_ids': ['cocorinha', 'role'],
                },
              ],
            },
            {
              'block_id': 'blk_3',
              'fase': 'Roda & Vuelta a la Calma',
              'duracion_min': 20,
              'ejercicios': [
                {
                  'exercise_id': 'ex_3_1',
                  'nombre': 'Roda Benguela de diálogo corporal',
                  'detalle_paso_a_paso': 'Entradas obligatorias saliendo en rolê.',
                  'duracion_min': 20,
                  'organizacion': 'Roda única con rotación cada 60s',
                  'materiales': ['Berimbau', 'Pandeiro', 'Atabaque'],
                  'content_origin': 'ai_complementary_proposal',
                },
              ],
            },
          ],
        }),
        // Plan V2 Infantil sin currículo adulto (40 min planificados de 60 min objetivo)
        ClassPlanModel.fromMap('v2_plan_infantil_01', {
          'schema_version': 2,
          'plan_status': 'saved',
          'creation_mode': 'rápida',
          'titulo': 'Juegos motores y palmas de terreiro (Kids)',
          'duracion_total': 60,
          'nivel': 'Niños',
          'audience_type': 'infantil',
          'curriculum_scope': 'infantil_fiu_pending',
          'enfoque': 'Juegos & Agilidad',
          'objetivo': 'Coordinación motora, atención grupal y palmas en 3 tiempos.',
          'objetivos': [
            'Coordinación motora, atención grupal y palmas en 3 tiempos.',
          ],
          'veces_impartida': 0,
          'created_at': '2026-11-22T14:00:00Z',
          'group_snapshot': {
            'group_name': 'Kids M/J 18:00',
            'age_min': 6,
            'age_max': 11,
            'participants': 10,
            'experience_distribution': {
              'principiantes': 6,
              'intermedios': 4,
              'avanzados': 0,
              'manually_confirmed': true,
            },
          },
          'bloques': [
            {
              'block_id': 'blk_k1',
              'fase': 'Calentamiento Lúdico & Juegos Motores',
              'duracion_min': 20,
              'ejercicios': [
                {
                  'exercise_id': 'ex_k1_1',
                  'nombre': 'Circuito animal: sapo, cangrejo y aú lento',
                  'detalle_paso_a_paso': '2 carriles paralelos para evitar filas.',
                  'duracion_min': 20,
                  'organizacion': 'Estaciones en 2 carriles',
                  'materiales': ['Conos', 'Colchonetas', 'Aros'],
                  'seguridad': 'Cuidar distancia de caída al pasar por las colchonetas.',
                  'content_origin': 'teacher_resource',
                  'linked_resource_ids': ['idea_res_04'],
                },
              ],
            },
            {
              'block_id': 'blk_k2',
              'fase': 'Roda Infantil & Palmas',
              'duracion_min': 20,
              'ejercicios': [
                {
                  'exercise_id': 'ex_k2_1',
                  'nombre': 'Coro responsorial y ritmo en pandeiro',
                  'detalle_paso_a_paso': 'Turnos cortos de 30s con refuerzo positivo.',
                  'duracion_min': 20,
                  'organizacion': 'Roda en semicírculo',
                  'materiales': ['Pandeiro'],
                  'content_origin': 'ai_complementary_proposal',
                },
              ],
            },
          ],
        }),
        if (includeCopilot8of8) ...[
        // Demostración local basada en el intento real 8/8 (PED-04C2-E -> Copiloto PED-04C3)
        ClassPlanModel.fromMap('v2_plan_infantil_8of8_demo', {
          'schema_version': 2,
          'plan_status': 'draft',
          'creation_mode': 'avanzada',
          'titulo': 'Infantil M/J 18:00 · Técnicas · Juegos · Acrobacias · Musicalidad (60 min)',
          'duracion_total': 60,
          'nivel': 'Infantil',
          'audience_type': 'infantil',
          'curriculum_scope': 'infantil_fiu_pending',
          'enfoque': 'Técnicas · Juegos · Acrobacias · Musicalidad',
          'objetivo': 'Trabajar Ginga, Armada y Aú mediante progresiones diferenciadas por nivel, esquivas, juegos de capoeira, musicalidad y participación simultánea.',
          'objetivos': [
            'Trabajar Ginga, Armada y Aú mediante progresiones diferenciadas por nivel, esquivas, juegos de capoeira, musicalidad y participación simultánea.',
          ],
          'group_snapshot': {
            'group_name': 'Infantil M/J 18:00',
            'age_min': 5,
            'age_max': 11,
            'participants': 10,
            'experience_distribution': {
              'principiantes': 6,
              'intermedios': 2,
              'avanzados': 2,
              'manually_confirmed': true,
            },
          },
          'space_snapshot': {
            'space_size': 'mediano',
            'floor_type': 'desconocido',
            'available_mats': null,
            'instructors_available': 1,
          },
          'bloques': [
            {
              'block_id': 'blk_1',
              'fase': 'Calentamiento',
              'fase_tipo': 'calentamiento',
              'duracion_min': 10,
              'ejercicios': [
                {
                  'exercise_id': 'blk_1_ex_1',
                  'nombre': 'Movimientos Simultáneos de Ginga y Esquiva',
                  'tipo_actividad': 'ejercicio_tecnico',
                  'detalle': 'Preparación: Formar un círculo con todos los participantes. Paso a paso: iniciar Ginga continua todos al mismo tiempo y alternar con Esquiva a la señal sin filas. Tiempos internos (Ginga 2 min + Esquiva 3 min = total: 5 min).',
                  'duracion_min': 5,
                  'organizacion': 'Todos simultáneamente',
                  'materiales': [],
                  'seguridad': 'Asegurarse de que el espacio esté libre de obstáculos.',
                  'diferenciacion_principiantes': 'Enfocarse en la Ginga a ritmo pausado.',
                  'diferenciacion_intermedios': 'Introducir la Esquiva con más rapidez y precisión.',
                  'diferenciacion_avanzados': 'Perfeccionar Ginga y Esquiva con fluidez y control.',
                  'sugerencias_ia': 'Corregir falta de sincronización con demostraciones claras.',
                  'technical_movement_refs': ['Ginga', 'Esquiva'],
                  'tiempos_internos': [
                    {'etapa': 'Ginga', 'minutos': 2},
                    {'etapa': 'Esquiva', 'minutos': 3},
                  ],
                  'content_origin': 'ai_complementary_proposal',
                },
                {
                  'exercise_id': 'blk_1_ex_2',
                  'nombre': 'Introducción a Armada y Aú',
                  'tipo_actividad': 'ejercicio_tecnico',
                  'detalle': 'Preparación: parejas alternando soporte visual y ejecución controlada de Armada y Aú con apoyo firme de manos, cambiando de rol cada 2 min. Tiempos internos (Armada 2 min + Aú 3 min = total: 5 min).',
                  'duracion_min': 5,
                  'organizacion': 'Rotación por parejas',
                  'materiales': [],
                  'seguridad': 'Espacio adecuado entre parejas.',
                  'diferenciacion_principiantes': 'Técnica básica de Armada con control cercano.',
                  'diferenciacion_intermedios': 'Armada sin apoyo manteniendo equilibrio.',
                  'diferenciacion_avanzados': 'Fluidez y control en Armada y Aú.',
                  'sugerencias_ia': 'Fomentar equilibrio antes de acelerar el giro.',
                  'technical_movement_refs': ['Armada', 'Aú'],
                  'tiempos_internos': [
                    {'etapa': 'Armada', 'minutos': 2},
                    {'etapa': 'Aú', 'minutos': 3},
                  ],
                  'content_origin': 'ai_complementary_proposal',
                },
              ],
            },
            {
              'block_id': 'blk_2',
              'fase': 'Técnica',
              'fase_tipo': 'tecnica',
              'duracion_min': 16,
              'ejercicios': [
                {
                  'exercise_id': 'blk_2_ex_1',
                  'nombre': 'Progresión de Ginga y Armada',
                  'tipo_actividad': 'ejercicio_tecnico',
                  'detalle': 'Progresión bilateral de Ginga conectando hacia giro controlado de Armada al pulso de palmas sin filas. Tiempos internos (Introducción a Ginga 2 min + Práctica en parejas 4 min + Introducción a Armada 2 min = total: 8 min).',
                  'duracion_min': 8,
                  'organizacion': 'Todos simultáneamente',
                  'materiales': [],
                  'seguridad': 'Distancia segura entre compañeros.',
                  'diferenciacion_principiantes': 'Ginga y Armada lentas con pausas breves.',
                  'diferenciacion_intermedios': 'Transición fluida entre Ginga y Armada.',
                  'diferenciacion_avanzados': 'Variaciones limpias enlazando hacia Aú.',
                  'sugerencias_ia': 'Mantener peso centrado y mirada al frente.',
                  'technical_movement_refs': ['Ginga', 'Armada'],
                  'tiempos_internos': [
                    {'etapa': 'Introducción a Ginga', 'minutos': 2},
                    {'etapa': 'Práctica de Ginga en parejas', 'minutos': 4},
                    {'etapa': 'Introducción a Armada', 'minutos': 2},
                  ],
                  'content_origin': 'ai_complementary_proposal',
                },
                {
                  'exercise_id': 'blk_2_ex_2',
                  'nombre': 'Progresión de Aú y Esquiva',
                  'tipo_actividad': 'ejercicio_tecnico',
                  'detalle': 'Progresión controlada de Aú y Esquiva al pulso de palmas rotando parejas cada 2 minutos. Tiempos internos (Introducción a Aú 2 min + Práctica de Aú 4 min + Introducción a Esquiva 2 min = total: 8 min).',
                  'duracion_min': 8,
                  'organizacion': 'Todos simultáneamente',
                  'materiales': [],
                  'seguridad': 'Espacio despejado para apoyo de manos.',
                  'diferenciacion_principiantes': 'Aú bajo con apoyo de manos y esquiva simple.',
                  'diferenciacion_intermedios': 'Conexión continua entre Aú y Esquiva.',
                  'diferenciacion_avanzados': 'Combinaciones rápidas y limpias.',
                  'sugerencias_ia': 'Recordar apoyar manos firmes al iniciar Aú.',
                  'technical_movement_refs': ['Aú', 'Esquiva'],
                  'tiempos_internos': [
                    {'etapa': 'Introducción a Aú', 'minutos': 2},
                    {'etapa': 'Práctica de Aú en parejas', 'minutos': 4},
                    {'etapa': 'Introducción a Esquiva', 'minutos': 2},
                  ],
                  'content_origin': 'ai_complementary_proposal',
                },
              ],
            },
            {
              'block_id': 'blk_3',
              'fase': 'Juegos de capoeira',
              'fase_tipo': 'juegos',
              'duracion_min': 12,
              'ejercicios': [
                {
                  'exercise_id': 'blk_3_ex_1',
                  'nombre': 'Juego espejo de esquivas por señales',
                  'tipo_actividad': 'juego_dinamico',
                  'detalle': 'Preparación: parejas a distancia segura. Reglas y señales: cambiar esquiva a la señal (alternativa: palmas y voz si no hay instrumento disponible). Rondas y rotación: rondas de 2 min alternando rol. Tiempos internos (Esquivas por señales 2 min + Cambio de roles 4 min = total: 6 min).',
                  'duracion_min': 6,
                  'organizacion': 'Todos simultáneamente',
                  'materiales': [],
                  'seguridad': 'Suficiente espacio entre parejas.',
                  'diferenciacion_principiantes': 'Esquivas simples progresivas.',
                  'diferenciacion_intermedios': 'Esquivas más ágiles y variadas.',
                  'diferenciacion_avanzados': 'Esquiva rápida con salida encadenada.',
                  'sugerencias_ia': 'Fomentar atención visual constante al compañero.',
                  'technical_movement_refs': ['Esquiva'],
                  'content_origin': 'teacher_resource',
                  'linked_resource_ids': ['idea_res_02'],
                  'resource_usage_notes': {
                    'idea_res_02': 'Aplicar como juego central de reacción.',
                  },
                  'tiempos_internos': [
                    {'etapa': 'Esquivas por señales', 'minutos': 2},
                    {'etapa': 'Cambio de roles', 'minutos': 4},
                  ],
                },
                {
                  'exercise_id': 'blk_3_ex_2',
                  'nombre': 'Progresión de Ginga y Armada',
                  'tipo_actividad': 'ejercicio_tecnico',
                  'detalle': 'Preparación: estaciones simultáneas con 2 m libres. Paso a paso: Ginga continua y Armada controlada por parejas. Tiempos internos (Práctica de Ginga 2 min + Práctica de Armada 4 min = total: 6 min).',
                  'duracion_min': 6,
                  'organizacion': 'Estaciones simultáneas',
                  'materiales': [],
                  'seguridad': 'Área libre de obstáculos.',
                  'diferenciacion_principiantes': 'Forma básica de Ginga y Armada controlada.',
                  'diferenciacion_intermedios': 'Armada más fluida con retorno estable.',
                  'diferenciacion_avanzados': 'Velocidad y precisión en transición.',
                  'sugerencias_ia': 'Cuidar alineación postural.',
                  'technical_movement_refs': ['Ginga', 'Armada'],
                  'tiempos_internos': [
                    {'etapa': 'Práctica de Ginga', 'minutos': 2},
                    {'etapa': 'Práctica de Armada', 'minutos': 4},
                  ],
                  'content_origin': 'ai_complementary_proposal',
                },
              ],
            },
            {
              'block_id': 'blk_4',
              'fase': 'Acrobacias en Suelo',
              'fase_tipo': 'acrobacias_suelo',
              'duracion_min': 11,
              'ejercicios': [
                {
                  'exercise_id': 'blk_4_ex_1',
                  'nombre': 'Preparación de Aú con Apoyos de Manos',
                  'tipo_actividad': 'progresion_suelo',
                  'detalle': 'Preparación: círculo amplio en el salón. Paso a paso: Ginga, Cocorinha y apoyos firmes de manos pasando pies bajo control. Rondas/rotación: rotar pareja cada 2 minutos. Tiempos internos (Ejercicio de Ginga y Cocorinha 2 min + Práctica del Aú con apoyo 4 min = total: 6 min).',
                  'duracion_min': 6,
                  'organizacion': 'Todos simultáneamente',
                  'materiales': [],
                  'seguridad': 'Espacio libre sin impactos bruscos.',
                  'diferenciacion_principiantes': 'Ginga y Cocorinha con apoyo progresivo de manos.',
                  'diferenciacion_intermedios': 'Aú lateral controlado con manos firmes.',
                  'diferenciacion_avanzados': 'Aú limpio cuidando aterrizaje suave.',
                  'sugerencias_ia': 'Mirada al frente y dedos separados en apoyo.',
                  'technical_movement_refs': ['Ginga', 'Aú', 'Cocorinha'],
                  'tiempos_internos': [
                    {'etapa': 'Ejercicio de Ginga y Cocorinha', 'minutos': 2},
                    {'etapa': 'Práctica del Aú con apoyo', 'minutos': 4},
                  ],
                  'content_origin': 'ai_complementary_proposal',
                },
                {
                  'exercise_id': 'blk_4_ex_2',
                  'nombre': 'Ejercicio de Rolê y Esquiva',
                  'tipo_actividad': 'progresion_suelo',
                  'detalle': 'Transición baja controlada en Rolê lateral combinada con Esquiva en parejas cada 2 minutos. Tiempos internos (Calentamiento con Ginga 2 min + Práctica de Rolê y Esquiva 3 min = total: 5 min).',
                  'duracion_min': 5,
                  'organizacion': 'Rotación por parejas',
                  'materiales': [],
                  'seguridad': 'Sin rodadas cervicales ni obstáculos en piso.',
                  'diferenciacion_principiantes': 'Rolê lateral lento y controlado.',
                  'diferenciacion_intermedios': 'Enlazar Rolê con Esquiva lateral.',
                  'diferenciacion_avanzados': 'Transiciones fluidas a ambos lados.',
                  'sugerencias_ia': 'Mantener mirada continua hacia la pareja.',
                  'technical_movement_refs': ['Rolê', 'Esquiva'],
                  'tiempos_internos': [
                    {'etapa': 'Calentamiento con Ginga', 'minutos': 2},
                    {'etapa': 'Práctica de Rolê y Esquiva', 'minutos': 3},
                  ],
                  'content_origin': 'ai_complementary_proposal',
                },
              ],
            },
            {
              'block_id': 'blk_5',
              'fase': 'Roda y musicalidad',
              'fase_tipo': 'roda_musicalidad',
              'duracion_min': 11,
              'ejercicios': [
                {
                  'exercise_id': 'blk_5_ex_1',
                  'nombre': 'Mini-Roda Musical',
                  'tipo_actividad': 'musicalidad_roda',
                  'detalle': 'Preparación: círculo con canto responsorial y palmas al pulso. Rondas/rotación: todos participan y entran por turnos breves aplicando Ginga, Armada, Aú y Esquiva. Tiempos internos (Canto y palmas 2 min + Mini-roda con movimientos 6 min + Cierre positivo 3 min = total: 11 min).',
                  'duracion_min': 11,
                  'organizacion': 'Todos simultáneamente',
                  'materiales': [],
                  'seguridad': 'Cero contacto; amplitud uniforme de la roda.',
                  'diferenciacion_principiantes': 'Ginga y Armada al ritmo de las palmas.',
                  'diferenciacion_intermedios': 'Integrar Aú controlado respetando el coro.',
                  'diferenciacion_avanzados': 'Perfeccionar Armada y Aú con fluidez musical.',
                  'sugerencias_ia': 'Evitar acelerar el pulso de las palmas.',
                  'technical_movement_refs': ['Ginga', 'Armada', 'Aú', 'Esquiva'],
                  'tiempos_internos': [
                    {'etapa': 'Canto y palmas', 'minutos': 2},
                    {'etapa': 'Mini-roda con movimientos', 'minutos': 6},
                    {'etapa': 'Cierre positivo y retroalimentación', 'minutos': 3},
                  ],
                  'cancionero_reference': {
                    'song_title': 'Marinheiro só',
                    'rhythm': 'Corrido',
                    'audience_fit': 'infantil',
                    'cantiga_id': null,
                    'lookup_hint': 'Canción tradicional infantil para mini-roda.',
                  },
                  'content_origin': 'ai_complementary_proposal',
                },
              ],
            },
          ],
        }),
        ],
      ],
      resources: const [
        PlannerResourceItem(
          resourceId: 'idea_res_01',
          title: 'Drill esquiva en parejas sin pausa',
          type: 'video',
          category: 'Técnica',
          audienceLabel: 'Adultos',
          notes: '3 rondas de 90s alternando atacante y defensa en cocorinha.',
          url: 'https://www.instagram.com/reel/demo_drill_esquiva',
          hasBeenTaught: true,
          timesUsed: 1,
        ),
        PlannerResourceItem(
          resourceId: 'idea_res_02',
          title: 'Juego espejo de esquivas por señales',
          type: 'nota',
          category: 'Juegos',
          audienceLabel: 'Todos',
          notes: 'Palma alta = cocorinha; palma lateral = negativa corta.',
          hasBeenTaught: true,
          timesUsed: 2,
        ),
        PlannerResourceItem(
          resourceId: 'idea_res_03',
          title: 'Progresión segura de Aú batido desde banco',
          type: 'video',
          category: 'Acrobacias',
          audienceLabel: 'Adultos',
          notes: 'Colchoneta lateral y bloqueo de codos antes de despegar.',
          url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          hasBeenTaught: false,
          timesUsed: 0,
        ),
        PlannerResourceItem(
          resourceId: 'idea_res_04',
          title: 'Diagrama de circuito motor en 4 estaciones',
          type: 'imagen',
          category: 'Calentamiento',
          audienceLabel: 'Niños',
          notes: 'Estaciones de 45s sin espera: sapo, macaco corto y rolê.',
          thumbnailUrl: 'assets/images/ginga_logo.png',
          hasBeenTaught: false,
          timesUsed: 0,
        ),
        PlannerResourceItem(
          resourceId: 'idea_res_05',
          title: 'Referencia musical: cadencia de São Bento Grande',
          type: 'link',
          category: 'Roda',
          audienceLabel: 'Todos',
          notes: 'Introducir coro antes de abrir el juego de São Bento.',
          url: 'https://capoeirafiu.example/referencias/sao-bento',
          hasBeenTaught: false,
          timesUsed: 0,
        ),
      ],
      history: [
        TaughtSessionRecord(
          sessionId: 'ses_20261123_adultos',
          planId: 'v2_plan_adulto_01',
          planTitle: 'Esquivas bajas y transición a rolê continuo',
          groupId: 'clase_adultos_mj_1900',
          groupName: 'Adultos M/J 19:00',
          audienceType: PlannerAudienceType.adultos,
          date: DateTime.now().subtract(const Duration(days: 3)),
          durationMin: 60,
          attendeesCount: 12,
          completedExercisesCount: 3,
          totalExercisesCount: 3,
          completedExercises: const [
            'Juego espejo de esquivas en parejas',
            'Cocorinha + salida en Rolê',
            'Roda Benguela de diálogo corporal',
          ],
          groupResponse: 'Excelente',
          practicedMovements: const ['Ginga', 'Cocorinha', 'Rolê'],
          summaryNote:
              'Fluidez alta en parejas; las rotaciones de 60s evitaron tiempos muertos.',
          difficulties:
              'Mantener la mirada continua al pasar de cocorinha a rolê en principiantes.',
          reinforceContent:
              'Cobertura facial en transición de rolê y entrada sin pausa.',
          pendingNextSession:
              'Añadir entrada con meia lua de frente tras la salida en rolê.',
          isSimulatedFixture: true,
        ),
        TaughtSessionRecord(
          sessionId: 'ses_20261119_adultos',
          planId: 'legacy_plan_01',
          planTitle: 'Base de Ginga, Bênção y Esquiva',
          groupId: 'clase_adultos_mj_1900',
          groupName: 'Adultos M/J 19:00',
          audienceType: PlannerAudienceType.adultos,
          date: DateTime.now().subtract(const Duration(days: 7)),
          durationMin: 60,
          attendeesCount: 11,
          completedExercisesCount: 3,
          totalExercisesCount: 3,
          completedExercises: const [
            'Movilidad articular + ginga progresiva',
            'Bênção con salida en cocorinha',
            'Roda cadenciada São Bento Grande',
          ],
          groupResponse: 'Buena',
          practicedMovements: const ['Ginga', 'Bênção', 'Cocorinha'],
          summaryNote:
              'Muy buena energía en parejas; los 4 alumnos nuevos consolidaron base de ginga.',
          difficulties: 'Sincronización de cocorinha ante bênção frontal.',
          reinforceContent: 'Distancia segura y guardia alta tras pateo.',
          pendingNextSession:
              'Conectar cocorinha con salida lateral en rolê en ritmo Benguela.',
          isSimulatedFixture: true,
        ),
        TaughtSessionRecord(
          sessionId: 'ses_20261112_kids',
          planId: 'v2_plan_infantil_01',
          planTitle: 'Juegos motores y palmas de terreiro (Kids)',
          groupId: 'clase_kids_mj_1800',
          groupName: 'Kids M/J 18:00',
          audienceType: PlannerAudienceType.infantil,
          date: DateTime.now().subtract(const Duration(days: 14)),
          durationMin: 58,
          attendeesCount: 10,
          completedExercisesCount: 1,
          totalExercisesCount: 2,
          completedExercises: const [
            'Circuito animal: sapo, cangrejo y aú lento',
          ],
          skippedExercises: const [
            'Coro responsorial y ritmo en pandeiro',
          ],
          groupResponse: 'Buena',
          practicedMovements: const ['Ginga', 'Cocorinha', 'Aú'],
          summaryNote: 'Excelente respuesta en el circuito motor por estaciones.',
          difficulties: 'Mantener atención en el cierre rítmico tras el circuito.',
          reinforceContent: 'Palmas de 3 tiempos y coordinación básica en aú.',
          pendingNextSession:
              'Reforzar canto responsorial y entrada ordenada a la roda.',
          isSimulatedFixture: true,
        ),
      ],
    );
  }

  @override
  Future<List<PlannerGroupProfile>> loadGroups() async {
    if (simulateConnectionError) {
      throw StateError('Sin conexión simulada al cargar grupos.');
    }
    return List.unmodifiable(_store.groups);
  }

  @override
  Future<List<ClassPlanModel>> loadPlans() async {
    if (simulateConnectionError) {
      throw StateError('Sin conexión simulada al cargar planes.');
    }
    return List.unmodifiable(_store.plans);
  }

  @override
  Future<ClassPlanModel?> loadPlanById(String planId) async {
    if (simulateConnectionError) {
      throw StateError('Sin conexión simulada al cargar el plan $planId.');
    }
    final idx = _store.plans.indexWhere((p) => p.id == planId);
    return idx >= 0 ? _store.plans[idx] : null;
  }

  @override
  Future<List<PlannerResourceItem>> loadResources() async {
    if (simulateConnectionError) {
      throw StateError('Sin conexión simulada al cargar recursos.');
    }
    return List.unmodifiable(_store.resources);
  }

  @override
  Future<List<TaughtSessionRecord>> loadHistory() async {
    if (simulateConnectionError) {
      throw StateError('Sin conexión simulada al cargar historial.');
    }
    return List.unmodifiable(_store.history);
  }

  void _checkSimulatedWriteError() {
    if (nextWriteError != null) {
      final err = nextWriteError!;
      nextWriteError = null;
      throw err;
    }
    if (simulateConnectionError) {
      throw StateError('Sin conexión simulada: no se pudo sincronizar el cambio.');
    }
  }

  @override
  Future<ClassPlanModel> savePlan(
    ClassPlanModel draft, {
    int? expectedRevision,
    String? deviceId,
  }) async {
    _checkSimulatedWriteError();
    final now = DateTime.now();
    final idx = _store.plans.indexWhere((p) => p.id == draft.id);
    if (idx >= 0) {
      final existing = _store.plans[idx];
      if (expectedRevision != null && existing.revision != expectedRevision) {
        throw PlannerConcurrencyConflictException(
          planId: draft.id,
          expectedRevision: expectedRevision,
          remoteRevision: existing.revision,
          remotePlan: existing,
          message:
              'Otro dispositivo guardó una versión más reciente (${existing.revision} vs $expectedRevision).',
        );
      }
      final nextRev = existing.revision + 1;
      final saved = draft.copyWith(
        revision: nextRev,
        instructorId: instructorUid ?? draft.instructorId,
        updatedByDevice: deviceId ?? defaultDeviceId ?? draft.updatedByDevice,
        updatedAt: now,
        vecesImpartida: draft.vecesImpartida > existing.vecesImpartida
            ? draft.vecesImpartida
            : existing.vecesImpartida,
        ultimaEjecucion: draft.ultimaEjecucion ?? existing.ultimaEjecucion,
      );
      _store.plans[idx] = saved;
      return saved;
    } else {
      final saved = draft.copyWith(
        revision: 1,
        instructorId: instructorUid ?? draft.instructorId,
        updatedByDevice: deviceId ?? defaultDeviceId ?? draft.updatedByDevice,
        createdAt: draft.createdAt ?? now,
        updatedAt: now,
      );
      _store.plans.insert(0, saved);
      return saved;
    }
  }

  @override
  Future<void> saveLocalDraft(ClassPlanModel draft) async {
    await savePlan(draft);
  }

  @override
  Future<ClassPlanModel> updatePlanStatus(
    String planId,
    ClassPlanStatus nextStatus, {
    int? expectedRevision,
    String? deviceId,
  }) async {
    _checkSimulatedWriteError();
    final idx = _store.plans.indexWhere((p) => p.id == planId);
    if (idx < 0) {
      throw StateError('No se encontró el plan $planId.');
    }
    final current = _store.plans[idx];
    if (!current.planStatus.canTransitionTo(nextStatus)) {
      throw StateError(
        'Transición inválida de ${current.planStatus.label} a ${nextStatus.label}.',
      );
    }
    return savePlan(
      current.copyWith(planStatus: nextStatus),
      expectedRevision: expectedRevision ?? current.revision,
      deviceId: deviceId,
    );
  }

  @override
  Future<PlannerResourceItem> saveResource(PlannerResourceItem resource) async {
    _checkSimulatedWriteError();
    final idx =
        _store.resources.indexWhere((r) => r.resourceId == resource.resourceId);
    final updated = resource.copyWith(
      instructorId: instructorUid ?? resource.instructorId,
    );
    if (idx >= 0) {
      _store.resources[idx] = updated;
    } else {
      _store.resources.insert(0, updated);
    }
    return updated;
  }

  Future<void> saveLocalResource(PlannerResourceItem resource) async {
    await saveResource(resource);
  }

  @override
  Future<bool> recordCompletedLiveSession(
    TaughtSessionRecord session, {
    required Set<String> taughtResourceIds,
  }) async {
    _checkSimulatedWriteError();
    if (_store.recordedSessionIds.contains(session.sessionId)) {
      return false;
    }
    _store.recordedSessionIds.add(session.sessionId);
    _store.history.removeWhere((h) => h.sessionId == session.sessionId);
    _store.history.insert(0, session);

    if (taughtResourceIds.isNotEmpty) {
      for (int i = 0; i < _store.resources.length; i++) {
        final res = _store.resources[i];
        if (taughtResourceIds.contains(res.resourceId)) {
          _store.resources[i] = res.copyWith(
            hasBeenTaught: true,
            timesUsed: res.timesUsed + 1,
          );
        }
      }
    }
    // Actualiza solo vecesImpartida, ultimaEjecucion, planStatus y revision del plan original,
    // preservando intactos bloques, ejercicios y snapshot histórico separado.
    final planIdx = _store.plans.indexWhere((p) => p.id == session.planId);
    if (planIdx >= 0) {
      final original = _store.plans[planIdx];
      _store.plans[planIdx] = original.copyWith(
        vecesImpartida: original.vecesImpartida + 1,
        ultimaEjecucion: session.date,
        planStatus: ClassPlanStatus.completed,
        revision: original.revision + 1,
        updatedAt: DateTime.now(),
      );
    }
    return true;
  }
}

/// Fuente de datos real y persistente en Firestore (`PED-05`).
class FirestorePlannerDataSource implements PlannerDataSource {
  final FirebaseFirestore _firestore;
  final String? instructorUid;
  final String? deviceId;

  @override
  bool get isPersistentRemote => true;

  FirestorePlannerDataSource({
    FirebaseFirestore? firestore,
    required this.instructorUid,
    this.deviceId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  String _requireUid() {
    final uid = instructorUid?.trim() ?? '';
    if (uid.isEmpty) {
      throw StateError(
        'Se requiere sesión autenticada del instructor para sincronizar con Firestore.',
      );
    }
    return uid;
  }

  @override
  Future<List<PlannerGroupProfile>> loadGroups() async {
    final clasesSnap = await _firestore.collection('clases').get();
    final alumnosSnap = await _firestore
        .collection('users')
        .where('rol', isEqualTo: 'alumno')
        .get();

    final alumnosPorClase = <String, List<Map<String, dynamic>>>{};
    for (final doc in alumnosSnap.docs) {
      final data = doc.data();
      final claseId = (data['clase_id'] as String? ?? '').trim();
      if (claseId.isNotEmpty) {
        alumnosPorClase.putIfAbsent(claseId, () => []).add(data);
      }
    }

    final now = DateTime.now();
    final profiles = <PlannerGroupProfile>[];
    for (final doc in clasesSnap.docs) {
      final data = doc.data();
      final publicoRaw =
          (data['publico'] ?? data['nombre'] ?? 'Adultos').toString();
      final audience = PlannerAudienceType.fromLegacyLevel(publicoRaw);
      final alumnos = alumnosPorClase[doc.id] ?? const [];

      final cordasCount = <String, int>{};
      int? observedMinAge;
      int? observedMaxAge;
      for (final a in alumnos) {
        final corda = (a['corda'] as String? ?? 'Sin especificar').trim();
        cordasCount[corda] = (cordasCount[corda] ?? 0) + 1;
        final birth = a['fecha_nacimiento'];
        if (birth is Timestamp) {
          final dob = birth.toDate();
          var age = now.year - dob.year;
          if (now.month < dob.month ||
              (now.month == dob.month && now.day < dob.day)) {
            age--;
          }
          if (age >= 2 && age <= 95) {
            observedMinAge =
                observedMinAge == null ? age : (age < observedMinAge ? age : observedMinAge);
            observedMaxAge =
                observedMaxAge == null ? age : (age > observedMaxAge ? age : observedMaxAge);
          }
        }
      }

      final cfgMinAge = (data['edad_min'] as num?)?.toInt();
      final cfgMaxAge = (data['edad_max'] as num?)?.toInt();
      final finalMinAge = observedMinAge ??
          cfgMinAge ??
          (audience == PlannerAudienceType.infantil ? 5 : 16);
      final finalMaxAge = observedMaxAge ??
          cfgMaxAge ??
          (audience == PlannerAudienceType.infantil ? 12 : 45);
      final count = alumnos.isNotEmpty
          ? alumnos.length
          : ((data['cupos_totales'] as num?)?.toInt() ?? 10);

      final dias = (data['dias'] as String? ?? '').trim();
      final hora = (data['hora'] as String? ?? '').trim();
      final schedule = [dias, hora].where((s) => s.isNotEmpty).join(' · ');

      profiles.add(
        PlannerGroupProfile(
          id: doc.id,
          name: (data['nombre'] as String? ?? 'Grupo').trim(),
          source: PlannerGroupSource.realClass,
          audienceType: audience,
          scheduleSummary: schedule.isNotEmpty ? schedule : 'Horario regular',
          ageMin: finalMinAge,
          ageMax: finalMaxAge < finalMinAge ? finalMinAge : finalMaxAge,
          participantsCount: count,
          observedCordasSummary: cordasCount,
          defaultDistribution: ExperienceDistribution(
            principiantes: (count * 0.4).round(),
            intermedios: (count * 0.4).round(),
            avanzados: count - (count * 0.4).round() - (count * 0.4).round(),
            manuallyConfirmed: false,
          ),
        ),
      );
    }
    return profiles;
  }

  @override
  Future<List<ClassPlanModel>> loadPlans() async {
    final uid = instructorUid?.trim() ?? '';
    if (uid.isEmpty) return const [];
    final snap = await _firestore
        .collection('instructor_planes_clase')
        .where('instructor_id', isEqualTo: uid)
        .get();

    final remote = snap.docs
        .map((d) => ClassPlanModel.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(2000))
          .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(2000)));
    return remote;
  }

  @override
  Future<ClassPlanModel?> loadPlanById(String planId) async {
    _requireUid();
    final doc = await _firestore
        .collection('instructor_planes_clase')
        .doc(planId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return ClassPlanModel.fromMap(doc.id, doc.data()!);
  }

  @override
  Future<List<PlannerResourceItem>> loadResources() async {
    final uid = instructorUid?.trim() ?? '';
    if (uid.isEmpty) return const [];
    final byId = <String, Map<String, dynamic>>{};

    final ownSnap = await _firestore
        .collection('instructor_ideas')
        .where('instructor_id', isEqualTo: uid)
        .get();
    for (final d in ownSnap.docs) {
      byId[d.id] = d.data();
    }

    try {
      final sharedSnap = await _firestore
          .collection('instructor_ideas')
          .where('shared', isEqualTo: true)
          .get();
      for (final d in sharedSnap.docs) {
        byId.putIfAbsent(d.id, () => d.data());
      }
    } catch (_) {
      // Tolerante si las reglas o el entorno no habilitan lectura compartida aún.
    }

    final items = byId.entries
        .map((e) => PlannerResourceItem.fromMap(e.key, e.value))
        .toList();
    items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return items;
  }

  @override
  Future<List<TaughtSessionRecord>> loadHistory() async {
    final uid = instructorUid?.trim() ?? '';
    if (uid.isEmpty) return const [];
    final snap = await _firestore
        .collection('instructor_sesiones_impartidas')
        .where('instructor_id', isEqualTo: uid)
        .limit(50)
        .get();
    final remote = snap.docs
        .map((d) => TaughtSessionRecord.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return remote;
  }

  @override
  Future<ClassPlanModel> savePlan(
    ClassPlanModel plan, {
    int? expectedRevision,
    String? deviceId,
  }) async {
    final uid = _requireUid();
    final effDevice = (deviceId ?? this.deviceId ?? plan.updatedByDevice)?.trim();
    final docRef = _firestore.collection('instructor_planes_clase').doc(plan.id);
    final now = DateTime.now();

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      int nextRevision = 1;
      int preservedVeces = plan.vecesImpartida;
      DateTime? preservedUltima = plan.ultimaEjecucion;

      if (snap.exists && snap.data() != null) {
        final remotePlan = ClassPlanModel.fromMap(snap.id, snap.data()!);
        if (expectedRevision != null &&
            remotePlan.revision != expectedRevision) {
          throw PlannerConcurrencyConflictException(
            planId: plan.id,
            expectedRevision: expectedRevision,
            remoteRevision: remotePlan.revision,
            remotePlan: remotePlan,
            message:
                'Otro dispositivo guardó la revisión ${remotePlan.revision} (tenías ${expectedRevision}).',
          );
        }
        nextRevision = remotePlan.revision + 1;
        if (remotePlan.vecesImpartida > preservedVeces) {
          preservedVeces = remotePlan.vecesImpartida;
        }
        if (remotePlan.ultimaEjecucion != null &&
            (preservedUltima == null ||
                remotePlan.ultimaEjecucion!.isAfter(preservedUltima))) {
          preservedUltima = remotePlan.ultimaEjecucion;
        }
      }

      final toPersist = plan.copyWith(
        revision: nextRevision,
        instructorId: uid,
        updatedByDevice: effDevice,
        updatedAt: now,
        createdAt: plan.createdAt ?? now,
        vecesImpartida: preservedVeces,
        ultimaEjecucion: preservedUltima,
      );
      tx.set(
        docRef,
        toPersist.toFirestoreMap(
          instructorUid: uid,
          deviceId: effDevice,
          now: now,
        ),
        SetOptions(merge: true),
      );
      return toPersist;
    });
  }

  @override
  Future<void> saveLocalDraft(ClassPlanModel draft) async {
    await savePlan(draft);
  }

  @override
  Future<ClassPlanModel> updatePlanStatus(
    String planId,
    ClassPlanStatus nextStatus, {
    int? expectedRevision,
    String? deviceId,
  }) async {
    final uid = _requireUid();
    final effDevice = (deviceId ?? this.deviceId)?.trim();
    final docRef = _firestore.collection('instructor_planes_clase').doc(planId);
    final now = DateTime.now();

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('No se encontró el plan $planId.');
      }
      final current = ClassPlanModel.fromMap(snap.id, snap.data()!);
      if (!current.planStatus.canTransitionTo(nextStatus)) {
        throw StateError(
          'Transición inválida de ${current.planStatus.label} a ${nextStatus.label}.',
        );
      }
      if (expectedRevision != null && current.revision != expectedRevision) {
        throw PlannerConcurrencyConflictException(
          planId: planId,
          expectedRevision: expectedRevision,
          remoteRevision: current.revision,
          remotePlan: current,
          message:
              'Otro dispositivo actualizó el estado a revisión ${current.revision}.',
        );
      }
      final next = current.copyWith(
        planStatus: nextStatus,
        revision: current.revision + 1,
        updatedAt: now,
        updatedByDevice: effDevice ?? current.updatedByDevice,
      );
      tx.update(docRef, {
        'instructor_id': current.instructorId ?? uid,
        'plan_status': nextStatus.id,
        'revision': next.revision,
        'updated_at': now.toIso8601String(),
        if (effDevice != null && effDevice.isNotEmpty)
          'updated_by_device': effDevice,
      });
      return next;
    });
  }

  @override
  Future<PlannerResourceItem> saveResource(PlannerResourceItem resource) async {
    final uid = _requireUid();
    final docRef = _firestore.collection('instructor_ideas').doc(resource.resourceId);
    await docRef.set(
      resource.toFirestoreMap(instructorUid: uid),
      SetOptions(merge: true),
    );
    return resource.copyWith(
      instructorId: resource.instructorId?.isNotEmpty == true
          ? resource.instructorId
          : uid,
    );
  }

  @override
  Future<bool> recordCompletedLiveSession(
    TaughtSessionRecord session, {
    required Set<String> taughtResourceIds,
  }) async {
    final uid = _requireUid();
    final sessionRef = _firestore
        .collection('instructor_sesiones_impartidas')
        .doc(session.sessionId);
    final planRef = session.planId.trim().isNotEmpty
        ? _firestore.collection('instructor_planes_clase').doc(session.planId)
        : null;
    final resourceRefs = taughtResourceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .map((id) => _firestore.collection('instructor_ideas').doc(id))
        .toList();

    final nowIso = DateTime.now().toIso8601String();
    return _firestore.runTransaction((tx) async {
      // 1. Todas las lecturas antes de cualquier escritura (requisito de transacciones Firestore).
      final sessionSnap = await tx.get(sessionRef);
      if (sessionSnap.exists) {
        return false;
      }

      final planSnap = planRef != null ? await tx.get(planRef) : null;
      final resSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in resourceRefs) {
        resSnaps.add(await tx.get(ref));
      }

      // 2. Registro inmutable de historial separado del plan editable original.
      final sessionPayload = session.toMap()
        ..['instructor_id'] = uid
        ..['schema_version'] = 2
        ..['immutable'] = true
        ..['recorded_at'] = nowIso;
      tx.set(sessionRef, sessionPayload);

      // 3. Actualizar solo métricas de ejecución y estado del plan (sin alterar bloques/ejercicios).
      if (planRef != null && planSnap != null && planSnap.exists && planSnap.data() != null) {
        final planData = planSnap.data()!;
        final currentVeces = (planData['veces_impartida'] as num?)?.toInt() ?? 0;
        final currentRev = (planData['revision'] as num?)?.toInt() ?? 1;
        tx.update(planRef, {
          'veces_impartida': currentVeces + 1,
          'ultima_ejecucion': session.date.toIso8601String(),
          'plan_status': ClassPlanStatus.completed.id,
          'revision': currentRev + 1,
          'updated_at': nowIso,
        });
      }

      // 4. Contabilizar únicamente recursos efectivamente completados.
      for (final resSnap in resSnaps) {
        if (!resSnap.exists || resSnap.data() == null) continue;
        final resData = resSnap.data()!;
        final currentCount = (resData['veces_impartida'] as num?)?.toInt() ??
            (resData['veces_usada'] as num?)?.toInt() ??
            0;
        tx.update(resSnap.reference, {
          'completado': true,
          'veces_impartida': currentCount + 1,
          'clase_usada': session.groupName,
          'updated_at': nowIso,
        });
      }

      return true;
    });
  }
}
