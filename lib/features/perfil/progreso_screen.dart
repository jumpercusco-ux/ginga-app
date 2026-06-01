import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/ginga_theme.dart';
import 'mi_progreso_screen.dart';
import '../biblioteca/practicar_toque_screen.dart';
import 'package:url_launcher/url_launcher.dart';

int _obtenerAsistenciasObjetivo(String corda) {
  switch (corda.toLowerCase()) {
    case 'iniciación':
    case 'iniciacion':
    case 'iniciante':
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
    case 'iniciante':
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
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        // Datos por defecto mientras carga
        String nombre = 'Alumno';
        String corda = 'Crua';
        String sede = 'Lima';
        String inicial = 'A';
        String? fotoUrl;
        String userStatus = 'nuevo';
        Timestamp? membresiaInicio;
        Timestamp? membresiaFin;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          nombre = data['nombre'] ?? 'Alumno';
          corda = data['corda'] ?? 'Crua';
          sede = data['sede'] ?? 'Lima';
          inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';
          fotoUrl = data['foto_url'];
          userStatus = data['status'] ?? 'nuevo';
          membresiaInicio = data['membresia_inicio'] as Timestamp?;
          membresiaFin = data['membresia_fin'] as Timestamp?;
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

            final Set<String> asistenciasFechas = asistenciasSnapshot.hasData
                ? asistenciasSnapshot.data!.docs
                    .map((doc) => (doc.data() as Map<String, dynamic>)['fecha'] as String)
                    .toSet()
                : {};



            final int objetivo = _obtenerAsistenciasObjetivo(corda);
            final double porcentaje =
                (totalAsistencias / objetivo).clamp(0.0, 1.0);
            final int porcentajeInt = (porcentaje * 100).toInt();

            final String siguienteCorda = _obtenerSiguienteCorda(corda);

            // Ritmo dinámico para practicar
            String tituloToque = 'Domina el ritmo Angola';
            String descToque = 'Practica con el simulador de berimbau';
            switch (corda.toLowerCase()) {
              case 'iniciación':
              case 'iniciacion':
              case 'iniciante':
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
                              backgroundImage: fotoUrl != null && fotoUrl!.isNotEmpty
                                  ? NetworkImage(fotoUrl!)
                                  : null,
                              child: fotoUrl != null && fotoUrl!.isNotEmpty
                                  ? null
                                  : Text(
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

                      if (uid != null) ...[
                        const SizedBox(height: 28),
                        _SectionHeader(
                            title: 'Mi Membresía y Pagos', actionLabel: ''),
                        const SizedBox(height: 12),
                        _MembresiaYPagosSection(
                          uid: uid,
                          userStatus: userStatus,
                          membresiaInicio: membresiaInicio,
                          membresiaFin: membresiaFin,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Círculo de progreso ──────────────
                      Center(
                        child: _ProgressCircle(
                          inicial: inicial,
                          porcentaje: porcentaje,
                          porcentajeInt: porcentajeInt,
                          fotoUrl: fotoUrl,
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
                      _SectionHeader(
                          title: 'Asistencia del Mes', actionLabel: ''),
                      const SizedBox(height: 12),
                      _AsistenciaMensual(asistenciasFechas: asistenciasFechas),

                      const SizedBox(height: 28),
                      _SectionHeader(
                          title: 'Próximos Desafíos', actionLabel: ''),
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
  final String? fotoUrl;

  const _ProgressCircle({
    required this.inicial,
    required this.porcentaje,
    required this.porcentajeInt,
    required this.fotoUrl,
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
                backgroundImage: fotoUrl != null && fotoUrl!.isNotEmpty
                    ? NetworkImage(fotoUrl!)
                    : null,
                child: fotoUrl != null && fotoUrl!.isNotEmpty
                    ? null
                    : Text(inicial,
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
    canvas.drawCircle(
        center,
        radius,
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
  bool shouldRepaint(covariant _CirclePainter oldDelegate) =>
      oldDelegate.progress != progress;
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
              valueColor: const AlwaysStoppedAnimation(GingaColors.brandGreen),
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
        desc: totalAsistencias >= 5
            ? '5 clases tomadas'
            : '$totalAsistencias de 5 clases',
        color: GingaColors.accentAmber,
        unlocked: totalAsistencias >= 5,
      ),
      _LogroData(
        icon: Icons.emoji_events_outlined,
        label: 'Camino Medio',
        desc: totalAsistencias >= 12
            ? '12 clases tomadas'
            : '$totalAsistencias de 12 clases',
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
    final Color badgeColor =
        logro.unlocked ? logro.color : Colors.grey.shade400;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(
              color: logro.unlocked
                  ? badgeColor.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
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
                color: logro.unlocked
                    ? GingaColors.textPrimary
                    : GingaColors.textSecondary,
                height: 1.2)),
        const SizedBox(height: 2),
        Text(logro.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
                fontSize: 9, color: GingaColors.textSecondary, height: 1.2)),
      ],
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

class _AsistenciaMensual extends StatefulWidget {
  final Set<String> asistenciasFechas;
  const _AsistenciaMensual({required this.asistenciasFechas});

  @override
  State<_AsistenciaMensual> createState() => _AsistenciaMensualState();
}

class _AsistenciaMensualState extends State<_AsistenciaMensual> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mes',
        },
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: GingaColors.textPrimary,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, color: GingaColors.brandGreen),
          rightChevronIcon: const Icon(Icons.chevron_right, color: GingaColors.brandGreen),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: GingaColors.textSecondary),
          weekendStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: GingaColors.brandGreen),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textPrimary),
          weekendTextStyle: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textPrimary),
          outsideDaysVisible: false,
        ),
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final fechaStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final bool asistio = widget.asistenciasFechas.contains(fechaStr);
            if (asistio) {
              return Container(
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: GingaColors.brandGreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              );
            }
            return null;
          },
          todayBuilder: (context, day, focusedDay) {
            final fechaStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final bool asistio = widget.asistenciasFechas.contains(fechaStr);
            return Container(
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: asistio ? GingaColors.brandGreen : Colors.transparent,
                border: Border.all(color: GingaColors.brandGreen, width: 2),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: asistio ? Colors.white : GingaColors.brandGreen,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SECCIÓN DE MEMBRESÍA Y HISTORIAL DE PAGOS (ALUMNO)
// ─────────────────────────────────────────

class _MembresiaYPagosSection extends StatelessWidget {
  final String uid;
  final String userStatus;
  final Timestamp? membresiaInicio;
  final Timestamp? membresiaFin;

  const _MembresiaYPagosSection({
    required this.uid,
    required this.userStatus,
    required this.membresiaInicio,
    required this.membresiaFin,
  });

  String _formatFecha(DateTime? date) {
    if (date == null) return '-';
    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 
      'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${meses[date.month - 1]}, ${date.year}';
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const String message = 
        '🥋 *¡Hola Instructor! Deseo coordinar la renovación de mi membresía en Capoeira Ginga.*\n\n'
        '¿Me podría confirmar los datos o el monto de la cuota mensual para realizar el pago por Yape/Plin? ¡Muchas gracias! 👋';
    const String telefonoGinga = '51954642457';
    final String url = 'https://wa.me/$telefonoGinga?text=${Uri.encodeComponent(message)}';
    
    try {
      final Uri uri = Uri.parse(url);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('WhatsApp lanzado con éxito');
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp. Por favor, comunícate con tu instructor directamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int diasRestantes = 0;
    bool expirado = false;

    if (membresiaFin != null) {
      final finDate = membresiaFin!.toDate();
      final ahora = DateTime.now();
      // Calcular la diferencia a la medianoche para evitar desajustes de horas
      final finDia = DateTime(finDate.year, finDate.month, finDate.day);
      final ahoraDia = DateTime(ahora.year, ahora.month, ahora.day);
      final diferencia = finDia.difference(ahoraDia).inDays;
      if (diferencia >= 0) {
        diasRestantes = diferencia;
      } else {
        expirado = true;
      }
    }

    final String statusLimpio = userStatus.toLowerCase();
    final bool esActivo = statusLimpio == 'activo' && !expirado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Tarjeta Premium de Estado de Membresía
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: esActivo
                ? const LinearGradient(
                    colors: [Color(0xFF1B5E20), GingaColors.brandGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : (statusLimpio == 'prueba' || statusLimpio == 'nuevo'
                    ? const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (esActivo 
                    ? GingaColors.brandGreen 
                    : (statusLimpio == 'prueba' || statusLimpio == 'nuevo' 
                        ? Colors.blue 
                        : Colors.red)).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    esActivo
                        ? 'Acceso Regular Activo 🥋'
                        : (statusLimpio == 'prueba' || statusLimpio == 'nuevo'
                            ? 'Periodo de Prueba ⚡'
                            : 'Membresía Vencida ⚠️'),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      esActivo
                          ? 'ACTIVO'
                          : (statusLimpio == 'prueba' || statusLimpio == 'nuevo'
                              ? 'LIBRE'
                              : 'VENCIDO'),
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (esActivo && membresiaFin != null) ...[
                Text(
                  'Vence el: ${_formatFecha(membresiaFin!.toDate())}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  diasRestantes == 0
                      ? '¡Tu membresía vence hoy!'
                      : '¡Te quedan $diasRestantes días activos de entrenamiento!',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ] else if (statusLimpio == 'prueba' || statusLimpio == 'nuevo') ...[
                Text(
                  '¡Bienvenido a Capoeira Ginga!',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Disfruta de tus clases de cortesía y coordina tu membresía regular con tu profesor.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _launchWhatsApp(context),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Text(
                      'Coordinar Membresía Regular',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  membresiaFin != null
                      ? 'Tu membresía expiró el: ${_formatFecha(membresiaFin!.toDate())}'
                      : 'Aún no tienes una membresía regular activa.',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coordinar renovación y pago de cuota para restablecer tu acceso.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _launchWhatsApp(context),
                    icon: const Icon(Icons.chat, size: 16),
                    label: Text(
                      'Coordinar Renovación por WhatsApp',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 2. Historial de Pagos Recientes
        Text(
          'Historial de Pagos Recientes',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: GingaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pagos')
              .where('user_id', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Error al obtener historial de pagos: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: GingaColors.brandGreen),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GingaColors.borderLight.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 40, color: GingaColors.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      'Aún no hay transacciones validadas en tu historial.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: GingaColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Ordenar en memoria por fecha_pago de forma descendente para evitar requerir un índice compuesto en Firestore
            final pagos = snapshot.data!.docs.toList();
            pagos.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final Timestamp? aFecha = aData['fecha_pago'] as Timestamp?;
              final Timestamp? bFecha = bData['fecha_pago'] as Timestamp?;
              if (aFecha == null && bFecha == null) return 0;
              if (aFecha == null) return 1;
              if (bFecha == null) return -1;
              return bFecha.compareTo(aFecha); // Orden descendente
            });
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pagos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pago = pagos[index].data() as Map<String, dynamic>;
                final monto = pago['monto'] ?? 0.0;
                final metodo = pago['metodo_pago'] ?? 'Yape';
                final meses = pago['meses_pagados'] ?? 1;
                final Timestamp? fechaPago = pago['fecha_pago'] as Timestamp?;
                final fechaStr = _formatFecha(fechaPago?.toDate());

                // Icono y color según el método de pago
                IconData metodoIcon = Icons.payment;
                Color metodoColor = Colors.grey;
                switch (metodo.toString().toLowerCase()) {
                  case 'yape':
                    metodoIcon = Icons.phone_android;
                    metodoColor = const Color(0xFF7A1FA2);
                    break;
                  case 'plin':
                    metodoIcon = Icons.qr_code_2;
                    metodoColor = const Color(0xFF00B0FF);
                    break;
                  case 'efectivo':
                    metodoIcon = Icons.payments;
                    metodoColor = const Color(0xFF388E3C);
                    break;
                  case 'transferencia':
                    metodoIcon = Icons.account_balance;
                    metodoColor = const Color(0xFF1976D2);
                    break;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GingaColors.borderLight.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: metodoColor.withOpacity(0.1),
                        child: Icon(metodoIcon, color: metodoColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'S/ ${monto.toStringAsFixed(2)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$meses ${meses == 1 ? "mes" : "meses"} de acceso • $metodo',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: GingaColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fechaStr,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: GingaColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 10, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'Validado',
                                  style: GoogleFonts.nunito(
                                    fontSize: 9,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
