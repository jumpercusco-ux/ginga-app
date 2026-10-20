import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../theme/ginga_theme.dart';
import 'web_embed_view/web_embed_view.dart';

const Color _kBordeOscuro = Color(0xFF2C2C2C);
const Color _kTextoSecundario = Color(0xFFA0A0A0);

/// Determina si una URL corresponde a un archivo de video directo (MP4, WebM, etc.)
bool esVideoDirecto(String url) {
  final clean = url.trim().toLowerCase();
  return clean.endsWith('.mp4') ||
      clean.endsWith('.webm') ||
      clean.endsWith('.mov') ||
      clean.contains('.mp4?') ||
      clean.contains('.webm?') ||
      clean.contains('firebasestorage.googleapis.com');
}

/// Extrae la URL de Embed para YouTube, TikTok o Instagram
String? obtenerEmbedUrl(String rawUrl) {
  final clean = rawUrl.trim();

  // 1. YouTube
  final ytMatch = RegExp(
          r'(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|shorts\/|embed\/))([a-zA-Z0-9_-]{11})')
      .firstMatch(clean);
  if (ytMatch != null) {
    return 'https://www.youtube-nocookie.com/embed/${ytMatch.group(1)}?autoplay=1&rel=0';
  }

  // 2. TikTok
  final ttMatch = RegExp(r'\/video\/(\d+)').firstMatch(clean);
  if (ttMatch != null) {
    return 'https://www.tiktok.com/embed/v2/${ttMatch.group(1)}';
  }

  // 3. Instagram Reels / Posts
  final igMatch = RegExp(r'\/(?:reel|p)\/([a-zA-Z0-9_-]+)').firstMatch(clean);
  if (igMatch != null) {
    return 'https://www.instagram.com/p/${igMatch.group(1)}/embed/';
  }

  return null;
}

IconData detectarIconoLink(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('instagram.com')) return Icons.camera_alt_outlined;
  if (lower.contains('tiktok.com')) return Icons.music_note_outlined;
  if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
    return Icons.play_arrow_rounded;
  }
  return Icons.play_circle_fill_rounded;
}

String detectarNombrePlataforma(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('instagram.com')) return 'Instagram Reel';
  if (lower.contains('tiktok.com')) return 'TikTok Video';
  if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
    return 'YouTube';
  }
  return 'Video';
}

/// Abre el modal de reproducción de video dentro de Ginga
Future<void> mostrarVideoPlayerInApp(
  BuildContext context, {
  required String url,
  required String titulo,
  String? tipo,
}) async {
  HapticFeedback.lightImpact();

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (ctx) => _VideoPlayerInAppModal(
      url: url,
      titulo: titulo,
      tipo: tipo,
    ),
  );
}

class _VideoPlayerInAppModal extends StatefulWidget {
  final String url;
  final String titulo;
  final String? tipo;

  const _VideoPlayerInAppModal({
    required this.url,
    required this.titulo,
    this.tipo,
  });

  @override
  State<_VideoPlayerInAppModal> createState() => _VideoPlayerInAppModalState();
}

class _VideoPlayerInAppModalState extends State<_VideoPlayerInAppModal> {
  VideoPlayerController? _videoCtrl;
  bool _isDirectVideo = false;
  String? _embedUrl;
  bool _isLoadingDirectVideo = false;

  @override
  void initState() {
    super.initState();
    _isDirectVideo = esVideoDirecto(widget.url) || widget.tipo == 'video';
    _embedUrl = obtenerEmbedUrl(widget.url);

    if (_isDirectVideo) {
      _inicializarVideoDirecto();
    }
  }

  Future<void> _inicializarVideoDirecto() async {
    setState(() => _isLoadingDirectVideo = true);
    try {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoCtrl!.initialize();
      _videoCtrl!.setLooping(true);
      _videoCtrl!.play();
      if (mounted) {
        setState(() => _isLoadingDirectVideo = false);
      }
    } catch (e) {
      debugPrint('Error inicializando VideoPlayer directo: $e');
      if (mounted) {
        setState(() => _isLoadingDirectVideo = false);
      }
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _abrirEnAppExterna() async {
    var clean = widget.url.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    try {
      await launchUrl(
        Uri.parse(clean),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el enlace: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTikTokOrReel = widget.url.toLowerCase().contains('tiktok.com') ||
        widget.url.toLowerCase().contains('instagram.com');

    // Dimensiones óptimas: vertical (9:16) para TikTok/Reels, o panorámico para YouTube
    final double maxModalWidth = isTikTokOrReel ? 390.0 : 680.0;
    final double modalWidth = size.width > maxModalWidth ? maxModalWidth : size.width * 0.94;
    final double modalHeight = size.height * 0.84;

    final iconoPlat = detectarIconoLink(widget.url);
    final nombrePlat = detectarNombrePlataforma(widget.url);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: modalWidth,
          height: modalHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(GingaRadius.xl),
            border: Border.all(color: _kBordeOscuro, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Header Superior del Visor ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
                  border: Border(bottom: BorderSide(color: _kBordeOscuro)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: GingaColors.accentAmber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconoPlat, size: 16, color: GingaColors.accentAmber),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.titulo,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$nombrePlat • Reproduciendo dentro de Ginga',
                            style: GoogleFonts.montserrat(
                              fontSize: 10.5,
                              color: _kTextoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón secundario para abrir en la app oficial si el usuario lo desea
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18, color: _kTextoSecundario),
                      onPressed: _abrirEnAppExterna,
                      tooltip: 'Abrir en $nombrePlat',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),

                    // Botón Cerrar (✕)
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Cuerpo del Reproductor ──
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(GingaRadius.xl)),
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    height: double.infinity,
                    child: _buildPlayerContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    // 1. Video directo (MP4 / Firebase Storage)
    if (_isDirectVideo) {
      if (_isLoadingDirectVideo) {
        return const Center(
          child: CircularProgressIndicator(color: GingaColors.brandGreen),
        );
      }
      if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoCtrl!.value.aspectRatio,
              child: VideoPlayer(_videoCtrl!),
            ),
            // Controles de Play/Pausa
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _videoCtrl!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoCtrl!.value.isPlaying
                              ? _videoCtrl!.pause()
                              : _videoCtrl!.play();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      // Error o no inicializado
      return _buildFallbackView();
    }

    // 2. Iframe Embed (TikTok, YouTube, Instagram)
    if (_embedUrl != null && _embedUrl!.isNotEmpty) {
      return PlatformEmbedViewWidget(embedUrl: _embedUrl!);
    }

    // 3. Fallback en caso de que no tenga embed reconocido
    return _buildFallbackView();
  }

  Widget _buildFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_display_outlined, size: 54, color: GingaColors.accentAmber),
            const SizedBox(height: 14),
            Text(
              'Este enlace no permite reproducción directa incrustada',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes reproducirlo de inmediato en la aplicación de origen:',
              style: GoogleFonts.montserrat(color: _kTextoSecundario, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _abrirEnAppExterna,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Abrir en ${detectarNombrePlataforma(widget.url)}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.md)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
