import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                ),
              ),

              const SizedBox(height: 24),

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

              // Lista de lecciones desde Firestore en tiempo real
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tutoriales')
                    .limit(3)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: GingaColors.brandGreen),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: GingaColors.cardLight,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                      ),
                      child: Center(
                        child: Text(
                          'No hay lecciones en la biblioteca aún',
                          style: GoogleFonts.nunito(color: GingaColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final titulo = data['titulo'] ?? '';
                      final nivel = data['nivel'] ?? 'Iniciante';
                      final duracion = data['duracion'] ?? '6 min';
                      final categoria = data['categoria'] ?? 'Ataques';
                      final descripcion = data['descripcion'] ?? '';
                      final tipMestre = data['tipMestre'] ?? '';
                      final tipError = data['tipError'] ?? '';
                      final imagenUrl = data['imagen_url'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LeccionCard(
                          titulo: titulo,
                          nivel: nivel,
                          duracion: duracion,
                          icono: categoria == 'Fundamentos'
                              ? Icons.school_rounded
                              : categoria == 'Floreos'
                                  ? Icons.accessibility_new
                                  : Icons.sports_martial_arts,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TutorialDetailScreen(
                                title: titulo,
                                category: categoria,
                                level: nivel,
                                description: descripcion,
                                tipMestre: tipMestre,
                                tipError: tipError,
                                imageUrl: imagenUrl,
                                videoUrl: data['video_url'] ?? '',
                                duracion: duracion,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
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

