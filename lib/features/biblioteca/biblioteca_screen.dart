import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';
import 'practicar_toque_screen.dart';

class BibliotecaScreen extends StatelessWidget {
  const BibliotecaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Header ──────────────────────────────
              Text(
                'A Biblioteca',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: GingaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aprende, practica y descubre la cultura',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: GingaColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // ── Sección principal ────────────────────
              _SeccionCard(
                titulo: 'Practicar Toque',
                subtitulo: 'Identifica ritmos con IA en tiempo real',
                icono: Icons.music_note,
                tag: 'IA',
                tagColor: GingaColors.brandGreen,
                color: GingaColors.brandGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PracticarToqueScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              _SeccionCard(
                titulo: 'Tutoriales On-Demand',
                subtitulo: 'Micro-lecciones de técnica para practicar en casa',
                icono: Icons.play_circle_outline,
                tag: 'NUEVO',
                tagColor: GingaColors.accentAmber,
                color: GingaColors.accentAmber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TutorialesScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              _SeccionCard(
                titulo: 'Cultura Capoeira',
                subtitulo: 'Cantigas, historia y enciclopedia de mestres',
                icono: Icons.menu_book_outlined,
                tag: 'CULTURA',
                tagColor: GingaColors.textSecondary,
                color: GingaColors.textSecondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CulturaScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Últimas lecciones ────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Últimas lecciones',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Ver todas',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: GingaColors.brandGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Lista de lecciones
              _LeccionCard(
                titulo: 'Ginga Básica',
                nivel: 'Iniciante',
                duracion: '5 min',
                icono: Icons.directions_run,
              ),
              const SizedBox(height: 10),
              _LeccionCard(
                titulo: 'Au Batido',
                nivel: 'Graduado',
                duracion: '8 min',
                icono: Icons.accessibility_new,
              ),
              const SizedBox(height: 10),
              _LeccionCard(
                titulo: 'Meia Lua de Frente',
                nivel: 'Iniciante',
                duracion: '6 min',
                icono: Icons.sports_martial_arts,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SECCIÓN CARD
// ─────────────────────────────────────────

class _SeccionCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final String tag;
  final Color tagColor;
  final Color color;
  final VoidCallback onTap;

  const _SeccionCard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.tag,
    required this.tagColor,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(color: GingaColors.borderLight),
        ),
        child: Row(
          children: [
            // Ícono
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(GingaRadius.md),
              ),
              child: Icon(icono, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
               Row(
  children: [
    Flexible(
      child: Text(
        titulo,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.montserrat(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: GingaColors.textPrimary,
        ),
      ),
    ),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: tagColor,
          letterSpacing: 0.3,
        ),
      ),
    ),
  ],
),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: GingaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: GingaColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  LECCION CARD
// ─────────────────────────────────────────

class _LeccionCard extends StatelessWidget {
  final String titulo;
  final String nivel;
  final String duracion;
  final IconData icono;

  const _LeccionCard({
    required this.titulo,
    required this.nivel,
    required this.duracion,
    required this.icono,
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
          // Thumbnail
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: GingaColors.backgroundDark,
              borderRadius: BorderRadius.circular(GingaRadius.md),
            ),
            child: Icon(icono, color: GingaColors.brandGreen, size: 24),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: GingaColors.cardLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        nivel,
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: GingaColors.brandGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time_outlined,
                        size: 12, color: GingaColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      duracion,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: GingaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Play button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: GingaColors.brandGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TUTORIALES SCREEN (placeholder)
// ─────────────────────────────────────────

class TutorialesScreen extends StatelessWidget {
  const TutorialesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        title: Text('Tutoriales',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        backgroundColor: GingaColors.backgroundLight,
        elevation: 0,
        foregroundColor: GingaColors.textPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline,
                color: GingaColors.brandGreen, size: 64),
            const SizedBox(height: 16),
            Text('Tutoriales On-Demand',
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Próximamente — Sprint 8',
                style: GoogleFonts.nunito(
                    fontSize: 14, color: GingaColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CULTURA SCREEN (placeholder)
// ─────────────────────────────────────────

class CulturaScreen extends StatelessWidget {
  const CulturaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        title: Text('Cultura Capoeira',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        backgroundColor: GingaColors.backgroundLight,
        elevation: 0,
        foregroundColor: GingaColors.textPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined,
                color: GingaColors.brandGreen, size: 64),
            const SizedBox(height: 16),
            Text('Cultura & Historia',
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Próximamente — Sprint 8',
                style: GoogleFonts.nunito(
                    fontSize: 14, color: GingaColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}