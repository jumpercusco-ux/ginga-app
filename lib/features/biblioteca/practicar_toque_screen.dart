import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/ginga_theme.dart';

class PracticarToqueScreen extends StatefulWidget {
  const PracticarToqueScreen({super.key});

  @override
  State<PracticarToqueScreen> createState() => _PracticarToqueScreenState();
}

class _PracticarToqueScreenState extends State<PracticarToqueScreen>
    with TickerProviderStateMixin {
  int _selectedInstrumentIndex = 0; // 0: Berimbau, 1: Pandeiro, 2: Atabaque
  int _selectedToqueIndex = 0;
  bool _isPlaying = false;
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _beatController;
  
  // Secuenciador rítmico fonético
  Timer? _stepTimer;
  int _currentStep = -1;

  // Reproductores de audio de cero latencia pre-cargados
  late AudioPlayer _tchiPlayer;
  late AudioPlayer _dongPlayer;
  late AudioPlayer _tinPlayer;
  bool _isLoadingSounds = true;

  final Map<int, List<_ToqueData>> _toquesPorInstrumento = {
    0: [ // Berimbau
      _ToqueData(
        nombre: 'Angola',
        descripcion: 'Juego bajo, estratégico, lento y tradicional. Exige paciencia y astucia.',
        tag: 'LENTO',
        tagColor: GingaColors.brandGreen,
        bpm: 85,
        silabas: ['Dong', 'Tchi', 'Tchi', 'Dong', 'Tim'],
      ),
      _ToqueData(
        nombre: 'São Bento Pequeno',
        descripcion: 'Juego intermedio, fluido y de transición. Ideal para entrenar combinaciones suaves.',
        tag: 'MEDIO',
        tagColor: GingaColors.accentAmber,
        bpm: 110,
        silabas: ['Dong', 'Tchi', 'Dong', 'Tchi', 'Tim'],
      ),
      _ToqueData(
        nombre: 'São Bento Grande',
        descripcion: 'Juego rápido, enérgico y altamente acrobático. Enfocado en patadas veloces y reflejos.',
        tag: 'RÁPIDO',
        tagColor: GingaColors.brandGreen,
        bpm: 130,
        silabas: ['Tchi', 'Tchi', 'Dong', 'Tchi', 'Tim'],
      ),
      _ToqueData(
        nombre: 'Samba de Roda',
        descripcion: 'Ritmo festivo, alegre y sincopado de clausura. Celebración con canto, palmas y baile.',
        tag: 'ESPECIAL',
        tagColor: GingaColors.accentAmber,
        bpm: 145,
        silabas: ['Tchi', 'Tchi', 'Dong', 'Tin', 'Dong', 'Tin', 'Dong', '•'],
      ),
    ],
    1: [ // Pandeiro
      _ToqueData(
        nombre: 'Toque Básico',
        descripcion: 'Ritmo base del pandeiro en capoeira. Combina golpe de pulgar, yemas y sacudidas de platinelas.',
        tag: 'BÁSICO',
        tagColor: GingaColors.brandGreen,
        bpm: 100,
        silabas: ['Tup', 'Taca', 'Plat', 'Tup', 'Taca', 'Plat'],
      ),
      _ToqueData(
        nombre: 'Toque Dobrado',
        descripcion: 'Variación sincopada avanzada. Dobla los golpes de mano para dar más velocidad al juego de la roda.',
        tag: 'AVANZADO',
        tagColor: GingaColors.accentAmber,
        bpm: 115,
        silabas: ['Tup', 'Tchi', 'Taca', 'Plat', 'Tup', 'Tchi', 'Taca', 'Plat'],
      ),
      _ToqueData(
        nombre: 'Samba de Pandeiro',
        descripcion: 'Compás festivo y rápido tradicionalmente usado para acompañar las palmas al final de la roda.',
        tag: 'FIESTA',
        tagColor: Colors.blue,
        bpm: 125,
        silabas: ['Tup', 'Plat', 'Taca', 'Plat', 'Tup', 'Plat', 'Taca', 'Plat'],
      ),
    ],
    2: [ // Atabaque
      _ToqueData(
        nombre: 'Toque Congo',
        descripcion: 'Ritmo majestuoso, constante y pesado. El latido del atabaque más sagrado en la roda.',
        tag: 'SOLEMNE',
        tagColor: GingaColors.brandGreen,
        bpm: 105,
        silabas: ['Gong', 'Muff', 'Slap', 'Muff', 'Gong', 'Muff', 'Slap', 'Muff'],
      ),
      _ToqueData(
        nombre: 'Barravento',
        descripcion: 'Toque sumamente rápido e inquieto. Caracterizado por slaps agudos e intensos.',
        tag: 'ENÉRGICO',
        tagColor: Colors.red,
        bpm: 130,
        silabas: ['Gong', 'Gong', 'Slap', 'Gong', 'Slap', 'Gong', 'Gong', 'Slap'],
      ),
      _ToqueData(
        nombre: 'Toque Angola',
        descripcion: 'Compás pausado y cadencioso para acompañar al berimbau en la roda tradicional de Angola.',
        tag: 'CADENCIADO',
        tagColor: GingaColors.accentAmber,
        bpm: 85,
        silabas: ['Gong', 'Slap', '•', 'Gong', 'Slap', '•'],
      ),
    ],
  };

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

    _beatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    _initAudio();

    // Iniciar temporizador de 1 segundo para mostrar el modal de "En Construcción"
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _mostrarModalConstruccion();
      }
    });
  }

  void _mostrarModalConstruccion() {
    showDialog(
      context: context,
      barrierDismissible: false, // Bloquear cierre tocando fuera
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false, // Bloquear botón físico de retroceso de Android
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GingaRadius.lg),
            ),
            title: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: GingaColors.accentAmber.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    color: GingaColors.accentAmber,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sección en Construcción 🛠️',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: GingaColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: Text(
              'Esta sección interactiva de Toques de Berimbau se encuentra actualmente bajo desarrollo activo para brindarte la mejor experiencia con sonido y ritmos. ¡Disponible muy pronto!',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                color: GingaColors.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: 180,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      // Volver atrás
                      Navigator.pop(dialogContext);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                    ),
                    child: Text(
                      'Volver Atrás',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _initAudio() async {
    try {
      _tchiPlayer = AudioPlayer();
      _dongPlayer = AudioPlayer();
      _tinPlayer = AudioPlayer();

      // Pre-cargar los sonidos desde assets locales
      await _tchiPlayer.setAsset('assets/sounds/tchi.mp3');
      await _dongPlayer.setAsset('assets/sounds/dong.mp3');
      await _tinPlayer.setAsset('assets/sounds/tim.mp3');

      // Asegurar volumen al máximo
      await _tchiPlayer.setVolume(1.0);
      await _dongPlayer.setVolume(1.0);
      await _tinPlayer.setVolume(1.0);

      if (mounted) {
        setState(() {
          _isLoadingSounds = false;
        });
      }
    } catch (e) {
      debugPrint("Error al pre-cargar audios del simulador: $e");
      // Si falla, permitimos continuar sin sonido para no bloquear la app
      if (mounted) {
        setState(() {
          _isLoadingSounds = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _beatController.dispose();
    _stepTimer?.cancel();
    _tchiPlayer.dispose();
    _dongPlayer.dispose();
    _tinPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_isLoadingSounds) return; // Bloquear interacción si está cargando
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
    final toquesActuales = _toquesPorInstrumento[_selectedInstrumentIndex]!;
    final bpm = toquesActuales[_selectedToqueIndex].bpm;
    // Subdivisiones de corchea para las sílabas: 60000ms / BPM / 2
    final intervalMs = (60000 / bpm / 2 * 2.0).toInt();

    _stepTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (mounted && _isPlaying) {
        final totalSteps = toquesActuales[_selectedToqueIndex].silabas.length;
        final nextStep = (_currentStep + 1) % totalSteps;
        final silaba = toquesActuales[_selectedToqueIndex].silabas[nextStep];

        // Disparar sonido con cero latencia
        if (!_isLoadingSounds) {
          _playSyllableSound(silaba);
        }

        setState(() {
          _currentStep = nextStep;
        });
      }
    });
  }

  void _playSyllableSound(String silaba) {
    if (silaba != '•') {
      _beatController.forward(from: 0.0);
    }

    if (_selectedInstrumentIndex == 0) {
      // Berimbau
      switch (silaba) {
        case 'Tchi':
          _tchiPlayer.seek(Duration.zero);
          _tchiPlayer.play();
          break;
        case 'Dong':
          _dongPlayer.seek(Duration.zero);
          _dongPlayer.play();
          break;
        case 'Tin':
        case 'Tim':
          _tinPlayer.seek(Duration.zero);
          _tinPlayer.play();
          break;
        default:
          break;
      }
    } else if (_selectedInstrumentIndex == 1) {
      // Pandeiro
      switch (silaba) {
        case 'Tup':
          _dongPlayer.seek(Duration.zero);
          _dongPlayer.play();
          break;
        case 'Tchi':
        case 'Taca':
          _tchiPlayer.seek(Duration.zero);
          _tchiPlayer.play();
          break;
        case 'Plat':
          _tinPlayer.seek(Duration.zero);
          _tinPlayer.play();
          break;
        default:
          break;
      }
    } else if (_selectedInstrumentIndex == 2) {
      // Atabaque
      switch (silaba) {
        case 'Gong':
          _dongPlayer.seek(Duration.zero);
          _dongPlayer.play();
          break;
        case 'Slap':
          _tinPlayer.seek(Duration.zero);
          _tinPlayer.play();
          break;
        case 'Muff':
          _tchiPlayer.seek(Duration.zero);
          _tchiPlayer.play();
          break;
        default:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final toquesActuales = _toquesPorInstrumento[_selectedInstrumentIndex]!;
    final selectedToque = toquesActuales[_selectedToqueIndex];

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                    icon: Icon(Icons.arrow_back_ios_new,
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

            // ── Barra Selectora de Instrumentos (¡NUEVO!) ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  _buildInstrumentTab(0, 'Berimbau', Icons.music_note_rounded),
                  const SizedBox(width: 8),
                  _buildInstrumentTab(1, 'Pandeiro', Icons.donut_large_rounded),
                  const SizedBox(width: 8),
                  _buildInstrumentTab(2, 'Atabaque', Icons.layers_rounded),
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
                    _selectedInstrumentIndex == 0
                        ? 'GUÍA RÍTMICA DIGITAL'
                        : (_selectedInstrumentIndex == 1
                            ? 'PULSO Y SÍNCOPA DE RODA'
                            : 'LATIDO Y BASE DE RODA'),
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedInstrumentIndex == 0
                        ? 'Simulador de Berimbau'
                        : (_selectedInstrumentIndex == 1
                            ? 'Simulador de Pandeiro'
                            : 'Simulador de Atabaque'),
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
                          Color buttonColor = _isLoadingSounds
                              ? Colors.grey.shade400
                              : (_isPlaying ? Colors.red.shade600 : GingaColors.brandGreen);
                          
                          return Container(
                            width: 68 + (pulse * 8),
                            height: 68 + (pulse * 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: buttonColor,
                              boxShadow: _isLoadingSounds 
                                  ? [] 
                                  : [
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
                                onTap: _isLoadingSounds ? null : _togglePlay,
                                customBorder: const CircleBorder(),
                                child: _isLoadingSounds
                                    ? const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : Icon(
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
                      _selectedInstrumentIndex == 0
                          ? 'CLAVE DE SONIDOS DEL BERIMBAU:'
                          : (_selectedInstrumentIndex == 1
                              ? 'CLAVE DE SONIDOS DEL PANDEIRO:'
                              : 'CLAVE DE SONIDOS DEL ATABAQUE:'),
                      style: GoogleFonts.montserrat(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: GingaColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedInstrumentIndex == 0) ...[
                      Column(
                        children: [
                          _buildGlosarioItem('Tchi', 'Zumbido sordo', 'Piedra apoyada levemente contra el alambre'),
                          const SizedBox(height: 10),
                          _buildGlosarioItem('Dong', 'Grave / Abierto', 'Alambre libre / calabaza separada del pecho'),
                          const SizedBox(height: 10),
                          _buildGlosarioItem('Tin', 'Agudo / Seco', 'Piedra presionada fuertemente contra el alambre'),
                        ],
                      ),
                    ] else if (_selectedInstrumentIndex == 1) ...[
                      Column(
                        children: [
                          _buildGlosarioItem('Tup', 'Golpe de Pulgar', 'Golpe seco en el parche con el pulgar para marcar graves'),
                          const SizedBox(height: 10),
                          _buildGlosarioItem('Taca', 'Puntas de Dedos', 'Golpe ligero con las yemas en el borde superior del parche'),
                          const SizedBox(height: 10),
                          _buildGlosarioItem('Plat', 'Sacudida Platinelas', 'Movimiento de muñeca para hacer sonar los platillos brillantes'),
                        ],
                      ),
                    ] else ...[
                      Column(
                        children: [
                          _buildGlosarioItem('Gong', 'Golpe Abierto', 'Golpe resonante en el centro del cuero para el latido grave'),
                          const SizedBox(height: 10),
                          _buildGlosarioItem('Slap', 'Golpe Cerrado', 'Slap seco agudo con la mano abierta en el borde del tambor'),
                          const SizedBox(height: 10),
                          _buildGlosarioItem('Muff', 'Toque Ahogado', 'Golpe amortiguado apoyando la mano en el cuero para apagar resonancia'),
                        ],
                      ),
                    ],
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

            const SizedBox(height: 24),

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
                itemCount: toquesActuales.length,
                itemBuilder: (context, index) {
                  return _ToqueCard(
                    toque: toquesActuales[index],
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
    ),
    );
  }

  Widget _buildGlosarioItem(String silaba, String sonido, String tecnica) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: GingaColors.brandGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: GingaColors.brandGreen.withOpacity(0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            silaba,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: GingaColors.brandGreen,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sonido,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: GingaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                tecnica,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: GingaColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstrumentTab(int index, String label, IconData icon) {
    final isSelected = _selectedInstrumentIndex == index;
    Widget tabContent = Column(
      children: [
        Icon(
          icon,
          color: isSelected ? Colors.white : GingaColors.textSecondary,
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : GingaColors.textPrimary,
          ),
        ),
      ],
    );

    if (isSelected && _isPlaying) {
      tabContent = ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.15).animate(
          CurvedAnimation(
            parent: _beatController,
            curve: Curves.decelerate,
          ),
        ),
        child: tabContent,
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedInstrumentIndex = index;
            _selectedToqueIndex = 0; // Reinicia selección al cambiar de instrumento
            _isPlaying = false;
            _currentStep = -1;
            _stepTimer?.cancel();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? GingaColors.brandGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? GingaColors.brandGreen : GingaColors.borderLight,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: GingaColors.brandGreen.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: tabContent,
        ),
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