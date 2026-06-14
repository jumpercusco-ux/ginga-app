import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/tts_service.dart';
import '../../core/models/cuerdas_fiu.dart';
import 'practicar_movimiento_screen.dart'; 
import 'widgets/tutorial_thumbnail.dart';


class TutorialDetailScreen extends StatefulWidget {
  final String title;
  final String category;
  final String level;
  final String description;
  final String tipMestre;
  final String tipError;
  final String imageUrl;
  final String videoUrl;
  final String duracion;
  final String corda;

  const TutorialDetailScreen({
    super.key,
    this.title = 'Passape',
    this.category = 'Ataques',
    this.level = 'Iniciante',
    this.description = 'El passape es un movimiento de ataque circular que utiliza la parte externa del pie. Es fundamental mantener la pierna de apoyo firme y la guardia alta en todo momento.',
    this.tipMestre = 'No quites la vista del oponente durante el giro del pie.',
    this.tipError = 'Inclinar el tronco demasiado hacia atrás te hace perder el equilibrio y la potencia.',
    this.imageUrl = 'assets/images/placeholder_custom.jpg',
    this.videoUrl = '',
    this.duracion = '5 min',
    this.corda = 'Crua',
  });

  @override
  State<TutorialDetailScreen> createState() => _TutorialDetailScreenState();
}

