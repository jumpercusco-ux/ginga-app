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
  bool _isPlaying = false;
  late AnimationController _waveController;
  late AnimationController _pulseController;
  
  // Secuenciador rítmico fonético
  Timer? _stepTimer;
  int _currentStep = -1;

  final List<_ToqueData> _toques = [
    _ToqueData(
      nombre: 'Angola',
      descripcion: 'Juego bajo, estratégico, lento y tradicional. Exige paciencia y astucia.',
      tag: 'LENTO',
      tagColor: GingaColors.brandGreen,
      bpm: 85,
      silabas: ['Tchi', 'Tchi', 'Dong', '•', 'Tchi', 'Tchi', 'Tin', '•'],
    ),
    _ToqueData(
      nombre: 'São Bento Pequeno',
      descripcion: 'Juego intermedio, fluido y de transición. Ideal para entrenar combinaciones suaves.',
      tag: 'MEDIO',
      tagColor: GingaColors.accentAmber,
      bpm: 110,
      silabas: ['Tchi', 'Tchi', 'Tin', '•', 'Tchi', 'Tchi', 'Dong', '•'],
    ),
    _ToqueData(
      nombre: 'São Bento Grande',
      descripcion: 'Juego rápido, enérgico y altamente acrobático. Enfocado en patadas veloces y reflejos.',
      tag: 'RÁPIDO',
      tagColor: GingaColors.brandGreen,
      bpm: 130,
      silabas: ['Tchi', 'Tchi', 'Dong', '•', 'Tin', '•', 'Tin', '•'],
    ),
    _ToqueData(
      nombre: 'Samba de Roda',
      descripcion: 'Ritmo festivo, alegre y sincopado de clausura. Celebración con canto, palmas y baile.',
      tag: 'ESPECIAL',
      tagColor: GingaColors.accentAmber,
      bpm: 145,
      silabas: ['Tchi', 'Tchi', 'Dong', 'Tin', 'Dong', 'Tin', 'Dong', '•'],
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
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (!_isPlaying) {
        _currentStep = -1;
        _stepTimer?.cancel();
      } else {
        _currentStep = 0;
        _startSequencer();
      }
    });
  }

  void _startSequencer() {
    _stepTimer?.cancel();
    final bpm = _toques[_selectedToqueIndex].bpm;
    // Subdivisiones de corchea para las sílabas: 60000ms / BPM / 2
    final intervalMs = (60000 / bpm / 2).toInt();

    _stepTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (mounted && _isPlaying) {
        setState(() {
          final totalSteps = _toques[_selectedToqueIndex].silabas.length;
          _currentStep = (_currentStep + 1) % totalSteps;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedToque = _toques[_selectedToqueIndex];

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
                      'Biblioteca de Toques',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selectedToque.tagColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedToque.bpm} BPM',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: selectedToque.tagColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Reproductor y Análisis de Ritmo ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GUÍA RÍTMICA DIGITAL',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Simulador de Berimbau',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Visualizador de ondas con Botón Play/Pause central
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: GingaColors.cardLight,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(
                            color: _isPlaying 
                                ? selectedToque.tagColor.withOpacity(0.2) 
                                : Colors.transparent,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: _BarVisualizer(
                          controller: _waveController,
                          isActive: _isPlaying,
                          bpm: selectedToque.bpm,
                        ),
                      ),

                      // Botón circular Play/Pause Flotante
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          double pulse = _isPlaying ? _pulseController.value : 0.0;
                          return Container(
                            width: 68 + (pulse * 8),
                            height: 68 + (pulse * 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isPlaying ? Colors.red.shade600 : GingaColors.brandGreen,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isPlaying ? Colors.red : GingaColors.brandGreen).withOpacity(0.3),
                                  blurRadius: 15 + (pulse * 8),
                                  spreadRadius: 2 + (pulse * 3),
                                )
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _togglePlay,
                                customBorder: const CircleBorder(),
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Secuenciador Fonético Activo (Real-time timeline) ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SECUENCIA FONÉTICA DEL TOQUE',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      if (_isPlaying)
                        Text(
                          'REPRODUCIENDO...',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: GingaColors.brandGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Caja contenedora de las sílabas
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      border: Border.all(color: GingaColors.borderLight),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(selectedToque.silabas.length, (index) {
                          final silaba = selectedToque.silabas[index];
                          final isCurrent = _currentStep == index;
                          final isPause = silaba == '•';

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? GingaColors.brandGreen
                                  : (isPause ? Colors.grey.shade50 : GingaColors.cardLight),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent
                                    ? GingaColors.brandGreen
                                    : (isPause ? Colors.grey.shade200 : GingaColors.borderLight),
                                width: isCurrent ? 1.5 : 1,
                              ),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: GingaColors.brandGreen.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Text(
                              silaba,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isCurrent
                                    ? Colors.white
                                    : (isPause ? Colors.grey.shade400 : GingaColors.textPrimary),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Métodos de Sonido / Glosario Didáctico ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GingaColors.cardLight.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  border: Border.all(color: GingaColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLAVE DE SONIDOS DEL BERIMBAU:',
                      style: GoogleFonts.montserrat(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: GingaColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildGlosarioItem('Tchi', 'Zumbido sordo', 'Piedra apoyada levemente'),
                        _buildGlosarioItem('Dong', 'Grave / Abierto', 'Alambre libre / Calabaza separada'),
                        _buildGlosarioItem('Tin', 'Agudo / Seco', 'Piedra presionada fuerte'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Info de toque seleccionado ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  border: Border.all(color: selectedToque.tagColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: selectedToque.tagColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedToque.descripcion,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: GingaColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // ── Listado de Ritmos ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Selecciona un Toque para Escuchar',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: GingaColors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 10),

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
                    onTap: () {
                      setState(() {
                        _selectedToqueIndex = index;
                        if (_isPlaying) {
                          _startSequencer(); // Adapta la velocidad en vivo
                        }
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGlosarioItem(String silaba, String sonido, String tecnica) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  silaba,
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: GingaColors.brandGreen,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  sonido,
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tecnica,
            style: GoogleFonts.nunito(
              fontSize: 8,
              color: GingaColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  VISUALIZADOR DE ONDAS RÍTMICAS (ECUALIZADOR)
// ─────────────────────────────────────────

class _BarVisualizer extends StatelessWidget {
  final AnimationController controller;
  final bool isActive;
  final int bpm;

  const _BarVisualizer({
    required this.controller,
    required this.isActive,
    required this.bpm,
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
            bpm: bpm,
          ),
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  final double progress;
  final bool isActive;
  final int bpm;

  _BarPainter({
    required this.progress,
    required this.isActive,
    required this.bpm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int barCount = 38;
    final double spacing = 3.5;
    final double barWidth = (size.width - (barCount - 1) * spacing) / barCount;
    
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Aceleración de la onda según el BPM del toque seleccionado
    double bpmSpeedFactor = bpm / 85.0; // Normalizado respecto a Angola
    double calculatedProgress = (progress * bpmSpeedFactor) % 1.0;

    for (int i = 0; i < barCount; i++) {
      // Cálculo de la altura base mediante función seno reactiva
      double baseHeight = math.sin((i / barCount * 2.5 * math.pi) + (calculatedProgress * 2 * math.pi)).abs();
      
      double energy = isActive 
          ? (0.4 + math.Random().nextDouble() * 0.6) 
          : 0.15;
      
      double barHeight = (size.height * 0.85) * baseHeight * energy;
      
      if (!isActive && barHeight < 8) barHeight = 8;
      if (isActive && barHeight < 16) barHeight = 16 + math.Random().nextDouble() * 10;

      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (barWidth + spacing),
          size.height / 2 - barHeight / 2,
          barWidth,
          barHeight,
        ),
        const Radius.circular(12),
      );

      Color topColor = isActive 
          ? Color.lerp(GingaColors.brandGreen, GingaColors.accentAmber, (i / barCount))!
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
        duration: const Duration(milliseconds: 300),
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 8),
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? GingaColors.brandGreen : GingaColors.cardLight,
                    borderRadius: BorderRadius.circular(GingaRadius.sm),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: isSelected ? Colors.white : GingaColors.textSecondary,
                    size: 18,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: GingaColors.brandGreen, size: 16),
              ],
            ),
            const SizedBox(height: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: toque.tagColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                toque.tag,
                style: GoogleFonts.montserrat(
                  fontSize: 7.5,
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
  final int bpm;
  final List<String> silabas;

  _ToqueData({
    required this.nombre,
    required this.descripcion,
    required this.tag,
    required this.tagColor,
    required this.bpm,
    required this.silabas,
  });
}