import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import 'mi_progreso_screen.dart';
import '../biblioteca/practicar_toque_screen.dart';

int _obtenerAsistenciasObjetivo(String corda) {
  switch (corda.toLowerCase()) {
    case 'iniciación':
    case 'iniciacion':
      return 24;
    case 'corda amarela':
      return 48;
    case 'corda naranja':
    case 'corda laranja':
      return 60;
    case 'corda azul':
      return 80;
    default:
      return 100;
  }
}

String _obtenerSiguienteCorda(String corda) {
  switch (corda.toLowerCase()) {
    case 'iniciación':
    case 'iniciacion':
      return 'Corda Amarela';
    case 'corda amarela':
      return 'Corda Laranja';
    case 'corda naranja':
    case 'corda laranja':
      return 'Corda Azul';
    case 'corda azul':
      return 'Corda Verde';
    default:
      return 'Graduado';
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

            // --- CÁLCULO DE ACTIVIDAD SEMANAL EN TIEMPO REAL ---
            final ahora = DateTime.now();
            final lunes = ahora.subtract(Duration(days: ahora.weekday - 1));
            
            final List<String> fechasDeLaSemana = List.generate(7, (i) {
              final dia = DateTime(lunes.year, lunes.month, lunes.day).add(Duration(days: i));
              return '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
            });

            final List<bool> diasActivos = List.generate(7, (i) {
              final fechaStr = fechasDeLaSemana[i];
              if (!asistenciasSnapshot.hasData) return false;
              return asistenciasSnapshot.data!.docs.any((doc) => (doc.data() as Map<String, dynamic>)['fecha'] == fechaStr);
            });
            // ----------------------------------------------------

            final int objetivo = _obtenerAsistenciasObjetivo(corda);
            final double porcentaje = (totalAsistencias / objetivo).clamp(0.0, 1.0);
            final int porcentajeInt = (porcentaje * 100).toInt();

            final String siguienteCorda = _obtenerSiguienteCorda(corda);
            
            // Ritmo dinámico para practicar
            String tituloToque = 'Domina el ritmo Angola';
            String descToque = 'Practica con el simulador de berimbau';
            switch (corda.toLowerCase()) {
              case 'iniciación':
              case 'iniciacion':
                tituloToque = 'Domina el ritmo Angola';
                descToque = 'Practica toques básicos en el simulador';
                break;
              case 'corda amarela':
                tituloToque = 'Domina São Bento Pequeno';
                descToque = 'Practica toques medios en el simulador';
                break;
              case 'corda naranja':
              case 'corda laranja':
                tituloToque = 'Domina São Bento Grande';
                descToque = 'Practica toques rápidos en el simulador';
                break;
              default:
                tituloToque = 'Domina Samba de Roda';
                descToque = 'Practica toques avanzados y festivos';
                break;
            }
            
            // Objetivo de cuerda dinámico
            String tituloCorda = 'Objetivo: $siguienteCorda';
            String descCorda = totalAsistencias >= objetivo
                ? '¡Clases completadas! ($totalAsistencias/$objetivo)'
                : 'Faltan ${objetivo - totalAsistencias} clases para graduarte ($totalAsistencias de $objetivo)';
            if (siguienteCorda == 'Graduado') {
              tituloCorda = 'Camino Completado';
              descCorda = '¡Has alcanzado el rango máximo en Ginga!';
            }

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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                            Text('Progreso de Graduación',
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
                      _SectionHeader(title: 'Tus Logros', actionLabel: ''),
                      const SizedBox(height: 12),
                      _LogrosRow(totalAsistencias: totalAsistencias),

                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Actividad Semanal', actionLabel: ''),
                      const SizedBox(height: 12),
                      _ActividadSemanal(diasActivos: diasActivos, totalAsistencias: totalAsistencias),

                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Próximos Desafíos', actionLabel: ''),
                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PracticarToqueScreen(),
                          ),
                        ),
                        child: _DesafioCard(
                          icon: Icons.music_note_outlined,
                          titulo: tituloToque,
                          subtitulo: descToque,
                          color: GingaColors.brandGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MiProgresoScreen(),
                          ),
                        ),
                        child: _DesafioCard(
                          icon: Icons.emoji_events_outlined,
                          titulo: tituloCorda,
                          subtitulo: descCorda,
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
  final int totalAsistencias;

  const _LogrosRow({required this.totalAsistencias});

  @override
  Widget build(BuildContext context) {
    final logros = [
      _LogroData(
        icon: Icons.check_circle_outline,
        label: 'Primer Paso',
        desc: totalAsistencias >= 1 ? '¡1ª clase tomada!' : 'Toma 1 clase',
        color: GingaColors.brandGreen,
        unlocked: totalAsistencias >= 1,
      ),
      _LogroData(
        icon: Icons.local_fire_department,
        label: 'Constancia',
        desc: totalAsistencias >= 5 ? '5 clases tomadas' : '$totalAsistencias de 5 clases',
        color: GingaColors.accentAmber,
        unlocked: totalAsistencias >= 5,
      ),
      _LogroData(
        icon: Icons.emoji_events_outlined,
        label: 'Camino Medio',
        desc: totalAsistencias >= 12 ? '12 clases tomadas' : '$totalAsistencias de 12 clases',
        color: Colors.blueAccent,
        unlocked: totalAsistencias >= 12,
      ),
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
    final Color badgeColor = logro.unlocked ? logro.color : Colors.grey.shade400;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(
              color: logro.unlocked ? badgeColor.withValues(alpha: 0.3) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Icon(
            logro.unlocked ? logro.icon : Icons.lock_outline, 
            color: badgeColor, 
            size: 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(logro.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: logro.unlocked ? GingaColors.textPrimary : GingaColors.textSecondary,
                height: 1.2)),
        const SizedBox(height: 2),
        Text(logro.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
                fontSize: 9,
                color: GingaColors.textSecondary,
                height: 1.2)),
      ],
    );
  }
}

class _ActividadSemanal extends StatelessWidget {
  final List<bool> diasActivos;
  final int totalAsistencias;

  const _ActividadSemanal({
    required this.diasActivos,
    required this.totalAsistencias,
  });

  @override
  Widget build(BuildContext context) {
    final int asistenciasSemana = diasActivos.where((a) => a).length;
    final List<String> dias = [
      'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'
    ];

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
              children: List.generate(diasActivos.length, (i) {
                final bool activo = diasActivos[i];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 28,
                  height: activo ? 70.0 : 12.0,
                  decoration: BoxDecoration(
                    color: activo
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
            children: dias
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
                Text('CLASES ESTA SEMANA',
                    style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textSecondary,
                        letterSpacing: 0.5)),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$asistenciasSemana ${asistenciasSemana == 1 ? 'clase' : 'clases'}',
                          style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: asistenciasSemana > 0 ? GingaColors.brandGreen : Colors.grey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(asistenciasSemana > 0 ? '¡Activo! 🔥' : 'Inactivo',
                            style: GoogleFonts.nunito(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
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
  final String desc;
  final Color color;
  final bool unlocked;
  _LogroData({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
    required this.unlocked,
  });
}