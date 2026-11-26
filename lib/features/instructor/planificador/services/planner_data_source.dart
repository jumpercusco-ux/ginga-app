import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_plan_models.dart';

/// Fuente de datos desacoplada para el Planificador V2 (fixtures locales aislados o Firestore).
abstract class PlannerDataSource {
  Future<List<PlannerGroupProfile>> loadGroups();
  Future<List<ClassPlanModel>> loadPlans();
  Future<List<PlannerResourceItem>> loadResources();
  Future<List<TaughtSessionRecord>> loadHistory();
  Future<void> saveLocalDraft(ClassPlanModel draft);
}

/// Implementación local aislada con fixtures realistas libres de PII para pruebas y vista previa.
class InMemoryPlannerDataSource implements PlannerDataSource {
  final List<PlannerGroupProfile> _groups;
  final List<ClassPlanModel> _plans;
  final List<PlannerResourceItem> _resources;
  final List<TaughtSessionRecord> _history;

  InMemoryPlannerDataSource({
    required List<PlannerGroupProfile> groups,
    required List<ClassPlanModel> plans,
    required List<PlannerResourceItem> resources,
    required List<TaughtSessionRecord> history,
  })  : _groups = List.of(groups),
        _plans = List.of(plans),
        _resources = List.of(resources),
        _history = List.of(history);

  factory InMemoryPlannerDataSource.demoFixtures() {
    return InMemoryPlannerDataSource(
      groups: const [
        PlannerGroupProfile(
          id: 'clase_adultos_mj_1900',
          name: 'Adultos M/J 19:00',
          source: PlannerGroupSource.realClass,
          audienceType: PlannerAudienceType.adultos,
          scheduleSummary: 'Martes y Jueves · 19:00',
          ageMin: 16,
          ageMax: 38,
          participantsCount: 12,
          observedCordasSummary: {
            'Crua': 4,
            'Crua e Verde': 3,
            'Verde': 3,
            'Verde e Laranja': 2,
          },
          defaultDistribution: ExperienceDistribution(
            principiantes: 5,
            intermedios: 5,
            avanzados: 2,
            manuallyConfirmed: false,
          ),
          suggestedTargetAdultoCordaIndex: 3,
        ),
        PlannerGroupProfile(
          id: 'clase_kids_mj_1800',
          name: 'Kids M/J 18:00',
          source: PlannerGroupSource.realClass,
          audienceType: PlannerAudienceType.infantil,
          scheduleSummary: 'Martes y Jueves · 18:00',
          ageMin: 6,
          ageMax: 11,
          participantsCount: 10,
          observedCordasSummary: {'Cru e Verde (ref)': 6, 'Cru e Azul (ref)': 4},
          defaultDistribution: ExperienceDistribution(
            principiantes: 6,
            intermedios: 4,
            avanzados: 0,
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
          practicedMovements: const ['Ginga', 'Cocorinha', 'Rolê'],
          summaryNote:
              'Fluidez alta en parejas; las rotaciones de 60s evitaron tiempos muertos.',
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
          practicedMovements: const ['Ginga', 'Bênção', 'Cocorinha'],
          summaryNote:
              'Muy buena energía en parejas; los 4 alumnos nuevos consolidaron base de ginga.',
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
          completedExercisesCount: 4,
          totalExercisesCount: 5,
          practicedMovements: const ['Ginga', 'Cocorinha', 'Aú'],
          summaryNote: 'Excelente respuesta en el circuito motor por estaciones.',
          pendingNextSession:
              'Reforzar canto responsorial y entrada ordenada a la roda.',
          isSimulatedFixture: true,
        ),
      ],
    );
  }

  @override
  Future<List<PlannerGroupProfile>> loadGroups() async => List.unmodifiable(_groups);

  @override
  Future<List<ClassPlanModel>> loadPlans() async => List.unmodifiable(_plans);

  @override
  Future<List<PlannerResourceItem>> loadResources() async =>
      List.unmodifiable(_resources);

  @override
  Future<List<TaughtSessionRecord>> loadHistory() async =>
      List.unmodifiable(_history);

  @override
  Future<void> saveLocalDraft(ClassPlanModel draft) async {
    final idx = _plans.indexWhere((p) => p.id == draft.id);
    if (idx >= 0) {
      _plans[idx] = draft;
    } else {
      _plans.insert(0, draft);
    }
  }

  Future<void> saveLocalResource(PlannerResourceItem resource) async {
    final idx = _resources.indexWhere((r) => r.resourceId == resource.resourceId);
    if (idx >= 0) {
      _resources[idx] = resource;
    } else {
      _resources.insert(0, resource);
    }
  }
}

/// Fuente de datos real en Firestore (solo lectura en PED-04B1 + saneamiento Zero-PII).
class FirestorePlannerDataSource implements PlannerDataSource {
  final FirebaseFirestore _firestore;
  final String? instructorUid;
  final List<ClassPlanModel> _sessionDrafts = [];

  FirestorePlannerDataSource({
    FirebaseFirestore? firestore,
    required this.instructorUid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

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
    if (instructorUid == null) return List.unmodifiable(_sessionDrafts);
    final snap = await _firestore
        .collection('instructor_planes_clase')
        .where('instructor_id', isEqualTo: instructorUid)
        .get();

    final remote = snap.docs
        .map((d) => ClassPlanModel.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));

    final localIds = _sessionDrafts.map((d) => d.id).toSet();
    final filteredRemote = remote.where((r) => !localIds.contains(r.id));
    return [..._sessionDrafts, ...filteredRemote];
  }

  @override
  Future<List<PlannerResourceItem>> loadResources() async {
    final snap = await _firestore
        .collection('instructor_ideas')
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs
        .map((d) => PlannerResourceItem.fromMap(d.id, d.data()))
        .toList();
  }

  @override
  Future<List<TaughtSessionRecord>> loadHistory() async {
    if (instructorUid == null) return const [];
    try {
      final snap = await _firestore
          .collection('instructor_sesiones_impartidas')
          .where('instructor_id', isEqualTo: instructorUid)
          .limit(30)
          .get();
      final list = snap.docs
          .map((d) => TaughtSessionRecord.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (_) {
      // Tolerante si la colección aún no existe en este entorno
      return const [];
    }
  }

  @override
  Future<void> saveLocalDraft(ClassPlanModel draft) async {
    // PED-04B1 mantiene los borradores nuevos localmente sin escribir en producción.
    _sessionDrafts.removeWhere((p) => p.id == draft.id);
    _sessionDrafts.insert(0, draft);
  }
}
