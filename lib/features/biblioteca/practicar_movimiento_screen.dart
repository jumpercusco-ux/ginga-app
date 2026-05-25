import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/tts_service.dart';

class PracticarMovimientoScreen extends StatefulWidget {
  final String titulo;
  final String duracion;
  final String categoria;
  final String videoUrl;
  final String imageUrl;

  const PracticarMovimientoScreen({
    super.key,
    required this.titulo,
    required this.duracion,
    required this.categoria,
    this.videoUrl = '',
    this.imageUrl = 'assets/images/placeholder_custom.jpg',
  });

  @override
  State<PracticarMovimientoScreen> createState() => _PracticarMovimientoScreenState();
}

class _PracticarMovimientoScreenState extends State<PracticarMovimientoScreen> {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isCompleted = false;
  bool _metronomeActive = false;

  // Controlador del video looping en el círculo
  VideoPlayerController? _videoPlayerController;
  bool _isPlayerInitialized = false;
  bool _hasError = false;

  // Lista de mantras motivacionales que rotan cada 12 segundos
  final List<String> _motivationQuotes = [
    "Mantén tu centro de gravedad bajo. ¡Flexiona rodillas!",
    "No bajes la guardia. Protege tu rostro en cada paso.",
    "Busca fluidez y ritmo en la esquiva.",
    "El giro nace de la cadera. Siente la inercia.",
    "La mirada siempre al oponente. No mires al suelo.",
    "Respira profundo. La capoeira es resistencia y maña.",
  ];
  int _currentQuoteIndex = 0;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    
    // Parsear la duración
    int minutes = 5;
    try {
      final numberString = widget.duracion.replaceAll(RegExp(r'[^0-9]'), '');
      if (numberString.isNotEmpty) {
        minutes = int.parse(numberString);
      }
    } catch (e) {
      minutes = 5;
    }

    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;

