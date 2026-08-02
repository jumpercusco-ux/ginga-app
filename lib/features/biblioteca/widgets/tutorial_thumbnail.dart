import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/ginga_theme.dart';
import '../../../core/widgets/ginga_cached_image.dart';

class TutorialThumbnail extends StatelessWidget {
  final String imagenUrl;
  final String categoria;
  final String titulo;
  final double? width;
  final double? height;
  final double iconSize;
  final bool showPlayIcon;

  const TutorialThumbnail({
    super.key,
    required this.imagenUrl,
    required this.categoria,
    required this.titulo,
    this.width,
    this.height,
    this.iconSize = 24.0,
    this.showPlayIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imagenUrl.isNotEmpty) {
      return GingaCachedImage(
        imageUrl: imagenUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        category: categoria,
        errorWidget: _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final String catNorm = categoria.trim().toLowerCase();
    
    // Configuración por categoría
    List<Color> gradientColors;
    IconData icon;
    String watermarkText = '';

    if (catNorm.contains('ataque')) {
      gradientColors = [const Color(0xFF0F9D58), const Color(0xFF0B6623)];
      icon = Icons.bolt;
      watermarkText = 'ATAQUE';
    } else if (catNorm.contains('defensa')) {
      gradientColors = [const Color(0xFF1E88E5), const Color(0xFF0D47A1)];
      icon = Icons.shield_outlined;
      watermarkText = 'DEFENSA';
    } else if (catNorm.contains('esquiva')) {
      gradientColors = [const Color(0xFFAB47BC), const Color(0xFF4A148C)];
      icon = Icons.double_arrow_rounded;
      watermarkText = 'ESQUIVA';
    } else if (catNorm.contains('floreo')) {
      gradientColors = [const Color(0xFFFF7043), const Color(0xFFD84315)];
      icon = Icons.auto_awesome;
      watermarkText = 'FLOREO';
    } else if (catNorm.contains('fundamento') || catNorm.contains('ginga')) {
      gradientColors = [const Color(0xFF26A69A), const Color(0xFF00695C)];
      icon = Icons.menu_book_rounded;
      watermarkText = 'FUNDAMENTO';
    } else {
      // Por defecto
      gradientColors = [const Color(0xFF546E7A), const Color(0xFF263238)];
      icon = Icons.play_circle_outline;
      watermarkText = 'LECCIÓN';
    }

    // Iniciales o primera letra del título para dar textura personalizada
    final String inicial = titulo.isNotEmpty ? titulo[0].toUpperCase() : '';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Marca de agua de texto en background con opacidad
          Positioned(
            right: -8,
            bottom: -6,
            child: Opacity(
              opacity: 0.12,
              child: Text(
                watermarkText,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          
          // Letra inicial grande y difuminada en el centro/fondo
          Opacity(
            opacity: 0.08,
            child: Text(
              inicial,
              style: GoogleFonts.montserrat(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),

          // Icono decorativo de la categoría en la esquina superior izquierda
          Positioned(
            left: 8,
            top: 8,
            child: Opacity(
              opacity: 0.25,
              child: Icon(
                icon,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),

          // Botón Play destacado en el centro
          if (showPlayIcon)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: iconSize,
              ),
            ),
        ],
      ),
    );
  }
}
