import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';
import 'practicar_toque_screen.dart';
import 'tutor_detail_screen.dart';
import 'cultura_screen.dart';
import 'tutoriales_screen.dart';


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
                               // ── Sección principal ────────────────────
              _SeccionCard(
                titulo: 'Toques',
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
                titulo: 'Tutoriales',
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
                titulo: 'Cultura',
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
                titulo: 'Passape',
                nivel: 'Iniciante',
                duracion: '6 min',
                icono: Icons.sports_martial_arts,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TutorialDetailScreen(
                      title: 'Passape',
                      category: 'Ataques',
                      level: 'Iniciante',
                      description: 'El passape es un movimiento de ataque circular que utiliza la parte externa del pie. Es fundamental mantener la pierna de apoyo firme y la guardia alta en todo momento para evitar contraataques rápidos.',
                      tipMestre: 'No quites la vista del oponente durante el giro del pie y mantén la guardia firme.',
                      tipError: 'Inclinar el tronco demasiado hacia atrás te hace perder el equilibrio y la potencia del golpe.',
                      imageUrl: 'assets/images/passape.jpg',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _LeccionCard(
                titulo: 'Au Batido',
                nivel: 'Graduado',
                duracion: '8 min',
                icono: Icons.accessibility_new,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TutorialDetailScreen(
                      title: 'Au Batido',
                      category: 'Floreos',
                      level: 'Graduado',
                      description: 'El Au Batido (también conocido como Au de Bico) es una de las acrobacias más icónicas y funcionales de la capoeira. Combina un giro de Au (rueda) bloqueado a mitad de camino sobre una sola mano, lanzando una patada defensiva/ofensiva con la pierna libre mientras proteges el rostro.',
                      tipMestre: 'Fortalece tus muñecas y empuja activamente el suelo con el hombro del brazo de apoyo para ganar altura.',
                      tipError: 'Dejar caer la cadera antes de completar el bloqueo arruina la postura y puede sobrecargar tu hombro.',
                      imageUrl: 'assets/images/au_batido.jpg',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _LeccionCard(
                titulo: 'Meia Lua de Frente',
                nivel: 'Iniciante',
                duracion: '6 min',
                icono: Icons.sports_martial_arts,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TutorialDetailScreen(
                      title: 'Meia Lua de Frente',
                      category: 'Ataques',
                      level: 'Iniciante',
                      description: 'Un movimiento semicircular básico de ataque de afuera hacia adentro. La pierna describe un semicírculo amplio y extendido frente al cuerpo cruzando la línea de guardia del oponente.',
                      tipMestre: 'Mantén el talón de la pierna de apoyo completamente plantado en el suelo para no perder estabilidad.',
                      tipError: 'Bajar los brazos durante el recorrido de la patada expone tu cabeza a una contrapatada directa.',
                      imageUrl: 'assets/images/meia_lua.jpg',
                    ),
                  ),
                ),
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
  final VoidCallback? onTap; // 👈 Añadimos esto

  const _LeccionCard({
    required this.titulo,
    required this.nivel,
    required this.duracion,
    required this.icono,
    this.onTap, // 👈 Y esto
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector( // 👈 Envolvemos en GestureDetector para que funcione el clic
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(color: GingaColors.borderLight),
        ),
        child: Row(
          children: [
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      const Icon(Icons.access_time_outlined, size: 12, color: GingaColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(duracion, style: GoogleFonts.nunito(fontSize: 11, color: GingaColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: GingaColors.brandGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

