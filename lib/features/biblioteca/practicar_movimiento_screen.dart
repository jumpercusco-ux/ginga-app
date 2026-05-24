import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class PracticarMovimientoScreen extends StatefulWidget {
  final String titulo;
  final String duracion;
  final String categoria;

  const PracticarMovimientoScreen({
    super.key,
    required this.titulo,
    required this.duracion,
    required this.categoria,
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

  // Lista de mantras motivacionales que rotan cada 15 segundos
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
    // Parsear la duración. Ej: "10 min" -> 10 minutos
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
    _startTimer();
    _startQuoteRotation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _quoteTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _isRunning = true);
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

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) {
      return _buildCelebrationScreen();
    }

    final progress = 1.0 - (_remainingSeconds / _totalSeconds);

    return Scaffold(
      backgroundColor: GingaColors.backgroundDark,
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
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () {
                      _showExitConfirmationDialog();
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GingaColors.brandGreen.withOpacity(0.4)),
                    ),
                    child: Text(
                      widget.categoria.toUpperCase(),
                      style: GoogleFonts.montserrat(
                        color: GingaColors.accentGreenDark,
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
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Deja tu celular en el suelo y sigue el ritmo',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: GingaColors.textMuted,
                ),
              ),

              const Spacer(),

              // ── Cronómetro Circular Animado ──────────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Sombra ambiental / Resplandor
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: GingaColors.brandGreen.withOpacity(_isRunning ? 0.2 : 0.05),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                  ),
                  // Barra de progreso circular de fondo
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 10,
                      valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  // Barra de progreso circular activa
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      valueColor: const AlwaysStoppedAnimation(GingaColors.brandGreen),
                    ),
                  ),
                  // Textos del tiempo interior
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_remainingSeconds),
                        style: GoogleFonts.montserrat(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'restantes',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: GingaColors.textMuted,
                          fontWeight: FontWeight.w600,
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
                  color: GingaColors.surfaceDark,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: GingaColors.brandGreen.withOpacity(0.15)),
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
                          Text(
                            'CONSEJO DEL MESTRE',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: GingaColors.accentAmber,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _motivationQuotes[_currentQuoteIndex],
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: GingaColors.textWhite,
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
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.audiotrack_rounded,
                      color: _metronomeActive ? GingaColors.accentGreenDark : GingaColors.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Base Rítmica Berimbau',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: _metronomeActive ? Colors.white : GingaColors.textMuted,
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
                      activeColor: GingaColors.accentGreenDark,
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
                      backgroundColor: _isRunning ? Colors.white24 : GingaColors.brandGreen,
                      foregroundColor: Colors.white,
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
