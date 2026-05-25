import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
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
  
  // Lógica de simulación IA avanzada para el demo
  int _currentBpm = 112;
  double _syncAccuracy = 0.0;
  Timer? _analysisTimer;
  Timer? _detectionTimer;

  final List<_ToqueData> _toques = [
    _ToqueData(
      nombre: 'Angola',
      descripcion: 'Juego bajo, estratégico, lento y tradicional. Exige paciencia y astucia.',
      tag: 'LENTO',
      tagColor: GingaColors.brandGreen,
    ),
    _ToqueData(
      nombre: 'São Bento Pequeno',
      descripcion: 'Juego intermedio, fluido y de transición. Ideal para entrenar combinaciones suaves.',
      tag: 'MEDIO',
      tagColor: GingaColors.accentAmber,
    ),
    _ToqueData(
      nombre: 'São Bento Grande',
      descripcion: 'Juego rápido, enérgico y altamente acrobático. Enfocado en patadas veloces y reflejos.',
      tag: 'RÁPIDO',
      tagColor: GingaColors.brandGreen,
    ),
    _ToqueData(
      nombre: 'Samba de Roda',
      descripcion: 'Ritmo festivo, alegre y sincopado de clausura. Celebración con canto, palmas y baile.',
      tag: 'ESPECIAL',
      tagColor: GingaColors.accentAmber,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    _analysisTimer?.cancel();
    _detectionTimer?.cancel();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (!_isListening) {
        _syncAccuracy = 0.0;
        _currentBpm = 112;
      }
    });

    if (_isListening) {
      // 1. Simular análisis de micro-ritmos en tiempo real
      _analysisTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
        if (mounted) {
          setState(() {
            _currentBpm = 110 + math.Random().nextInt(8);
            // Simulación de mejora de precisión orgánica
            if (_syncAccuracy < 0.92) {
              _syncAccuracy += 0.05 + (math.Random().nextDouble() * 0.1);
            } else {
              _syncAccuracy = 0.92 + (math.Random().nextDouble() * 0.05);
            }
          });
        }
      });

      // 2. Simular detección exitosa tras unos segundos
      _detectionTimer = Timer(const Duration(milliseconds: 4000), () {
        if (mounted && _isListening) {
          final selectedToque = _toques[_selectedToqueIndex];
          setState(() {
            _syncAccuracy = 0.98; // Bloqueo de ritmo exitoso
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎯 ¡Ritmo Sincronizado: ${selectedToque.nombre}!'),
              backgroundColor: GingaColors.brandGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } else {
      _analysisTimer?.cancel();
      _detectionTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Barra Superior (AppBar) ──────────────────────────────
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

            // ── Visualizador de ritmo por IA ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ANÁLISIS ESPECTRAL',
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
                      const Spacer(),
                      if (_isListening)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: GingaColors.brandGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SYNC: ${(_syncAccuracy * 100).toInt()}%',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: GingaColors.brandGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'IA Visualizer',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      if (_isListening)
                        Text(
                          '$_currentBpm BPM',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textPrimary.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Visualizador de barras de frecuencia
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: GingaColors.cardLight,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      border: Border.all(
                        color: _isListening 
                          ? GingaColors.brandGreen.withOpacity(0.2) 
                          : Colors.transparent,
                      )
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: _BarVisualizer(
                      controller: _waveController,
                      isActive: _isListening,
                      accuracy: _syncAccuracy,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Sección de Ritmos ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Identificación de Toque',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Historial',
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

            // 🟢 JUMPER FIX: Altura aumentada de 110 a 125 para evitar overflow
            SizedBox(
              height: 125,
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

            const SizedBox(height: 16),

            // Tarjeta de Descripción del Toque Seleccionado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GingaColors.cardLight,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: GingaColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _toques[_selectedToqueIndex].tagColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: _toques[_selectedToqueIndex].tagColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOBRE EL RITMO: ${_toques[_selectedToqueIndex].nombre.toUpperCase()}',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _toques[_selectedToqueIndex].tagColor,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _toques[_selectedToqueIndex].descripcion,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: GingaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // ── Botón de Control (Escuchar) ────────────────────────
            Center(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double pulseValue = _isListening ? _pulseController.value : 0;
                      return Container(
                        width: 85 + (pulseValue * 12),
                        height: 85 + (pulseValue * 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? Colors.red.shade600 : GingaColors.brandGreen,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? Colors.red : GingaColors.brandGreen).withOpacity(0.3),
                              blurRadius: 20 + (pulseValue * 10),
                              spreadRadius: 2 + (pulseValue * 5),
                            )
                          ],
                        ),
                        child: GestureDetector(
                          onTap: _toggleListening,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isListening ? 'Parar' : 'Tocar',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 50),
                    child: Text(
                      _isListening
                          ? 'Mantén la cadencia. La IA está analizando tu golpe de arame...'
                          : 'Toca el berimbau para que la IA califique tu técnica y ritmo.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: GingaColors.textSecondary.withOpacity(0.8),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  VISUALIZADOR DE BARRAS (ECUALIZADOR CON SYNC)
// ─────────────────────────────────────────

class _BarVisualizer extends StatelessWidget {
  final AnimationController controller;
  final bool isActive;
  final double accuracy;

  const _BarVisualizer({
    required this.controller,
    required this.isActive,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _BarPainter(
            progress: controller.value,
            isActive: isActive,
            accuracy: accuracy,
          ),
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  final double progress;
  final bool isActive;
  final double accuracy;

  _BarPainter({
    required this.progress,
    required this.isActive,
    required this.accuracy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int barCount = 38;
    final double spacing = 3.5;
    final double barWidth = (size.width - (barCount - 1) * spacing) / barCount;
    
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      // Cálculo de la altura base mediante función seno
      double baseHeight = math.sin((i / barCount * 2.5 * math.pi) + (progress * 2 * math.pi)).abs();
      
      // Multiplicador de energía reactiva
      double energy = isActive 
          ? (0.4 + math.Random().nextDouble() * 0.6) 
          : 0.15;
      
      double barHeight = (size.height * 0.85) * baseHeight * energy;
      
      // Ajustes visuales de suavizado
      if (!isActive && barHeight < 12) barHeight = 12;
      if (isActive && barHeight < 18) barHeight = 18 + math.Random().nextDouble() * 10;

      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (barWidth + spacing),
          size.height / 2 - barHeight / 2,
          barWidth,
          barHeight,
        ),
        const Radius.circular(12),
      );

      // Color dinámico interpolado según precisión (SYNC)
      Color topColor = isActive 
          ? Color.lerp(GingaColors.textSecondary.withOpacity(0.5), GingaColors.brandGreen, accuracy)!
          : GingaColors.borderLight;
      
      Color bottomColor = topColor.withOpacity(0.4);

      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => true;
}

// ─────────────────────────────────────────
//  TARJETA DE TOQUE (DATO DEL MODELO)
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
        duration: const Duration(milliseconds: 400),
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        // 🟢 JUMPER FIX: Padding reducido de 16 a 12 para ganar espacio vertical
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? GingaColors.brandGreen.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(
            color: isSelected ? GingaColors.brandGreen : GingaColors.borderLight,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: GingaColors.brandGreen.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected ? GingaColors.brandGreen : GingaColors.cardLight,
                    borderRadius: BorderRadius.circular(GingaRadius.sm),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: isSelected ? Colors.white : GingaColors.textSecondary,
                    size: 20,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.verified, color: GingaColors.brandGreen, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              toque.nombre,
              style: GoogleFonts.montserrat(
                fontSize: 12, // Reducido un punto para seguridad
                fontWeight: FontWeight.w700,
                color: GingaColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: toque.tagColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                toque.tag,
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: toque.tagColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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