    _inicializarVideoLoop();
    _startTimer();
    _startQuoteRotation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _quoteTimer?.cancel();
    _videoPlayerController?.dispose();
    TtsService.instance.stop(); // Detener narración de voz al salir
    super.dispose();
  }

  Future<void> _inicializarVideoLoop() async {
    final rawUrl = widget.videoUrl;
    // Si no tiene url de video, usamos el loop de entrenamiento HD en red por defecto para wowear al usuario
    final videoUrlStr = rawUrl.isNotEmpty 
        ? rawUrl 
        : 'https://assets.mixkit.co/videos/preview/mixkit-martial-arts-fighter-performing-kicks-40893-large.mp4';

    try {
      if (videoUrlStr.startsWith('http')) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrlStr));
      } else if (videoUrlStr.startsWith('assets/')) {
        _videoPlayerController = VideoPlayerController.asset(videoUrlStr);
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrlStr));
      }

      await _videoPlayerController!.initialize();
      _videoPlayerController!.setVolume(0.0); // Mudo
      _videoPlayerController!.setLooping(true); // Bucle infinito
      
      if (mounted) {
        setState(() {
          _isPlayerInitialized = true;
        });
        if (_isRunning) {
          _videoPlayerController!.play();
        }
      }
    } catch (e) {
      debugPrint('Error al inicializar bucle de video en cronómetro: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _isRunning = true);
    _videoPlayerController?.play();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _completeWorkout();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
    _videoPlayerController?.pause();
  }

  void _startQuoteRotation() {
    _quoteTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (_isRunning && mounted) {
        setState(() {
          _currentQuoteIndex = (_currentQuoteIndex + 1) % _motivationQuotes.length;
        });
      }
    });
  }

  void _completeWorkout() {
    _timer?.cancel();
    _quoteTimer?.cancel();
    _videoPlayerController?.pause();
    setState(() {
      _isRunning = false;
      _isCompleted = true;
    });
  }

  String _formatTime(int totalSecs) {
    final minutes = totalSecs ~/ 60;
    final seconds = totalSecs % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildPlaceholderImage() {
    if (widget.imageUrl.startsWith('assets/')) {
      return Image.asset(widget.imageUrl, fit: BoxFit.cover);
    }
    return Image.network(
      widget.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: GingaColors.cardLight,
          child: const Icon(Icons.sports_martial_arts, color: GingaColors.brandGreen, size: 48),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) {
      return _buildCelebrationScreen();
    }

    final progress = 1.0 - (_remainingSeconds / _totalSeconds);

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: GingaColors.textPrimary, size: 28),
                    onPressed: () {
                      _showExitConfirmationDialog();
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GingaColors.brandGreen.withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.categoria.toUpperCase(),
                      style: GoogleFonts.montserrat(
                        color: GingaColors.brandGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balanceador
                ],
              ),

              const Spacer(),

              // ── Título del movimiento ───────────────────────────────────────
              Text(
                'Entrenando ${widget.titulo}',
                style: GoogleFonts.montserrat(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: GingaColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Observa el bucle guía y mantén la técnica',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: GingaColors.textSecondary,
                ),
              ),

              const Spacer(),

              // ── Cronómetro Circular Animado con Video Loop Interior ──────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Sombra ambiental / Resplandor verde suave
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: GingaColors.brandGreen.withOpacity(_isRunning ? 0.15 : 0.05),
                          blurRadius: 35,
                          spreadRadius: 8,
                        )
                      ],
                    ),
                  ),

                  // 1. Video o Imagen recortada en círculo (El Bucle Guía de fondo)
                  ClipOval(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Reproductor del bucle silencioso
                          if (_isPlayerInitialized && _videoPlayerController != null && !_hasError)
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoPlayerController!.value.size.width,
                                height: _videoPlayerController!.value.size.height,
                                child: VideoPlayer(_videoPlayerController!),
                              ),
                            )
                          else
                            _buildPlaceholderImage(),

                          // Filtro oscuro translúcido para garantizar legibilidad del texto del cronómetro
                          Container(
                            color: Colors.black.withOpacity(0.42),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Barra de progreso circular de fondo
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 9,
                      valueColor: AlwaysStoppedAnimation(Colors.grey.shade300.withOpacity(0.3)),
                    ),
                  ),

                  // 3. Barra de progreso circular activa en verde
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      valueColor: const AlwaysStoppedAnimation(GingaColors.brandGreen),
                    ),
                  ),

                  // 4. Textos del tiempo interior (Flotando sobre el video)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_remainingSeconds),
                        style: GoogleFonts.montserrat(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                      Text(
                        'restantes',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // ── Caja de consejos / feedback dinámico ────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: GingaColors.cardLight,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(
                    color: TtsService.instance.isSpeaking(_motivationQuotes[_currentQuoteIndex])
                        ? GingaColors.brandGreen
                        : GingaColors.brandGreen.withOpacity(0.2),
                    width: TtsService.instance.isSpeaking(_motivationQuotes[_currentQuoteIndex]) ? 1.5 : 1,
                  ),
                  boxShadow: TtsService.instance.isSpeaking(_motivationQuotes[_currentQuoteIndex])
                      ? [
                          BoxShadow(
                            color: GingaColors.brandGreen.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_rounded, color: GingaColors.accentAmber, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CONSEJO DEL MESTRE',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: GingaColors.brandGreen,
                                  letterSpacing: 1,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    TtsService.instance.speak(_motivationQuotes[_currentQuoteIndex]);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: TtsService.instance.isSpeaking(_motivationQuotes[_currentQuoteIndex])
                                        ? GingaColors.brandGreen.withOpacity(0.12)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    TtsService.instance.isSpeaking(_motivationQuotes[_currentQuoteIndex])
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_mute_rounded,
                                    color: GingaColors.brandGreen,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _motivationQuotes[_currentQuoteIndex],
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: GingaColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Metrónomo / Base Rítmica ────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: GingaColors.cardLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: GingaColors.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.audiotrack_rounded,
                      color: _metronomeActive ? GingaColors.brandGreen : GingaColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Base Rítmica Berimbau',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: _metronomeActive ? GingaColors.textPrimary : GingaColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _metronomeActive,
                      onChanged: (val) {
                        setState(() {
                          _metronomeActive = val;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val 
                              ? 'Base rítmica activada (Ritmo: Ginga Base)' 
                              : 'Base rítmica desactivada'),
                            duration: const Duration(seconds: 1),
                            backgroundColor: GingaColors.brandGreen,
                          ),
                        );
                      },
                      activeColor: GingaColors.brandGreen,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Controles Inferiores ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botón Pausar / Continuar
                  ElevatedButton.icon(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: Text(_isRunning ? 'PAUSAR' : 'REANUDAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? GingaColors.borderLight : GingaColors.brandGreen,
                      foregroundColor: _isRunning ? GingaColors.textPrimary : Colors.white,
                      minimumSize: const Size(150, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                      elevation: 0,
                    ),
                  ),

                  // Botón Terminar
                  OutlinedButton.icon(
                    onPressed: () {
                      _showCompleteEarlyDialog();
                    },
                    icon: const Icon(Icons.done_all_rounded, color: Colors.red),
                    label: const Text('COMPLETAR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      minimumSize: const Size(150, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pantalla de Celebración Premium ────────────────────────────────
  Widget _buildCelebrationScreen() {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Insignia de Trofeo Animada
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: GingaColors.brandGreen, width: 2),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: GingaColors.brandGreen,
                  size: 56,
                ),
              ),

              const SizedBox(height: 32),

              // Felicitación
              Text(
                '¡Excelente Axé!',
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: GingaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Has completado tu práctica diaria de ${widget.titulo}. Cada minuto de ginga te acerca más a tu próxima corda.',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: GingaColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Tarjeta de Recompensas
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: GingaColors.cardLight,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: GingaColors.brandGreen.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRewardStat('+50 XP', 'Experiencia'),
                    Container(width: 1, height: 40, color: GingaColors.brandGreen.withOpacity(0.3)),
                    _buildRewardStat('+1', 'Práctica Hoy'),
                    Container(width: 1, height: 40, color: GingaColors.brandGreen.withOpacity(0.3)),
                    _buildRewardStat('100%', 'Precisión'),
                  ],
                ),
              ),

              const Spacer(),

              // Botón Volver a la biblioteca
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true); // Retornar true para indicar completado
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
                  'VOLVER A LA BIBLIOTECA',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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

  Widget _buildRewardStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: GingaColors.brandGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: GingaColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Diálogos de Confirmación
  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.lg)),
          title: Text(
            '¿Abandonar entrenamiento?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Si sales ahora, no se guardará el registro de práctica de hoy para este movimiento.',
            style: GoogleFonts.nunito(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'SEGUIR ENTRENANDO',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: GingaColors.brandGreen),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(
                'SALIR',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCompleteEarlyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.lg)),
          title: Text(
            '¿Terminar temprano?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '¿Ya has sudado la camiseta y dominado el movimiento? Si es así, puedes completar tu registro de hoy.',
            style: GoogleFonts.nunito(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'MÁS TIEMPO',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: GingaColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.sm)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _completeWorkout();
              },
              child: Text(
                '¡COMPLETAR YA!',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
