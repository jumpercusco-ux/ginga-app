import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../core/theme/ginga_theme.dart';

class PracticarToqueScreen extends StatefulWidget {
  const PracticarToqueScreen({super.key});

  @override
  State<PracticarToqueScreen> createState() => _PracticarToqueScreenState();
}

class _PracticarToqueScreenState extends State<PracticarToqueScreen>
    with TickerProviderStateMixin {
  int _selectedToqueIndex = 0;
  bool _isListening = false;
  late AnimationController _waveController;
  late AnimationController _pulseController;

  final List<_ToqueData> _toques = [
    _ToqueData(
      nombre: 'Angola',
      descripcion: 'Tradición y paciencia',
      tag: 'LENTO',
      tagColor: GingaColors.brandGreen,
    ),
    _ToqueData(
      nombre: 'São Bento Grande',
      descripcion: 'Rápido y fuerte',
      tag: 'RÁPIDO',
      tagColor: GingaColors.accentAmber,
    ),
    _ToqueData(
      nombre: 'Banguela',
      descripcion: 'Suave y fluido',
      tag: 'MEDIO',
      tagColor: GingaColors.brandGreen,
    ),
    _ToqueData(
      nombre: 'Iuna',
      descripcion: 'Para Mestres',
      tag: 'ESPECIAL',
      tagColor: GingaColors.accentAmber,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: GingaColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Practicar Toque',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_outlined,
                        color: GingaColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),

            // ── Visualizador de ritmo ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'FRECUENCIA DE RITMO',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: GingaColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isListening)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-time Visualizer',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Visualizador de ondas
                  Container(
                    decoration: BoxDecoration(
                      color: GingaColors.cardLight,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _WaveVisualizer(
                      controller: _waveController,
                      isActive: _isListening,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Seleccionar Ritmo ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seleccionar Ritmo',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Ver Todos',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: GingaColors.brandGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Lista de toques
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _toques.length,
                itemBuilder: (context, index) {
                  return _ToqueCard(
                    toque: _toques[index],
                    isSelected: _selectedToqueIndex == index,
                    onTap: () =>
                        setState(() => _selectedToqueIndex = index),
                  );
                },
              ),
            ),

            const Spacer(),

            // ── Botón LISTEN ────────────────────────
            Center(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 80 +
                            (_isListening
                                ? _pulseController.value * 10
                                : 0),
                        height: 80 +
                            (_isListening
                                ? _pulseController.value * 10
                                : 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GingaColors.brandGreen,
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: GingaColors.brandGreen
                                        .withOpacity(0.35),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  )
                                ]
                              : [],
                        ),
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _isListening = !_isListening),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isListening ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 32,
                              ),
                              Text(
                                _isListening ? 'STOP' : 'LISTEN',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _isListening
                          ? 'Toca tu berimbau próximo al micrófono para recibir feedback en tiempo real.'
                          : 'Toca el berimbau para que Ginga identifique el ritmo automáticamente.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: GingaColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  WAVE VISUALIZER
// ─────────────────────────────────────────

class _WaveVisualizer extends StatelessWidget {
  final AnimationController controller;
  final bool isActive;

  const _WaveVisualizer({
    required this.controller,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 80),
          painter: _WavePainter(
            progress: controller.value,
            isActive: isActive,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final bool isActive;

  _WavePainter({required this.progress, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? GingaColors.brandGreen : GingaColors.borderLight
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final waveHeight = isActive ? 20.0 : 8.0;

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          waveHeight *
              math.sin((x / size.width * 4 * math.pi) +
                  (progress * 2 * math.pi));
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Segunda onda
    final path2 = Path();
    final paint2 = Paint()
      ..color = (isActive ? GingaColors.brandGreen : GingaColors.borderLight)
          .withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          (waveHeight * 0.6) *
              math.sin((x / size.width * 3 * math.pi) +
                  (progress * 2 * math.pi) + 1);
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.isActive != isActive;
}

// ─────────────────────────────────────────
//  TOQUE CARD
// ─────────────────────────────────────────

class _ToqueCard extends StatelessWidget {
  final _ToqueData toque;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToqueCard({
    required this.toque,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? GingaColors.cardLight : Colors.white,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(
            color: isSelected
                ? GingaColors.brandGreen
                : GingaColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? GingaColors.brandGreen.withOpacity(0.12)
                    : GingaColors.cardLight,
                borderRadius: BorderRadius.circular(GingaRadius.sm),
              ),
              child: Icon(
                Icons.music_note,
                color: isSelected
                    ? GingaColors.brandGreen
                    : GingaColors.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              toque.nombre,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: GingaColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: toque.tagColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                toque.tag,
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: toque.tagColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  MODELO
// ─────────────────────────────────────────

class _ToqueData {
  final String nombre;
  final String descripcion;
  final String tag;
  final Color tagColor;

  _ToqueData({
    required this.nombre,
    required this.descripcion,
    required this.tag,
    required this.tagColor,
  });
}