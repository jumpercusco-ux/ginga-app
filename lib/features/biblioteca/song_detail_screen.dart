import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Variables para la herramienta de Sincronización del Karaoke
  bool _isSyncMode = false;
  List<Map<String, dynamic>> _syncedLines = [];
  int _currentSyncIndex = 0;
  List<String> _linesToSync = [];
  bool _isSavingSync = false;
  List<dynamic>? _localSincronizada;

  // Variables para el control de Karaoke y autoscroll
  late ScrollController _karaokeScrollController;
  bool _karaokeEnabled = true;
  int _lastActiveIndex = -1;
  bool _isInstructor = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = _parseDuration(widget.cantiga.duracion);
    
    // Inicializar controlador del scroll del karaoke
    _karaokeScrollController = ScrollController();
    
    // Guardar copia local reactiva de la letra sincronizada
    _localSincronizada = widget.cantiga.letraPtSincronizada;

    // Separar la letra original en renglones limpios
    _linesToSync = widget.cantiga.letraPt
        .split('\n')
        .map((linea) => linea.trim())
        .where((linea) => linea.isNotEmpty)
        .toList();

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
    
    // Verificar el rol del usuario para habilitar/deshabilitar controles de Administrador
    _checkUserRole();
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
            
            // Auto-scrolling del Karaoke
            if (_karaokeEnabled && _localSincronizada != null && _localSincronizada!.isNotEmpty) {
              final activeIndex = _getActiveLineIndex();
              if (activeIndex != _lastActiveIndex) {
                _lastActiveIndex = activeIndex;
                _scrollToActiveLine(activeIndex);
              }
            }
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
    _karaokeScrollController.dispose();
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

  void _marcarSiguienteLinea() {
    if (_currentSyncIndex >= _linesToSync.length) return;
    
    final double segundo = double.parse(_currentProgress.toStringAsFixed(2));
    final String texto = _linesToSync[_currentSyncIndex];
    
    setState(() {
      _syncedLines.add({
        'segundo': segundo,
        'texto': texto,
      });
      _currentSyncIndex++;
    });
  }

  void _reiniciarSincronizacion() {
    setState(() {
      _syncedLines = [];
      _currentSyncIndex = 0;
    });
  }

  Future<void> _guardarSincronizacion() async {
    if (_syncedLines.isEmpty) return;
    
    setState(() => _isSavingSync = true);
    
    try {
      // Inyectar o actualizar el campo letraPtSincronizada en el documento de Firestore
      await FirebaseFirestore.instance
          .collection('cantigas')
          .doc(widget.cantiga.id)
          .update({
        'letraPtSincronizada': _syncedLines,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Letra sincronizada y guardada en Firestore! 🎉🎤'),
            backgroundColor: GingaColors.brandGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        setState(() {
          _localSincronizada = List.from(_syncedLines);
          _isSyncMode = false;
          _isSavingSync = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSavingSync = false);
      }
    }
  }

  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          final rol = doc.data()?['rol'] ?? 'alumno';
          setState(() {
            _isInstructor = rol == 'profesor';
          });
        }
      }
    } catch (e) {
      debugPrint("Error al validar rol de usuario: $e");
    }
  }

  int _getActiveLineIndex() {
    if (_localSincronizada == null || _localSincronizada!.isEmpty) return -1;
    int activeIndex = -1;
    for (int i = 0; i < _localSincronizada!.length; i++) {
      final line = _localSincronizada![i];
      final double segundo = (line['segundo'] as num?)?.toDouble() ?? 0.0;
      if (_currentProgress >= segundo) {
        activeIndex = i;
      } else {
        break;
      }
    }
    return activeIndex;
  }

  void _scrollToActiveLine(int index) {
    if (index < 0) return;
    if (_karaokeScrollController.hasClients) {
      const double containerHeight = 280.0;
      const double itemHeight = 48.0;
      final double targetOffset = (index * itemHeight) - (containerHeight / 2) + (itemHeight / 2);
      
      _karaokeScrollController.animateTo(
        targetOffset.clamp(0.0, _karaokeScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: GingaColors.textPrimary),
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
                    icon: Icon(Icons.favorite_border_rounded, color: GingaColors.textPrimary, size: 22),
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
                      widget.cantiga.autor == widget.cantiga.interprete
                          ? 'Mestre/Cantor: ${widget.cantiga.autor} • Ritmo: ${widget.cantiga.ritmo}'
                          : 'Compositor: ${widget.cantiga.autor} • Cantor: ${widget.cantiga.interprete} • Ritmo: ${widget.cantiga.ritmo}',
                      textAlign: TextAlign.center,
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? GingaColors.surfaceDark
                            : GingaColors.borderLight.withOpacity(0.5),
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
                                  color: _showPortuguese
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? GingaColors.backgroundDark
                                          : Colors.white)
                                      : Colors.transparent,
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
                                  color: !_showPortuguese
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? GingaColors.backgroundDark
                                          : Colors.white)
                                      : Colors.transparent,
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

                    // ── Contenedor Dinámico: Karaoke / Sincronización / Letra Estática ──
                    Builder(
                      builder: (context) {
                        // CASO 1: MODO SINCRONIZACIÓN (Admin)
                        if (_isSyncMode) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? GingaColors.surfaceDark
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(GingaRadius.lg),
                              border: Border.all(color: GingaColors.brandGreen.withOpacity(0.5), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: GingaColors.brandGreen.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.sync_rounded, color: GingaColors.brandGreen, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Sincronizador (Admin)',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: GingaColors.brandGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '$_currentSyncIndex / ${_linesToSync.length}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: GingaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 24, color: GingaColors.borderLight),
                                
                                // Línea actual a sincronizar
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: GingaColors.backgroundLight,
                                    borderRadius: BorderRadius.circular(GingaRadius.md),
                                    border: Border.all(color: GingaColors.borderLight),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'LÍNEA ACTUAL A GRABAR:',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: GingaColors.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _currentSyncIndex < _linesToSync.length
                                            ? _linesToSync[_currentSyncIndex]
                                            : '¡Fin de la letra! Pulsa guardar.',
                                        style: GoogleFonts.nunito(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: GingaColors.textPrimary,
                                        ),
                                      ),
                                      if (_currentSyncIndex + 1 < _linesToSync.length) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          'Siguiente línea:',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: GingaColors.textSecondary.withOpacity(0.5),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _linesToSync[_currentSyncIndex + 1],
                                          style: GoogleFonts.nunito(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: GingaColors.textSecondary.withOpacity(0.6),
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Gran botón de tap
                                InkWell(
                                  onTap: _currentSyncIndex < _linesToSync.length ? _marcarSiguienteLinea : null,
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    decoration: BoxDecoration(
                                      color: _currentSyncIndex < _linesToSync.length
                                          ? GingaColors.brandGreen
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(GingaRadius.md),
                                      boxShadow: [
                                        BoxShadow(
                                          color: GingaColors.brandGreen.withOpacity(0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.timer_outlined, color: Colors.white, size: 24),
                                        const SizedBox(width: 10),
                                        Text(
                                          _currentSyncIndex < _linesToSync.length
                                              ? 'MARCAR TIEMPO DE LÍNEA'
                                              : 'COMPLETADO',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Lista de líneas sincronizadas para previsualizar
                                if (_syncedLines.isNotEmpty) ...[
                                  Text(
                                    'Líneas Grabadas:',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: GingaColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: GingaColors.backgroundLight.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(GingaRadius.sm),
                                      border: Border.all(color: GingaColors.borderLight),
                                    ),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _syncedLines.length,
                                      itemBuilder: (ctx, i) {
                                        final line = _syncedLines[i];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: GingaColors.brandGreen.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _formatDuration(line['segundo']),
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: GingaColors.brandGreen,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  line['texto'],
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 11,
                                                    color: GingaColors.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Botones de Control de la sincronización
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _reiniciarSincronizacion,
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('Reiniciar'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _syncedLines.isEmpty || _isSavingSync
                                            ? null
                                            : _guardarSincronizacion,
                                        icon: _isSavingSync
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.cloud_upload_outlined, size: 16),
                                        label: const Text('Guardar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: GingaColors.brandGreen,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => setState(() => _isSyncMode = false),
                                  child: Text(
                                    'Cancelar y Salir',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: GingaColors.textSecondary,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        }

                        // CASO 2: MODO KARAOKE (Sincronizado)
                        final isKaraokeAvailable = _localSincronizada != null && _localSincronizada!.isNotEmpty;
                        final showKaraoke = isKaraokeAvailable && _karaokeEnabled && _showPortuguese;

                        if (showKaraoke) {
                          final activeIdx = _getActiveLineIndex();
                          
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: GingaColors.cardLight.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(GingaRadius.lg),
                              border: Border.all(color: GingaColors.borderLight),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                // Cabecera del Karaoke
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: GingaColors.brandGreen,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'MODO KARAOKE ACTIVO',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: GingaColors.brandGreen,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _karaokeEnabled = false),
                                        child: Text(
                                          'Ver Texto',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: GingaColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(height: 16, color: GingaColors.borderLight),
                                
                                // Lista de Karaoke con Efecto de Fading superior e inferior
                                SizedBox(
                                  height: 280,
                                  child: ShaderMask(
                                    shaderCallback: (rect) {
                                      return const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black,
                                          Colors.black,
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.15, 0.85, 1.0],
                                      ).createShader(rect);
                                    },
                                    blendMode: BlendMode.dstIn,
                                    child: ListView.builder(
                                      controller: _karaokeScrollController,
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                                      itemCount: _localSincronizada!.length,
                                      itemBuilder: (ctx, i) {
                                        final line = _localSincronizada![i];
                                        final lineText = line['texto'] as String? ?? '';
                                        final isActive = i == activeIdx;
                                        final isPast = i < activeIdx;

                                        // Estilos dinámicos según el estado de la línea
                                        final Color textColor;
                                        final double fontSize;
                                        final FontWeight fontWeight;

                                        if (isActive) {
                                          textColor = GingaColors.brandGreen;
                                          fontSize = 17.0;
                                          fontWeight = FontWeight.w800;
                                        } else if (isPast) {
                                          textColor = GingaColors.textPrimary.withOpacity(0.4);
                                          fontSize = 14.0;
                                          fontWeight = FontWeight.w600;
                                        } else {
                                          textColor = GingaColors.textSecondary.withOpacity(0.25);
                                          fontSize = 14.0;
                                          fontWeight = FontWeight.w500;
                                        }

                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          alignment: Alignment.center,
                                          child: Text(
                                            lineText,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.nunito(
                                              fontSize: fontSize,
                                              color: textColor,
                                              fontWeight: fontWeight,
                                              height: 1.4,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // CASO 3: LETRA ESTÁTICA ESTÁNDAR (O traducción, o sin sincronizar)
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: GingaColors.cardLight.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(GingaRadius.lg),
                            border: Border.all(color: GingaColors.borderLight),
                          ),
                          child: Column(
                            children: [
                              // Si está sincronizado en portugués pero estamos viendo español, avisar
                              if (isKaraokeAvailable && !_showPortuguese) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.stars_rounded, color: GingaColors.brandGreen, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Modo Karaoke disponible en Portugués',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: GingaColors.brandGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Si está en portugués pero el karaoke está deshabilitado por el usuario
                              if (isKaraokeAvailable && _showPortuguese && !_karaokeEnabled) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _karaokeEnabled = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: GingaColors.brandGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.play_circle_fill_rounded, color: GingaColors.brandGreen, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Activar Karaoke',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: GingaColors.brandGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Si NO está sincronizado, invitar a sincronizar (CTA de Admin)
                              if (!isKaraokeAvailable && _showPortuguese) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isInstructor ? Colors.amber.shade50 : GingaColors.brandGreen.withOpacity(0.06),
                                    border: Border.all(color: _isInstructor ? Colors.amber.shade200 : GingaColors.brandGreen.withOpacity(0.15)),
                                    borderRadius: BorderRadius.circular(GingaRadius.sm),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _isInstructor ? '🎤 ¿Quieres cantar en modo Karaoke?' : '🎤 El Karaoke no está sincronizado aún',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _isInstructor ? Colors.amber.shade900 : GingaColors.brandGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _isInstructor 
                                            ? 'Usa el Sincronizador de abajo para registrar los tiempos en tiempo real.'
                                            : 'Tu instructor sincronizará esta letra muy pronto en la roda. ¡Sigue entrenando!',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.nunito(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _isInstructor ? Colors.amber.shade900.withOpacity(0.8) : GingaColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              Text(
                                _showPortuguese ? widget.cantiga.letraPt : widget.cantiga.letraEs,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  height: 1.8,
                                  color: GingaColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Botón para Activar Herramienta de Sincronización en la Roda (Admin)
                    if (!_isSyncMode && _isInstructor)
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isSyncMode = true;
                              _reiniciarSincronizacion();
                            });
                          },
                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: GingaColors.brandGreen),
                          label: Text(
                            'Sincronizar Tiempos de Letra (Admin)',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.brandGreen,
                            ),
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

class SongDetailLoader extends StatelessWidget {
  final String songId;
  const SongDetailLoader({super.key, required this.songId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('cantigas').doc(songId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: GingaColors.brandGreen)),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Canción no encontrada')),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final cantiga = Cantiga(
          id: snapshot.data!.id,
          titulo: data['titulo'] ?? '',
          ritmo: data['ritmo'] ?? 'Corrido',
          autor: data['autor'] ?? 'Tradicional',
          interprete: data['interprete'] ?? 'Tradicional',
          duracion: data['duracion'] ?? '2:00',
          contexto: data['contexto'] ?? '',
          letraPt: data['letraPt'] ?? '',
          letraEs: data['letraEs'] ?? '',
          audioUrl: data['audio_url'] ?? '',
          letraPtSincronizada: data['letraPtSincronizada'] as List<dynamic>?,
        );
        return SongDetailScreen(cantiga: cantiga);
      },
    );
  }
}