class _TutorialDetailScreenState extends State<TutorialDetailScreen> {
  VideoPlayerController? _videoPlayerController;
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    TtsService.instance.stop(); // Detener narración al salir
    super.dispose();
  }

  Future<void> _inicializarVideo() async {
    final rawUrl = widget.videoUrl;
    // Si no tiene url de video, usamos un mock de capoeira espectacular por defecto para wowear al usuario
    final videoUrlStr = rawUrl.isNotEmpty 
        ? rawUrl 
        : 'https://assets.mixkit.co/videos/preview/mixkit-martial-arts-fighter-performing-kicks-40893-large.mp4';

    setState(() {
      _hasError = false;
    });

    try {
      if (videoUrlStr.startsWith('http')) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrlStr));
      } else if (videoUrlStr.startsWith('assets/')) {
        _videoPlayerController = VideoPlayerController.asset(videoUrlStr);
      } else {
        // Fallback local file or general path
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrlStr));
      }

      await _videoPlayerController!.initialize();
      setState(() {
        _isPlayerInitialized = true;
        _videoPlayerController!.play();
        _isPlaying = true;
      });

      // Escuchar cambios de play/pause
      _videoPlayerController!.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _videoPlayerController!.value.isPlaying;
          });
        }
      });
    } catch (e) {
      debugPrint('Error al inicializar video: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  void _togglePlay() {
    if (_videoPlayerController == null) {
      _inicializarVideo();
      return;
    }

    if (_videoPlayerController!.value.isPlaying) {
      _videoPlayerController!.pause();
    } else {
      _videoPlayerController!.play();
    }
  }

  Widget _buildPlaceholder() {
    return TutorialThumbnail(
      imagenUrl: '',
      categoria: widget.category,
      titulo: widget.title,
      iconSize: 44,
    );
  }

  Widget _buildCordaBadge(String cordaName, CordaFIU cordaItem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: cordaItem.colores.length > 1
                  ? LinearGradient(colors: cordaItem.colores)
                  : null,
              color: cordaItem.colores.length == 1 ? cordaItem.colores.first : Colors.grey,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'CUERDA: ${cordaName.toUpperCase()}',
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: GingaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Suscribir al tema para regenerar la pantalla al alternar claro/oscuro
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid != null
          ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
          : null,
      builder: (context, userSnapshot) {
        String userCordaName = 'Crua';
        String userRol = 'alumno';

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>;
          userCordaName = data['corda'] ?? 'Crua';
          userRol = data['rol'] ?? 'alumno';
        }

        final userCorda = CuerdasFIU.encontrarCordaFIU(userCordaName) ?? CuerdasFIU.lista.first;
        final tutorialCorda = CuerdasFIU.encontrarCordaFIU(widget.corda) ?? CuerdasFIU.lista.first;

        final bool isLocked = (userRol != 'instructor' && userRol != 'admin') &&
            (tutorialCorda.index > userCorda.index);

        if (isLocked) {
          // Si está bloqueado por resguardo, mostramos la pantalla negra con candado motivacional
          return Scaffold(
            backgroundColor: Colors.black87,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.orange,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Acceso Restringido',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Este tutorial está restringido para alumnos de graduación Cuerda ${tutorialCorda.nombre} o superior.',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 12,
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: tutorialCorda.colores.length > 1
                            ? LinearGradient(colors: tutorialCorda.colores)
                            : null,
                        color: tutorialCorda.colores.length == 1
                            ? tutorialCorda.colores.first
                            : Colors.grey,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.brandGreen,
                        minimumSize: const Size(200, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Volver a la Biblioteca',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: GingaColors.backgroundLight,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: CustomScrollView(
                slivers: [
              // ── Header con Video/Imagen ────────────────
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: GingaColors.textPrimary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Mostrar VideoPlayer si está inicializado y no hay error
                      if (_isPlayerInitialized && _videoPlayerController != null && !_hasError)
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _videoPlayerController!.value.aspectRatio,
                              child: VideoPlayer(_videoPlayerController!),
                            ),
                          ),
                        )
                      else
                        // 2. Mostrar la miniatura (usa la imagen si existe, o gradiente dinámico si no)
                        TutorialThumbnail(
                          imagenUrl: widget.imageUrl,
                          categoria: widget.category,
                          titulo: widget.title,
                          iconSize: 44,
                          showPlayIcon: false,
                        ),

                      // Overlay gradiente para legibilidad
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),

                      // Cargador del video
                      if (_videoPlayerController != null && !_isPlayerInitialized && !_hasError)
                        const Center(
                          child: CircularProgressIndicator(color: GingaColors.brandGreen),
                        ),

                      // Botón Play
                      if (!_isPlaying && !_hasError)
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: GingaColors.brandGreen.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
                            ),
                          ),
                        ),

                      // Mensaje de Error
                      if (_hasError)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'Error al reproducir el video',
                                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                      // Controles flotantes inferiores si el video se está reproduciendo
                      if (_isPlayerInitialized && _videoPlayerController != null)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: _togglePlay,
                              ),
                              Expanded(
                                child: VideoProgressIndicator(
                                  _videoPlayerController!,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                    playedColor: GingaColors.brandGreen,
                                    bufferedColor: Colors.white24,
                                    backgroundColor: Colors.white12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Contenido de la Lección ──────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildBadge(widget.category, GingaColors.brandGreen),
                          const SizedBox(width: 8),
                          _buildBadge(widget.level, GingaColors.accentAmber),
                          const SizedBox(width: 8),
                          _buildCordaBadge(widget.corda, tutorialCorda),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Instrucción por Mestre Enrique',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: GingaColors.brandGreen,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        'Descripción Técnica',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.description,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          height: 1.6,
                          color: GingaColors.textSecondary,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      _buildTipBox(
                        'Consejo del Mestre',
                        widget.tipMestre,
                        Icons.tips_and_updates_outlined,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTipBox(
                        'Error Común',
                        widget.tipError,
                        Icons.warning_amber_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
          ),
          
          // ── Botón Flotante para Practicar ──────────────
          bottomNavigationBar: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? GingaColors.backgroundDark : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.black38 : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              16 + (MediaQuery.of(context).padding.bottom > 12.0 
                  ? MediaQuery.of(context).padding.bottom 
                  : 12.0),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PracticarMovimientoScreen(
                      titulo: widget.title,
                      duracion: widget.duracion,
                      categoria: widget.category,
                      videoUrl: widget.videoUrl,
                      imageUrl: widget.imageUrl,
                    ),
                  ),
                );
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
                '¡ESTOY LISTO, PRACTICAR!',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTipBox(String title, String desc, IconData icon) {
    final isSpeakingText = TtsService.instance.isSpeaking(desc);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(
          color: isSpeakingText 
              ? GingaColors.brandGreen.withOpacity(0.4) 
              : borderColor,
          width: isSpeakingText ? 1.5 : 1,
        ),
        boxShadow: isSpeakingText ? [
          BoxShadow(
            color: GingaColors.brandGreen.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ] : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon, 
            color: isSpeakingText ? GingaColors.brandGreen : GingaColors.textSecondary, 
            size: 22
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          TtsService.instance.speak(desc);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSpeakingText 
                              ? GingaColors.brandGreen.withOpacity(0.12) 
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSpeakingText 
                              ? Icons.volume_up_rounded 
                              : Icons.volume_mute_rounded,
                          color: GingaColors.brandGreen,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: GingaColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialDetailLoader extends StatelessWidget {
  final String tutorialId;
  const TutorialDetailLoader({super.key, required this.tutorialId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('tutoriales').doc(tutorialId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: GingaColors.brandGreen)),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Tutorial no encontrado')),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return TutorialDetailScreen(
          title: data['titulo'] ?? '',
          category: data['categoria'] ?? 'Ataques',
          level: data['nivel'] ?? 'Iniciante',
          description: data['descripcion'] ?? '',
          tipMestre: data['tipMestre'] ?? '',
          tipError: data['tipError'] ?? '',
          imageUrl: data['imagen_url'] ?? '',
          videoUrl: data['video_url'] ?? '',
          duracion: data['duracion'] ?? '5 min',
          corda: data['corda'] ?? 'Crua',
        );
      },
    );
  }
}