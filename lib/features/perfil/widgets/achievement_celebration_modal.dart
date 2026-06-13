import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/ginga_theme.dart';

class AchievementCelebrationModal extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String badgeLabel;

  const AchievementCelebrationModal({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.badgeLabel,
  });

  @override
  State<AchievementCelebrationModal> createState() => _AchievementCelebrationModalState();
}

class _AchievementCelebrationModalState extends State<AchievementCelebrationModal> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late AnimationController _rotationController;
  late AnimationController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // 1. Animación de Entrada Elástica (Bounce)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    // 2. Animación de Rotación para el Sunburst (Glow de fondo)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 3. Simulación de Partículas (Confeti)
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _generateParticles();

    // Iniciar todo
    _entranceController.forward();
    _confettiController.forward();
    _playCelebrationSound();
  }

  void _generateParticles() {
    final colors = [
      GingaColors.brandGreen,
      GingaColors.accentAmber,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.orangeAccent,
    ];

    // Generar un estallido inicial en el centro
    for (int i = 0; i < 60; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 3.0 + _random.nextDouble() * 7.0;
      _particles.add(
        _ConfettiParticle(
          x: 0, // Relativo al centro
          y: -50,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 5.0, // Impulso inicial hacia arriba
          size: 6.0 + _random.nextDouble() * 10.0,
          color: colors[_random.nextInt(colors.length)],
          rotation: _random.nextDouble() * 2 * math.pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
          isCircle: _random.nextBool(),
        ),
      );
    }
  }

  Future<void> _playCelebrationSound() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/tim.mp3');
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('GINGA_DEBUG: Error al reproducir audio de logro: $e');
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _rotationController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Fondo Glassmorphism
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // Evitar que clics accidentales lo descarten
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),

          // 2. Animador de Confeti
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  _updateConfettiPhysics();
                  return CustomPaint(
                    painter: _ConfettiPainter(particles: _particles),
                  );
                },
              ),
            ),
          ),

          // 3. Tarjeta de Alerta Central (Scale Transition)
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: const BoxConstraints(maxHeight: 520),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge con Glow Rotativo
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow Rotativo (Sunburst)
                          RotationTransition(
                            turns: _rotationController,
                            child: CustomPaint(
                              size: const Size(160, 160),
                              painter: _SunburstPainter(color: widget.color),
                            ),
                          ),
                          // Sombra difusa
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          // Medalla/Insignia Central
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.color,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.color,
                              size: 48,
                            ),
                          ),
                          // Destello estético
                          Positioned(
                            top: 25,
                            right: 25,
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Categoría / Rango
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                      child: Text(
                        widget.badgeLabel.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: widget.color,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Título de la Medalla
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: GingaColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Descripción del Logro
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        widget.description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: GingaColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botón de Cierre
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.full),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          '¡Increíble! 🥋',
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateConfettiPhysics() {
    const gravity = 0.28;
    const airResistance = 0.98;

    for (final p in _particles) {
      p.vy += gravity;
      p.vx *= airResistance;
      p.vy *= airResistance;
      p.x += p.vx;
      p.y += p.vy;
      p.rotation += p.rotationSpeed;
    }
  }
}

class _ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;
  bool isCircle;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final pos = center + Offset(p.x, p.y);
      // Evitar pintar si está fuera de los límites de la pantalla
      if (pos.dy > size.height || pos.dx < 0 || pos.dx > size.width) continue;

      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotation);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Dibujar un rectángulo largo (cinta)
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.4),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SunburstPainter extends CustomPainter {
  final Color color;
  _SunburstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const rayCount = 12;
    const angleStep = 2 * math.pi / rayCount;

    for (int i = 0; i < rayCount; i++) {
      final startAngle = i * angleStep;
      final sweepAngle = angleStep * 0.45; // Ancho del rayo

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
