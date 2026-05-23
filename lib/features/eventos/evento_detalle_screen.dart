import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class EventoDetalleScreen extends StatelessWidget {
  const EventoDetalleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: Stack(
        children: [
          // ── Contenido scrolleable ──────────────
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Imagen hero ─────────────────
                _HeroImage(context: context),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag Workshop
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: GingaColors.accentAmber,
                          borderRadius:
                              BorderRadius.circular(GingaRadius.sm),
                        ),
                        child: Text(
                          'WORKSHOP ESPECIAL',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF412402),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Título
                      Text(
                        'Workshop de Capoeira Regional con Mestre Lucas',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info cards
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Sábado, 15 de Junio',
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.access_time_outlined,
                        label: '10:00 - 13:00',
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Parque de la Roda, Cusco',
                      ),

                      const SizedBox(height: 24),
                      _Divider(),

                      // Sobre el evento
                      const SizedBox(height: 20),
                      Text(
                        'Sobre el evento',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Únete a nosotros para una sesión intensiva sobre los fundamentos de la Capoeira Regional. Exploraremos las secuencias de Mestre Bimba, técnica de golpeo y la musicalidad esencial que define nuestro arte.\n\nApto para todos los niveles que deseen profundizar en su técnica.',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: GingaColors.textSecondary,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 24),
                      _Divider(),

                      // Sobre el Mestre
                      const SizedBox(height: 20),
                      Text(
                        'Sobre el Mestre',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MestreCard(),

                      const SizedBox(height: 24),
                      _Divider(),

                      // Cómo llegar
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cómo llegar',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: Text(
                              'Abrir en Maps',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: GingaColors.brandGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MapPlaceholder(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Botón flotante inscripción ──────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: GingaColors.backgroundLight,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
              // Botón Inscribirse Ahora — onPressed:
onPressed: () {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: GingaColors.brandGreen, size: 48),
          const SizedBox(height: 12),
          Text('¡Inscripción exitosa!',
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Tu ticket aparecerá en tu Pasaporte de Eventos.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textSecondary)),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GingaColors.brandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Inscribirse Ahora',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HERO IMAGE
// ─────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  final BuildContext context;
  const _HeroImage({required this.context});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 260,
          width: double.infinity,
          color: GingaColors.backgroundDark,
          child: const Center(
            child: Icon(
              Icons.sports_martial_arts,
              color: GingaColors.brandGreen,
              size: 80,
            ),
          ),
        ),
        // Back button
        Positioned(
          top: 48,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(GingaRadius.full),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  INFO ROW
// ─────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: GingaColors.cardLight,
            borderRadius: BorderRadius.circular(GingaRadius.sm),
          ),
          child: Icon(icon, size: 16, color: GingaColors.brandGreen),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: GingaColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  MESTRE CARD
// ─────────────────────────────────────────

class _MestreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GingaColors.cardLight,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: GingaColors.brandGreen,
            child: Text(
              'ML',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mestre Lucas',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Con más de 25 años de experiencia, Mestre Lucas es reconocido mundialmente por su preservación de las tradiciones de la Capoeira Regional.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: GingaColors.textSecondary,
                    height: 1.5,
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

// ─────────────────────────────────────────
//  MAP PLACEHOLDER
// ─────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: GingaColors.cardLight,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Grid lines simulando mapa
          CustomPaint(
            size: const Size(double.infinity, 140),
            painter: _MapGridPainter(),
          ),
          // Pin
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen,
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                child: Text(
                  'PARQUE DE LA RODA',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                width: 2,
                height: 12,
                color: GingaColors.brandGreen,
              ),
              const Icon(Icons.location_on,
                  color: GingaColors.brandGreen, size: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GingaColors.borderLight
      ..strokeWidth = 0.8;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────
//  DIVIDER
// ─────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: GingaColors.borderLight,
    );
  }
}