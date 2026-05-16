import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';
// Importamos la que ya tenemos para navegar a ella
import 'practicar_toque_screen.dart'; 

class TutorialDetailScreen extends StatelessWidget {
  final String title;
  final String category;
  final String level;

  const TutorialDetailScreen({
    super.key,
    this.title = 'Passape',
    this.category = 'Movimientos',
    this.level = 'Iniciante',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // ── Header con Video/Imagen ────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: GingaColors.textPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Placeholder de Video o Imagen del Mestre
                 Image.asset(
  'assets/images/passape.jpg', // 👈 Asegúrate que la ruta sea la correcta en tu proyecto
  fit: BoxFit.cover,
),
                  // Overlay gradiente para legibilidad
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Botón Play
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: GingaColors.brandGreen.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido de la Lección ──────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildBadge(category, GingaColors.brandGreen),
                      const SizedBox(width: 8),
                      _buildBadge(level, GingaColors.accentAmber),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Instrucción por Mestre Enrique',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GingaColors.brandGreen,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Descripción Técnica',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El passape es un movimiento de ataque circular que utiliza la parte externa del pie. Es fundamental mantener la pierna de apoyo firme y la guardia alta en todo momento.',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      height: 1.6,
                      color: GingaColors.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  _buildTipBox(
                    'Consejo del Mestre',
                    'No quites la vista del oponente durante el giro del pie.',
                    Icons.tips_and_updates_outlined,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTipBox(
                    'Error Común',
                    'Inclinar el tronco demasiado hacia atrás pierde potencia.',
                    Icons.warning_amber_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ── Botón Flotante para Practicar ──────────────
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            // Navegamos a la pantalla de IA que ya pulimos
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PracticarToqueScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: GingaColors.brandGreen,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GingaRadius.md),
            ),
            elevation: 0,
          ),
          child: Text(
            '¡ESTOY LISTO, PRACTICAR!',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTipBox(String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GingaColors.brandGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: GingaColors.textSecondary,
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