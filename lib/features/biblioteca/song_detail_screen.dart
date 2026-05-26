import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import '../../core/theme/ginga_theme.dart';
import 'cancionero_screen.dart'; // Para importar el modelo Cantiga

class SongDetailScreen extends StatefulWidget {
  final Cantiga cantiga;

  const SongDetailScreen({super.key, required this.cantiga});

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  double _currentProgress = 0.0; // En segundos
  int _totalSeconds = 120;
  
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

    // Inicializar reproductor de audio real
    _audioPlayer = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.cantiga.audioUrl.isNotEmpty) {
        await _audioPlayer.setUrl(widget.cantiga.audioUrl);
      }

      // Escuchar cambios de estado de reproducción
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (_isPlaying) {
              _waveController.repeat();
              _discController.repeat();
            } else {
              _waveController.stop();
              _discController.stop();
            }

            if (state.processingState == ProcessingState.completed) {
              _discController.reset();
              _audioPlayer.seek(Duration.zero);
              _audioPlayer.pause();
            }
          });
        }
      });

      // Escuchar cambios de posición transcurrida
      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentProgress = position.inMilliseconds / 1000.0;
          });
        }
      });

      // Escuchar cambios de duración total
      _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _totalSeconds = duration.inSeconds;
          });
        }
      });

    } catch (e) {
      debugPrint("Error al inicializar just_audio: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Liberar recursos de sonido del sistema
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
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _seek(double value) {
    _audioPlayer.seek(Duration(milliseconds: (value * 1000).toInt()));
  }

  void _skip(int seconds) {
    final newPos = _currentProgress + seconds;
    _audioPlayer.seek(Duration(seconds: newPos.clamp(0.0, _totalSeconds.toDouble()).toInt()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
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
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: GingaColors.textPrimary),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'CANTIGA CAPOEIRA',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textSecondary.withOpacity(0.8),
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
                    icon: const Icon(Icons.favorite_border_rounded, color: GingaColors.textPrimary, size: 22),
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

                    // ── Tocadiscos / Disco Vinilo Animado ──────────────────────
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
                              color: GingaColors.brandGreen.withOpacity(_isPlaying ? 0.08 : 0.02),
                              boxShadow: _isPlaying ? [
                                BoxShadow(
                                  color: GingaColors.brandGreen.withOpacity(0.1),
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
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Letra & Ritmo: ${widget.cantiga.autor}',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GingaColors.textSecondary,
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
                        inactiveTrackColor: GingaColors.borderLight,
                        thumbColor: GingaColors.brandGreen,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayColor: GingaColors.brandGreen.withOpacity(0.2),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _currentProgress.clamp(0.0, _totalSeconds.toDouble()),
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
                              color: GingaColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _formatDuration(_totalSeconds.toDouble()),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: GingaColors.textSecondary,
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
                            color: GingaColors.textPrimary.withOpacity(0.8),
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
                              color: GingaColors.brandGreen,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
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
                            color: GingaColors.textPrimary.withOpacity(0.8),
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
                        color: GingaColors.borderLight.withOpacity(0.5),
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
                                  color: _showPortuguese ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                                  boxShadow: _showPortuguese ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    )
                                  ] : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Português (Original)',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: _showPortuguese ? FontWeight.w800 : FontWeight.w600,
                                    color: _showPortuguese ? GingaColors.textPrimary : GingaColors.textSecondary,
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
                                  color: !_showPortuguese ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                                  boxShadow: !_showPortuguese ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    )
                                  ] : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Español (Traducción)',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: !_showPortuguese ? FontWeight.w800 : FontWeight.w600,
                                    color: !_showPortuguese ? GingaColors.textPrimary : GingaColors.textSecondary,
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
                        color: GingaColors.cardLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: Text(
                        _showPortuguese ? widget.cantiga.letraPt : widget.cantiga.letraEs,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          height: 1.8,
                          color: GingaColors.textPrimary,
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
                              color: GingaColors.textSecondary,
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

  // Silueta de una forma de onda masterizada estéticamente agradable (silencio en pausa)
  static const List<double> _waveEnvelope = [
    0.15, 0.20, 0.35, 0.40, 0.50, 0.60, 0.45, 0.35, 0.40, 0.65,
    0.80, 0.90, 0.75, 0.55, 0.40, 0.50, 0.70, 0.85, 0.95, 0.90,
    0.75, 0.65, 0.50, 0.60, 0.85, 0.90, 0.80, 0.60, 0.45, 0.35,
    0.40, 0.55, 0.70, 0.85, 0.65, 0.45, 0.30, 0.25, 0.30, 0.20,
    0.15, 0.10
  ];

  _SpectrogramPainter({required this.progress, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 42;
    const double spacing = 3.0;
    final double barWidth = (size.width - (barCount - 1) * spacing) / barCount;
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      // Obtener el valor base del mapa estático de la forma de onda
      final double baseHeightFactor = _waveEnvelope[i % _waveEnvelope.length];
      
      double heightMultiplier = 0.25; // Altura fija y uniforme en silencio
      
      if (isPlaying) {
        // En reproducción, generamos una oscilación orgánica fluida dependiente del tiempo
        final double wave1 = math.sin((i * 0.45) + (progress * 2 * math.pi));
        final double wave2 = math.cos((i * 0.75) - (progress * 3 * math.pi));
        
        // Normalizar la fluctuación a rango activo
        heightMultiplier = 0.45 + (wave1 + wave2).abs() * 0.27;
      }
      
      double barHeight = size.height * baseHeightFactor * heightMultiplier * 2.2;
      
      // Limitar altura mínima para mantener estética limpia
      if (barHeight < 3.0) barHeight = 3.0;
      // Limitar altura máxima para que no sobresalga del contenedor de CustomPaint
      if (barHeight > size.height) barHeight = size.height;

      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (barWidth + spacing),
          size.height / 2 - barHeight / 2,
          barWidth,
          barHeight,
        ),
        Radius.circular(barWidth / 2), // Cápsula perfectamente redondeada estilo premium
      );

      if (isPlaying) {
        // Color verde Ginga que fluctúa sutilmente creando un efecto de brillo
        paint.color = Color.lerp(
          GingaColors.brandGreen, 
          const Color(0xFF5CD895), 
          (i / barCount) + (math.sin(progress * math.pi) * 0.08)
        )!;
      } else {
        // En pausa, un gris ceniza premium muy limpio que dibuja la onda estática
        paint.color = GingaColors.borderLight;
      }

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SpectrogramPainter old) => true;
}
