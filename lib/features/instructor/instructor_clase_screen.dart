import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class InstructorClaseScreen extends StatefulWidget {
  const InstructorClaseScreen({super.key});

  @override
  State<InstructorClaseScreen> createState() => _InstructorClaseScreenState();
}

class _InstructorClaseScreenState extends State<InstructorClaseScreen> {
  final List<_AlumnoData> _alumnos = [
    _AlumnoData(
      nombre: 'Enrique',
      corda: 'Corda Verde',
      initials: 'E',
      status: _Status.enClase,
    ),
    _AlumnoData(
      nombre: 'Carla',
      corda: 'Iniciante',
      initials: 'C',
      status: _Status.pagoPendiente,
    ),
    _AlumnoData(
      nombre: 'Pedro',
      corda: 'Corda Amarela',
      initials: 'P',
      status: _Status.reservado,
    ),
    _AlumnoData(
      nombre: 'Sofía',
      corda: 'Corda Verde/Amarela',
      initials: 'S',
      status: _Status.enClase,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: GingaColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Ginga App',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Clase actual ─────────────────
                    _ClaseActualCard(),

                    const SizedBox(height: 24),

                    // ── Lista de alumnos ─────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lista de Alumnos',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            'Ver todos',
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

                    // Lista
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _alumnos.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: GingaColors.borderLight),
                      itemBuilder: (context, index) {
                        return _AlumnoTile(alumno: _alumnos[index]);
                      },
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── FAB QR Scanner ──────────────────────────
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: GingaColors.brandGreen,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: GingaColors.brandGreen.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.qr_code_scanner,
            color: Colors.white, size: 26),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CLASE ACTUAL CARD
// ─────────────────────────────────────────

class _ClaseActualCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con badge inscriptos
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clase Actual:',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: GingaColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Capoeira Adultos',
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_outlined,
                            size: 13, color: GingaColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '19:00 hrs · Sede Lima',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: GingaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Badge inscriptos
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: GingaColors.cardLight,
                    borderRadius: BorderRadius.circular(GingaRadius.full),
                  ),
                  child: Text(
                    'Inscritos: 18/25',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.brandGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Imagen placeholder
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: GingaColors.backgroundDark,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(GingaRadius.lg),
                bottomRight: Radius.circular(GingaRadius.lg),
              ),
            ),
            child: const Center(
              child: Icon(Icons.sports_martial_arts,
                  color: GingaColors.brandGreen, size: 48),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ALUMNO TILE
// ─────────────────────────────────────────

class _AlumnoTile extends StatelessWidget {
  final _AlumnoData alumno;
  const _AlumnoTile({required this.alumno});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: GingaColors.cardLight,
            child: Text(
              alumno.initials,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                color: GingaColors.brandGreen,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alumno.nombre,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                Text(
                  alumno.corda,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: GingaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Badge de estado
          _StatusBadge(status: alumno.status),

          const SizedBox(width: 8),

          // Menú
          const Icon(Icons.more_vert,
              size: 18, color: GingaColors.textSecondary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STATUS BADGE
// ─────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final _Status status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case _Status.enClase:
        bg = GingaColors.brandGreen.withOpacity(0.12);
        text = GingaColors.brandGreen;
        label = 'EN CLASE';
        break;
      case _Status.pagoPendiente:
        bg = GingaColors.accentAmber.withOpacity(0.15);
        text = const Color(0xFF856200);
        label = 'PAGO PENDIENTE';
        break;
      case _Status.reservado:
        bg = GingaColors.borderLight;
        text = GingaColors.textSecondary;
        label = 'RESERVADO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GingaRadius.sm),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  MODELOS
// ─────────────────────────────────────────

enum _Status { enClase, pagoPendiente, reservado }

class _AlumnoData {
  final String nombre;
  final String corda;
  final String initials;
  final _Status status;

  _AlumnoData({
    required this.nombre,
    required this.corda,
    required this.initials,
    required this.status,
  });
}