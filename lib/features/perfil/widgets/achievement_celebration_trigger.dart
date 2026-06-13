import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'achievement_celebration_modal.dart';
import '../../../core/theme/ginga_theme.dart';

class AchievementCelebrationTrigger extends StatefulWidget {
  final String uid;
  const AchievementCelebrationTrigger({super.key, required this.uid});

  @override
  State<AchievementCelebrationTrigger> createState() => _AchievementCelebrationTriggerState();
}

class _AchievementCelebrationTriggerState extends State<AchievementCelebrationTrigger> {
  bool _dialogShowing = false;

  // Lista de logros ordenados de menor a mayor requerimiento
  static final List<_AchievementDefinition> _achievements = [
    _AchievementDefinition(
      id: 'primer_paso',
      title: 'Primer Paso 👣',
      description: '¡Has completado tu primera clase de Capoeira Ginga! El inicio de un gran viaje.',
      icon: Icons.check_circle_outline,
      color: GingaColors.brandGreen,
      badgeLabel: '1 Clase',
      threshold: 1,
    ),
    _AchievementDefinition(
      id: 'constancia',
      title: 'Constancia 🔥',
      description: '¡5 clases tomadas! Tu dedicación empieza a dar frutos. ¡Sigue con ese ritmo!',
      icon: Icons.local_fire_department,
      color: GingaColors.accentAmber,
      badgeLabel: '5 Clases',
      threshold: 5,
    ),
    _AchievementDefinition(
      id: 'camino_medio',
      title: 'Camino Medio 🌟',
      description: '¡12 clases tomadas! Te estás convirtiendo en un capoeirista disciplinado. ¡Axé!',
      icon: Icons.emoji_events_outlined,
      color: Colors.blueAccent,
      badgeLabel: '12 Clases',
      threshold: 12,
    ),
    _AchievementDefinition(
      id: 'ritmo_y_cadencia',
      title: 'Ritmo y Cadencia 🎵',
      description: '¡25 clases tomadas! Sientes el ritmo y la cadencia de la capoeira en tu cuerpo.',
      icon: Icons.music_note_outlined,
      color: Colors.purpleAccent,
      badgeLabel: '25 Clases',
      threshold: 25,
    ),
    _AchievementDefinition(
      id: 'guerrero_ginga',
      title: 'Guerrero Ginga 🛡️',
      description: '¡50 clases tomadas! Eres un verdadero guerrero/a constante en la roda de Ginga.',
      icon: Icons.shield_outlined,
      color: Colors.redAccent,
      badgeLabel: '50 Clases',
      threshold: 50,
    ),
    _AchievementDefinition(
      id: 'mestre_de_la_arena',
      title: 'Mestre de la Arena 👑',
      description: '¡100 clases tomadas! Tu constancia, disciplina y respeto por el arte son legendarios.',
      icon: Icons.workspace_premium_outlined,
      color: const Color(0xFFFFD700), // Oro
      badgeLabel: '100 Clases',
      threshold: 100,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const SizedBox();
        }

        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        final List<String> logrosCelebrados = List<String>.from(userData['logros_celebrados'] ?? []);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('asistencias')
              .where('user_id', isEqualTo: widget.uid)
              .snapshots(),
          builder: (context, asistenciasSnap) {
            if (!asistenciasSnap.hasData) {
              return const SizedBox();
            }

            final int totalAsistencias = asistenciasSnap.data!.docs.length;

            // Encontrar todos los logros calificados (unlocked)
            final List<_AchievementDefinition> qualified = _achievements
                .where((a) => totalAsistencias >= a.threshold)
                .toList();

            if (qualified.isEmpty) {
              return const SizedBox();
            }

            // Identificar cuáles de los logros calificados aún no han sido celebrados
            final List<_AchievementDefinition> notCelebrated = qualified
                .where((a) => !logrosCelebrados.contains(a.id))
                .toList();

            if (notCelebrated.isNotEmpty && !_dialogShowing) {
              // El logro máximo no celebrado es el último de la lista no celebrada (ya que están ordenados por threshold)
              final targetLogro = notCelebrated.last;

              // Todos los logros calificados hasta el targetLogro deben marcarse como celebrados en Firestore
              final List<String> toMarkAsCelebrated = qualified
                  .where((a) => a.threshold <= targetLogro.threshold)
                  .map((a) => a.id)
                  .toList();

              _dialogShowing = true;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _celebrateLogro(targetLogro, toMarkAsCelebrated);
              });
            }

            return const SizedBox();
          },
        );
      },
    );
  }

  void _celebrateLogro(_AchievementDefinition logro, List<String> idsToCelebrate) async {
    if (!mounted) return;

    // Mostrar el modal animado
    await showDialog(
      context: context,
      barrierColor: Colors.transparent, // Lo maneja el propio modal
      barrierDismissible: false,
      builder: (context) {
        return AchievementCelebrationModal(
          title: logro.title,
          description: logro.description,
          icon: logro.icon,
          color: logro.color,
          badgeLabel: logro.badgeLabel,
        );
      },
    );

    // Actualizar Firestore marcando los logros como celebrados
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'logros_celebrados': FieldValue.arrayUnion(idsToCelebrate),
      });
      debugPrint('GINGA_DEBUG: Logros celebrados guardados: $idsToCelebrate');
    } catch (e) {
      debugPrint('Error guardando logros en Firestore: $e');
    } finally {
      if (mounted) {
        setState(() {
          _dialogShowing = false;
        });
      }
    }
  }
}

class _AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String badgeLabel;
  final int threshold;

  _AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.badgeLabel,
    required this.threshold,
  });
}
