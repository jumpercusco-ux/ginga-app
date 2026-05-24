import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/ginga_theme.dart';
import 'practicar_toque_screen.dart'; 
import 'practicar_movimiento_screen.dart'; 

class TutorialDetailScreen extends StatefulWidget {
  final String title;
  final String category;
  final String level;
  final String description;
  final String tipMestre;
  final String tipError;
  final String imageUrl;
  final String videoUrl;

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
    return Container(
      color: GingaColors.brandGreen,
      child: const Icon(
        Icons.play_circle_outline,
        color: Colors.white,
        size: 64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: CustomScrollView(
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
                    // 2. Mostrar la miniatura por defecto si no se ha reproducido el video
                    (widget.imageUrl.startsWith('assets/')
                        ? Image.asset(
                            widget.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                          )
                        : Image.network(
                            widget.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                          )),

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
      
      // ── Botón Flotante para Practicar ──────────────
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GingaColors.brandGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: GingaColors.textSecondary,
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