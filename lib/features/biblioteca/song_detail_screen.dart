import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/theme/ginga_theme.dart';
import 'cultura_screen.dart'; // Para importar el modelo Cantiga

class SongDetailScreen extends StatefulWidget {
  final Cantiga cantiga;

  const SongDetailScreen({super.key, required this.cantiga});

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> with TickerProviderStateMixin {
  bool _isPlaying = false;
  double _currentProgress = 0.0; // En segundos
  int _totalSeconds = 120;
  Timer? _playbackTimer;
  late AnimationController _waveController;
  late AnimationController _discController;
  bool _showPortuguese = true;

  @override
  void initState() {
    super.initState();
    _totalSeconds = _parseDuration(widget.cantiga.duracion);
    
    // Controlador de onda ecualizadora
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Controlador de rotación del disco
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    if (_isPlaying) {
      _waveController.repeat();
      _discController.repeat();
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _waveController.dispose();
    _discController.dispose();
    super.dispose();
  }

  int _parseDuration(String durationStr) {
    final parts = durationStr.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return (minutes * 60) + seconds;
    }
    return 120; // Por defecto 2 minutos
  }

  String _formatDuration(double secondsDouble) {
    final totalSecs = secondsDouble.toInt();
    final minutes = totalSecs ~/ 60;
    final seconds = totalSecs % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _waveController.repeat();
        _discController.repeat();
        
        // Timer de reproducción suave (actualiza cada 100ms para suavidad extrema)
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          setState(() {
            if (_currentProgress < _totalSeconds) {
              _currentProgress += 0.1;
            } else {
              _isPlaying = false;
              _currentProgress = 0.0;
              _waveController.stop();
              _discController.reset();
              timer.cancel();
            }
          });
        });
      } else {
        _waveController.stop();
        _discController.stop();
        _playbackTimer?.cancel();
      }
    });
  }

  void _seek(double value) {
    setState(() {
      _currentProgress = value;
    });
  }

  void _skip(int seconds) {
    setState(() {
      _currentProgress = (_currentProgress + seconds).clamp(0.0, _totalSeconds.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Definimos una paleta de color oscura y super premium tipo Spotify
    const Color spotifyDark = Color(0xFF121212);
    const Color spotifyCard = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: spotifyDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Superior ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'CANTIGA CAPOEIRA',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.5),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.cantiga.ritmo,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.brandGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cantiga guardada en tus favoritos localmente 💚'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: GingaColors.brandGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ── Tocadiscos / Disco Giratorio Animado ──────────────────────
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Sombra pulsante de fondo
                          Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: GingaColors.brandGreen.withOpacity(_isPlaying ? 0.05 : 0.01),
                              boxShadow: _isPlaying ? [
                                BoxShadow(
                                  color: GingaColors.brandGreen.withOpacity(0.15),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                )
                              ] : [],
                            ),
                          ),
                          // Disco de vinilo animado
                          RotationTransition(
                            turns: _discController,
                            child: Container(
                              width: 175,
                              height: 175,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                                border: Border.all(color: Colors.grey.shade900, width: 3),
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFF2C2C2C),
                                    Color(0xFF0F0F0F),
                                    Colors.black,
                                  ],
                                  stops: [0.0, 0.45, 1.0],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: ClipOval(
                                child: Container(
                                  width: 65,
                                  height: 65,
                                  color: GingaColors.brandGreen,
                                  child: const Icon(
                                    Icons.album_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Título y Autor ────────────────
                    Text(
                      widget.cantiga.titulo,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Letra & Ritmo: ${widget.cantiga.autor}',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Ecualizador de Ondas Espectral Reactiva ────────────────
                    SizedBox(
                      height: 35,
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _SpectrogramPainter(
                              progress: _waveController.value,
                              isPlaying: _isPlaying,
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Barra de Progreso Slider Reactivo ────────────────
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        activeTrackColor: GingaColors.brandGreen,
                        inactiveTrackColor: Colors.white.withOpacity(0.15),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayColor: GingaColors.brandGreen.withOpacity(0.2),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _currentProgress,
                        min: 0.0,
                        max: _totalSeconds.toDouble(),
                        onChanged: _seek,
                      ),
                    ),

                    // Tiempos (actual vs total)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_currentProgress),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.cantiga.duracion,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Controles de Reproducción (Play/Pause/Skip) ────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Retroceder 10s
                        IconButton(
                          onPressed: () => _skip(-10),
                          icon: Icon(
                            Icons.replay_10_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Play/Pause Central
                        GestureDetector(
                          onTap: _togglePlayback,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 38,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Avanzar 10s
                        IconButton(
                          onPressed: () => _skip(10),
                          icon: Icon(
                            Icons.forward_10_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 28,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Switch Selector de Letras Bilingüe ────────────────
                    Container(
                      height: 40,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: spotifyCard,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _showPortuguese = true),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _showPortuguese ? Colors.white.withOpacity(0.12) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Português (Original)',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: _showPortuguese ? FontWeight.w800 : FontWeight.w600,
                                    color: _showPortuguese ? Colors.white : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _showPortuguese = false),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !_showPortuguese ? Colors.white.withOpacity(0.12) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Español (Traducción)',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: !_showPortuguese ? FontWeight.w800 : FontWeight.w600,
                                    color: !_showPortuguese ? Colors.white : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Bloque de Letra (Lyrics) ────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: spotifyCard,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Text(
                        _showPortuguese ? widget.cantiga.letraPt : widget.cantiga.letraEs,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          height: 1.8,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Contexto e Historia del Tema ────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: GingaColors.brandGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: GingaColors.brandGreen.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: GingaColors.brandGreen, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Contexto en la Roda',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: GingaColors.brandGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.cantiga.contexto,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.75),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pintor de la onda ecualizadora del reproductor ──

class _SpectrogramPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;

  _SpectrogramPainter({required this.progress, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final int barCount = 42;
    final double spacing = 3.0;
    final double barWidth = (size.width - (barCount - 1) * spacing) / barCount;
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      double baseHeight = math.sin((i / barCount * 3 * math.pi) + (progress * 2 * math.pi)).abs();
      double energy = isPlaying ? (0.3 + math.Random().nextDouble() * 0.7) : 0.15;
      double barHeight = size.height * baseHeight * energy;
      
      if (barHeight < 4) barHeight = 4;

      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (barWidth + spacing),
          size.height / 2 - barHeight / 2,
          barWidth,
          barHeight,
        ),
        const Radius.circular(8),
      );

      paint.color = isPlaying
          ? Color.lerp(Colors.white.withOpacity(0.2), GingaColors.brandGreen, baseHeight * energy)!
          : Colors.white.withOpacity(0.12);

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SpectrogramPainter old) => true;
}
