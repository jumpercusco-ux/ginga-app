import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';
import 'practicar_toque_screen.dart';
import 'cancionero_screen.dart';

class MusicaScreen extends StatelessWidget {
  const MusicaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Suscribir al tema para regenerar la pantalla al alternar claro/oscuro
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Barra Superior (App Bar) ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_ios_new, size: 18, color: GingaColors.textPrimary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Música',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'El Corazón de la Roda',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: GingaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aprende los toques del berimbau y canta las cantigas de capoeira',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: GingaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Toques de Berimbau Card ────────────────────
              _MusicaMenuCard(
                titulo: 'Toques de Berimbau',
                subtitulo: 'Próximamente - Sección en desarrollo activo 🛠️',
                icono: Icons.music_note,
                tag: 'PRÓXIMAMENTE ⏳',
                tagColor: GingaColors.accentAmber,
                color: GingaColors.accentAmber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PracticarToqueScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Cantigas Card ────────────────────
              _MusicaMenuCard(
                titulo: 'Cantigas Tradicionales',
                subtitulo: 'Letras bilingües, traducciones y reproductor interactivo',
                icono: Icons.library_music,
                tag: 'CANTO',
                tagColor: Colors.purple,
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CancioneroScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicaMenuCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final String tag;
  final Color tagColor;
  final Color color;
  final VoidCallback onTap;

  const _MusicaMenuCard({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: GingaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: GingaColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
