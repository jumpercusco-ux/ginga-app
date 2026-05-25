import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import 'mi_progreso_screen.dart';

int _obtenerAsistenciasObjetivo(String corda) {
  switch (corda.toLowerCase()) {
    case 'iniciación':
    case 'iniciacion':
      return 24;
    case 'corda amarela':
      return 48;
    case 'corda laranja':
      return 60;
    case 'corda azul':
      return 80;
    default:
      return 100;
  }
}

class ProgresoScreen extends StatelessWidget {
  const ProgresoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Datos por defecto mientras carga
        String nombre = 'Alumno';
        String corda = 'Iniciación';
        String sede = 'Lima';
        String inicial = 'A';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          nombre = data['nombre'] ?? 'Alumno';
          corda = data['corda'] ?? 'Iniciación';
          sede = data['sede'] ?? 'Lima';
          inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('asistencias')
              .where('user_id', isEqualTo: uid)
              .snapshots(),
          builder: (context, asistenciasSnapshot) {
            int totalAsistencias = 0;
            if (asistenciasSnapshot.hasData) {
              totalAsistencias = asistenciasSnapshot.data!.docs.length;
            }

            final int objetivo = _obtenerAsistenciasObjetivo(corda);
            final double porcentaje = (totalAsistencias / objetivo).clamp(0.0, 1.0);
            final int porcentajeInt = (porcentaje * 100).toInt();

            return Scaffold(
              backgroundColor: GingaColors.backgroundLight,
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // ── Header ──────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progreso y Logros',
                              style: GoogleFonts.montserrat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: GingaColors.textPrimary)),
                          IconButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) context.go('/splash');
                            },
                            icon: const Icon(Icons.logout,
                                color: GingaColors.textSecondary, size: 22),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Card de perfil real ──────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: GingaColors.cardLight,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(
                              color: GingaColors.brandGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            // Avatar con inicial
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: GingaColors.brandGreen,
                              child: Text(
                                inicial,
                                style: GoogleFonts.montserrat(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: GingaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: GingaColors.brandGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        corda,
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          color: GingaColors.brandGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          size: 13,
                                          color: GingaColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        sede,
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: GingaColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Círculo de progreso ──────────────
                      Center(
                        child: _ProgressCircle(
                          inicial: inicial,
                          porcentaje: porcentaje,
                          porcentajeInt: porcentajeInt,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Text('Nivel de Musicalidad',
                                style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.textPrimary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: GingaColors.cardLight,
                                borderRadius:
                                    BorderRadius.circular(GingaRadius.full),
                              ),
                              child: Text('Grado: $corda',
                                  style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      color: GingaColors.brandGreen,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 12),
                            _XpBar(
                              total: totalAsistencias,
                              objetivo: objetivo,
                              porcentaje: porcentaje,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Tus Logros', actionLabel: 'Ver todas'),
                      const SizedBox(height: 12),
                      _LogrosRow(),

                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Actividad Semanal', actionLabel: ''),
                      const SizedBox(height: 12),
                      _ActividadSemanal(),

                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Próximos Desafíos', actionLabel: ''),
                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const MiProgresoScreen())),
                        child: _DesafioCard(
                          icon: Icons.music_note_outlined,
                          titulo: 'Domina el toque Iuna',
                          subtitulo: 'Practica en 2 rodas más',
                          color: GingaColors.brandGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const MiProgresoScreen())),
                        child: _DesafioCard(
                          icon: Icons.groups_outlined,
                          titulo: 'Asistencia Roda de Sábado',
                          subtitulo: 'Participa en 2 rodas más',
                          color: GingaColors.accentAmber,
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  CÍRCULO DE PROGRESO
// ─────────────────────────────────────────

class _ProgressCircle extends StatelessWidget {
  final String inicial;
  final double porcentaje;
  final int porcentajeInt;
  const _ProgressCircle({
    required this.inicial,
    required this.porcentaje,
    required this.porcentajeInt,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _CirclePainter(progress: porcentaje),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: GingaColors.cardLight,
                child: Text(inicial,
                    style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.brandGreen)),
              ),
              const SizedBox(height: 4),
              Text('$porcentajeInt%',
                  style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final double progress;
  const _CirclePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    canvas.drawCircle(center, radius,
        Paint()
          ..color = GingaColors.borderLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = GingaColors.brandGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CirclePainter oldDelegate) => oldDelegate.progress != progress;
}

class _XpBar extends StatelessWidget {
  final int total;
  final int objetivo;
  final double porcentaje;

  const _XpBar({
    required this.total,
    required this.objetivo,
    required this.porcentaje,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$total / $objetivo clases',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: GingaColors.textSecondary)),
              Text('para el siguiente corda',
                  style: GoogleFonts.nunito(
                      fontSize: 11, color: GingaColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(GingaRadius.full),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 8,
              backgroundColor: GingaColors.borderLight,
              valueColor:
                  const AlwaysStoppedAnimation(GingaColors.brandGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogrosRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logros = [
      _LogroData(
          icon: Icons.music_note,
          label: 'Primer Toque',
          color: GingaColors.brandGreen),
      _LogroData(
          icon: Icons.local_fire_department,
          label: '2 días seguidos',
          color: GingaColors.accentAmber),
      _LogroData(
          icon: Icons.person,
          label: 'Maestro\nAngola',
          color: GingaColors.textSecondary),
    ];
    return Row(
      children:
          logros.map((l) => Expanded(child: _LogroBadge(logro: l))).toList(),
    );
  }
}

class _LogroBadge extends StatelessWidget {
  final _LogroData logro;
  const _LogroBadge({required this.logro});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: logro.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(GingaRadius.md),
          ),
          child: Icon(logro.icon, color: logro.color, size: 26),
        ),
        const SizedBox(height: 6),
        Text(logro.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
                fontSize: 11,
                color: GingaColors.textSecondary,
                height: 1.3)),
      ],
    );
  }
}

class _ActividadSemanal extends StatelessWidget {
  final List<double> _valores = [0.3, 0.5, 0.8, 0.4, 1.0, 0.6, 0.2];
  final List<String> _dias = [
    'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_valores.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 28,
                  height: _valores[i] * 70,
                  decoration: BoxDecoration(
                    color: _valores[i] == 1.0
                        ? GingaColors.brandGreen
                        : GingaColors.cardLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _dias
                .map((d) => Text(d,
                    style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: GingaColors.textSecondary,
                        fontWeight: FontWeight.w600)))
                .toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: GingaColors.cardLight,
              borderRadius: BorderRadius.circular(GingaRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL DE PRÁCTICA',
                    style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: GingaColors.textSecondary,
                        letterSpacing: 0.5)),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('245 min',
                          style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GingaColors.brandGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('+12%',
                            style: GoogleFonts.nunito(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesafioCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final Color color;

  const _DesafioCard({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(GingaRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary)),
                Text(subtitulo,
                    style: GoogleFonts.nunito(
                        fontSize: 12, color: GingaColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: GingaColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  const _SectionHeader({required this.title, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: GingaColors.textPrimary)),
        if (actionLabel.isNotEmpty)
          Text(actionLabel,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: GingaColors.brandGreen,
                  fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LogroData {
  final IconData icon;
  final String label;
  final Color color;
  _LogroData({required this.icon, required this.label, required this.color});
}