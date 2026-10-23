import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/widgets/video_player_modal.dart';

const Color _kFondoOscuro = Color(0xFF121212);
const Color _kTarjetaOscura = Color(0xFF1E1E1E);
const Color _kBordeOscuro = Color(0xFF2C2C2C);
const Color _kTextoSecundario = Color(0xFFA0A0A0);

Color _faseColor(String fase) {
  switch (fase) {
    case 'Calentamiento':
      return Colors.orangeAccent;
    case 'Técnica':
      return Colors.lightBlueAccent;
    case 'Acrobacias':
      return GingaColors.accentAmber;
    case 'Juegos':
      return GingaColors.brandGreen;
    case 'Roda':
      return Colors.purpleAccent;
    case 'Vuelta a la Calma':
      return Colors.tealAccent;
    default:
      return _kTextoSecundario;
  }
}

Color _publicoColor(String pub) {
  switch (pub) {
    case 'Niños':
      return GingaColors.brandGreen;
    case 'Adultos':
      return Colors.lightBlueAccent;
    default:
      return Colors.cyanAccent;
  }
}

IconData _detectarIconoLink(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('instagram.com')) return Icons.camera_alt_outlined;
  if (lower.contains('tiktok.com')) return Icons.music_note_outlined;
  if (lower.contains('youtube.com') || lower.contains('youtu.be')) return Icons.play_arrow;
  return Icons.link;
}

String _formatearNombreLink(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('instagram.com')) return 'Ver Reel en Instagram';
  if (lower.contains('tiktok.com')) return 'Ver en TikTok';
  if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'Ver en YouTube';
  return 'Abrir enlace de video';
}

/// Busca en el mapa de ideas del instructor si este ejercicio está vinculado a un recurso guardado
Map<String, dynamic>? _buscarIdeaParaEjercicio({
  required Map<String, dynamic> ejercicio,
  required Map<String, Map<String, dynamic>> ideasMap,
}) {
  final rawRecurso = ejercicio['recurso_relacionado'];
  final recursoStr = (rawRecurso is String ? rawRecurso : '').trim();
  final ejNombre = (ejercicio['nombre'] as String? ?? '').toLowerCase().trim();
  final ejUrl = (ejercicio['url_recurso'] as String? ?? '').trim();
  final ejThumb = (ejercicio['thumbnail_url'] as String? ?? '').trim();

  // Si el ejercicio trae su propia URL directa
  if (ejUrl.isNotEmpty) {
    return {
      'url': ejUrl,
      'thumbnail_url': ejThumb.isNotEmpty ? ejThumb : null,
      'titulo': ejercicio['nombre'] ?? 'Recurso',
      'tipo': 'link',
    };
  }

  // Comprobar si el recurso relacionado es válido (evita 'null' o 'none')
  final esRecursoValido = recursoStr.isNotEmpty &&
      recursoStr.toLowerCase() != 'null' &&
      recursoStr.toLowerCase() != 'none';

  if (!esRecursoValido && ejNombre.isEmpty) {
    return null;
  }

  final recursoLower = recursoStr.toLowerCase();

  for (final entry in ideasMap.entries) {
    final idea = entry.value;
    final ideaTitulo = (idea['titulo'] as String? ?? '').toLowerCase().trim();
    final ideaId = entry.key.toLowerCase().trim();

    if (esRecursoValido) {
      if (ideaId == recursoLower ||
          ideaTitulo == recursoLower ||
          ideaTitulo.contains(recursoLower) ||
          recursoLower.contains(ideaTitulo)) {
        return {'id': entry.key, ...idea};
      }
    }

    if (ejNombre.isNotEmpty && ideaTitulo.isNotEmpty) {
      if (ideaTitulo.contains(ejNombre) || ejNombre.contains(ideaTitulo)) {
        return {'id': entry.key, ...idea};
      }
    }
  }

  return null;
}

/// Widget para mostrar la miniatura visual del clip vinculado (igual que en los cards de la pizarra)
class _EjercicioRecursoMiniaturaWidget extends StatelessWidget {
  final Map<String, dynamic> ideaData;
  final String? fallbackTitulo;

  const _EjercicioRecursoMiniaturaWidget({
    required this.ideaData,
    this.fallbackTitulo,
  });

  @override
  Widget build(BuildContext context) {
    final url = ideaData['url'] as String?;
    final tipo = ideaData['tipo'] as String? ?? 'link';
    final titulo = (ideaData['titulo'] as String? ?? fallbackTitulo ?? 'Recurso').trim();

    // Determinar miniatura visual
    String? miniatura = ideaData['thumbnail_url'] as String?;
    if (miniatura == null || miniatura.isEmpty) {
      if (tipo == 'imagen' && url != null && url.isNotEmpty) {
        miniatura = url;
      } else if (url != null && url.isNotEmpty) {
        final ytMatch = RegExp(r'(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|shorts\/|embed\/))([a-zA-Z0-9_-]{11})').firstMatch(url);
        if (ytMatch != null) {
          miniatura = 'https://img.youtube.com/vi/${ytMatch.group(1)}/hqdefault.jpg';
        }
      }
    }

    final tieneUrl = url != null && url.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tieneUrl
              ? () {
                  HapticFeedback.lightImpact();
                  mostrarVideoPlayerInApp(
                    context,
                    url: url,
                    titulo: titulo,
                    tipo: tipo,
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(GingaRadius.md),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(GingaRadius.md),
              border: Border.all(
                color: GingaColors.accentAmber.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Miniatura del Clip (Igual que en la Pizarra de Recursos) ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 78,
                    height: 54,
                    color: _kFondoOscuro,
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        if (miniatura != null && miniatura.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: miniatura,
                            fit: BoxFit.cover,
                            placeholder: (context, _) => Container(
                              color: Colors.black26,
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: GingaColors.accentAmber,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, _, __) => Container(
                              color: Colors.white10,
                              child: Icon(
                                tieneUrl ? _detectarIconoLink(url) : Icons.video_collection,
                                color: _kTextoSecundario,
                                size: 24,
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  GingaColors.accentAmber.withValues(alpha: 0.2),
                                  Colors.white10,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              tieneUrl ? _detectarIconoLink(url) : Icons.video_collection,
                              color: GingaColors.accentAmber,
                              size: 24,
                            ),
                          ),
                        // Overlay de Botón Play
                        if (tieneUrl)
                          Container(
                            color: Colors.black26,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ── Información del Recurso ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.push_pin, size: 12, color: GingaColors.accentAmber),
                          const SizedBox(width: 4),
                          Text(
                            'De tu pizarra',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.accentAmber,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (tieneUrl)
                            Icon(_detectarIconoLink(url), size: 12, color: _kTextoSecundario),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        titulo,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tieneUrl) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Toca para reproducir clip ▶',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: GingaColors.accentAmber.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Icono de acción rápida a la derecha ──
                if (tieneUrl)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 2),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: GingaColors.accentAmber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.open_in_new_rounded,
                        size: 15,
                        color: GingaColors.accentAmber,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InstructorPizarraScreen extends StatefulWidget {
  const InstructorPizarraScreen({super.key});

  @override
  State<InstructorPizarraScreen> createState() => _InstructorPizarraScreenState();
}

class _InstructorPizarraScreenState extends State<InstructorPizarraScreen> {
  int _tabActiva = 0; // 0: Ideas & Recursos, 1: Planes Guardados
  String _filtroPublico = 'Todos';
  String _filtroFase = 'Todos';
  String _filtroEstado = 'Todos'; // 'Todos' | '✨ Nuevos' | '🥋 En Clases'

  final List<String> _filtrosPublico = ['Todos', 'Adultos', 'Niños'];
  final List<String> _filtrosFase = [
    'Todos',
    'Calentamiento',
    'Técnica',
    'Acrobacias',
    'Juegos',
    'Roda',
  ];
  final List<String> _filtrosEstado = ['Todos', '✨ Nuevos', '🥋 En Clases'];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondoOscuro,
      appBar: AppBar(
        backgroundColor: _kFondoOscuro,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pizarra de Entrenamiento',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              'Banco de ideas, videos y planes de clase',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: _kTextoSecundario,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            children: [
              // ── Selector de Pestaña: Ideas vs Planes Guardados ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _kTarjetaOscura,
                    borderRadius: BorderRadius.circular(GingaRadius.full),
                    border: Border.all(color: _kBordeOscuro),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _tabActiva = 0),
                          borderRadius: BorderRadius.circular(GingaRadius.full),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _tabActiva == 0 ? GingaColors.brandGreen : Colors.transparent,
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 16,
                                  color: _tabActiva == 0 ? Colors.black : _kTextoSecundario,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Ideas & Recursos',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12.5,
                                    fontWeight: _tabActiva == 0 ? FontWeight.w700 : FontWeight.w600,
                                    color: _tabActiva == 0 ? Colors.black : _kTextoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _tabActiva = 1),
                          borderRadius: BorderRadius.circular(GingaRadius.full),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _tabActiva == 1 ? GingaColors.brandGreen : Colors.transparent,
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_kabaddi,
                                  size: 16,
                                  color: _tabActiva == 1 ? Colors.black : _kTextoSecundario,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Planes Guardados',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12.5,
                                    fontWeight: _tabActiva == 1 ? FontWeight.w700 : FontWeight.w600,
                                    color: _tabActiva == 1 ? Colors.black : _kTextoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Botón Destacado: Armar Clase con IA ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: InkWell(
                  onTap: () => _mostrarGeneradorClaseIA(context),
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A2F), Color(0xFF13221C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      border: Border.all(
                        color: GingaColors.brandGreen.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GingaColors.brandGreen.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GingaColors.brandGreen.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: GingaColors.brandGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Armar Clase con IA',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: GingaColors.brandGreen,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'NUEVO',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Planifica 45 a 90 min en segundos con tus recursos',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: _kTextoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: GingaColors.brandGreen, size: 22),
                      ],
                    ),
                  ),
                ),
              ),

              if (_tabActiva == 0) ...[
                // ── Selector de Filtros (Grupo, Fase, Estado) ──
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Grupo Público
                      Text(
                        'Grupo:',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundario,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ..._filtrosPublico.map((pub) {
                        final isSelected = _filtroPublico == pub;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(pub),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _filtroPublico = pub);
                            },
                            selectedColor: pub == 'Niños'
                                ? GingaColors.brandGreen
                                : (pub == 'Adultos' ? Colors.lightBlueAccent : GingaColors.brandGreen),
                            backgroundColor: _kTarjetaOscura,
                            labelStyle: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (pub == 'Adultos' ? Colors.black : Colors.white)
                                  : _kTextoSecundario,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                              side: BorderSide(
                                color: isSelected
                                    ? (pub == 'Adultos' ? Colors.lightBlueAccent : GingaColors.brandGreen)
                                    : _kBordeOscuro,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Separador
                      Container(
                        height: 20,
                        width: 1.2,
                        color: _kBordeOscuro,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                      ),

                      // Fase
                      Text(
                        'Fase:',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundario,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ..._filtrosFase.map((fase) {
                        final isSelected = _filtroFase == fase;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(fase),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _filtroFase = fase);
                            },
                            selectedColor: _faseColor(fase),
                            backgroundColor: _kTarjetaOscura,
                            labelStyle: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.black : _kTextoSecundario,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                              side: BorderSide(
                                color: isSelected ? _faseColor(fase) : _kBordeOscuro,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Separador
                      Container(
                        height: 20,
                        width: 1.2,
                        color: _kBordeOscuro,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                      ),

                      // Estado
                      Text(
                        'Estado:',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundario,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ..._filtrosEstado.map((est) {
                        final isSelected = _filtroEstado == est;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(est),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _filtroEstado = est);
                            },
                            selectedColor: est == 'Por Enseñar'
                                ? GingaColors.brandGreen
                                : (est == 'Ya Usados' ? Colors.grey[700] : GingaColors.brandGreen),
                            backgroundColor: _kTarjetaOscura,
                            labelStyle: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (est == 'Ya Usados' ? Colors.white : Colors.black)
                                  : _kTextoSecundario,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                              side: BorderSide(
                                color: isSelected
                                    ? (est == 'Ya Usados' ? Colors.white60 : GingaColors.brandGreen)
                                    : _kBordeOscuro,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // ── Lista reactiva de ideas desde Firestore ──
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('instructor_ideas')
                        .orderBy('created_at', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: GingaColors.brandGreen),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final pub = (data['publico'] ?? (data['categoria'] == 'Niños' ? 'Niños' : (data['categoria'] == 'Adultos' ? 'Adultos' : 'Todos'))).toString();
                        final fase = (data['tipo_ejercicio'] ?? (data['categoria'] != 'Adultos' && data['categoria'] != 'Niños' ? data['categoria'] : 'General')).toString();
                        final completado = data['completado'] == true;

                        final matchPublico = _filtroPublico == 'Todos' || pub == _filtroPublico || pub == 'Todos' || pub == 'Mixto';
                        final matchFase = _filtroFase == 'Todos' || fase.toLowerCase() == _filtroFase.toLowerCase();

                        final clUsada = data['clase_usada'] as String?;
                        final vUsada = (data['veces_usada'] as num?)?.toInt() ?? 0;
                        final tieneUsoClase = (clUsada != null && clUsada.trim().isNotEmpty) || vUsada > 0;

                        bool matchEstado = true;
                        if (_filtroEstado == '✨ Nuevos') {
                          matchEstado = !completado && !tieneUsoClase;
                        } else if (_filtroEstado == '🥋 En Clases') {
                          matchEstado = completado || tieneUsoClase;
                        }

                        return matchPublico && matchFase && matchEstado;
                      }).toList();

                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _filtroEstado == 'Por Enseñar'
                                  ? '¡Excelente! No hay ejercicios pendientes para este filtro 🎉'
                                  : 'No hay ejercicios para Grupo: "$_filtroPublico", Fase: "$_filtroFase" y Estado: "$_filtroEstado"',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(color: _kTextoSecundario),
                            ),
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = constraints.maxWidth;
                          int columns = 1;
                          if (maxWidth >= 1200) {
                            columns = 4;
                          } else if (maxWidth >= 850) {
                            columns = 3;
                          } else if (maxWidth >= 550) {
                            columns = 2;
                          }

                          if (columns == 1) {
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                return _IdeaCard(
                                  id: doc.id,
                                  data: data,
                                  onToggleCompletado: (val) {
                                    doc.reference.update({'completado': val});
                                  },
                                  onEdit: () => _abrirModalEditarIdea(context, doc.id, data),
                                  onDelete: () => _confirmarEliminar(doc.id, data['titulo'] ?? 'esta idea'),
                                );
                              },
                            );
                          }

                          // Masonry grid multi-columna para Desktop y Tablet
                          final List<List<Widget>> columnItems = List.generate(columns, (_) => []);
                          for (int i = 0; i < docs.length; i++) {
                            final doc = docs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final col = i % columns;
                            columnItems[col].add(
                              _IdeaCard(
                                id: doc.id,
                                data: data,
                                onToggleCompletado: (val) {
                                  doc.reference.update({'completado': val});
                                },
                                onEdit: () => _abrirModalEditarIdea(context, doc.id, data),
                                onDelete: () => _confirmarEliminar(doc.id, data['titulo'] ?? 'esta idea'),
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int c = 0; c < columns; c++) ...[
                                  if (c > 0) const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: columnItems[c],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ] else ...[
                // ── Vista de Planes de Clase Guardados ──
                _buildPlanesGuardadosView(),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GingaColors.brandGreen,
        foregroundColor: Colors.white,
        icon: Icon(_tabActiva == 0 ? Icons.add : Icons.auto_awesome),
        label: Text(
          _tabActiva == 0 ? 'Nueva Idea' : 'Armar Plan IA',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          if (_tabActiva == 0) {
            _abrirModalCrearIdea(context);
          } else {
            _mostrarGeneradorClaseIA(context);
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kTarjetaOscura,
                shape: BoxShape.circle,
                border: Border.all(color: _kBordeOscuro),
              ),
              child: const Icon(
                Icons.lightbulb_outline,
                size: 48,
                color: GingaColors.accentAmber,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tu pizarra está vacía',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guarda aquí videos de TikTok, Reels de Instagram, capturas de pantalla o notas para tus próximas clases.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: _kTextoSecundario,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _abrirModalCrearIdea(context),
              icon: const Icon(Icons.add),
              label: const Text('Agregar primera idea'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminar(String id, String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kTarjetaOscura,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          side: const BorderSide(color: _kBordeOscuro),
        ),
        title: Text(
          '¿Eliminar idea?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          'Se eliminará "$titulo" de tu pizarra.',
          style: GoogleFonts.montserrat(color: _kTextoSecundario),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.montserrat(color: _kTextoSecundario),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseFirestore.instance.collection('instructor_ideas').doc(id).delete();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarPlan(String id, String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kTarjetaOscura,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          side: const BorderSide(color: _kBordeOscuro),
        ),
        title: Text(
          '¿Eliminar plan de clase?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          'Se eliminará "$titulo". Esta acción no se puede deshacer.',
          style: GoogleFonts.montserrat(color: _kTextoSecundario),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.montserrat(color: _kTextoSecundario),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseFirestore.instance.collection('instructor_planes_clase').doc(id).delete();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanesGuardadosView() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('instructor_planes_clase')
            .where('instructor_id', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: GingaColors.brandGreen),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error cargando planes: ${snapshot.error}',
                  style: GoogleFonts.montserrat(color: Colors.redAccent),
                ),
              ),
            );
          }

          final rawDocs = snapshot.data?.docs ?? [];
          if (rawDocs.isEmpty) {
            return _buildPlanesEmptyState();
          }

          // Ordenar en memoria por created_at desc (seguro contra índices ausentes)
          final docs = List<QueryDocumentSnapshot>.from(rawDocs)
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = (aData['created_at'] as Timestamp?)?.toDate() ?? DateTime(2000);
              final bTime = (bData['created_at'] as Timestamp?)?.toDate() ?? DateTime(2000);
              return bTime.compareTo(aTime);
            });

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final card = _PlanClaseCard(
                    planId: doc.id,
                    data: data,
                    uid: _uid,
                    onVerFicha: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => _GeneradorClaseModal(
                          uid: _uid,
                          initialPlan: data,
                          initialPlanId: doc.id,
                        ),
                      );
                    },
                    onIniciarClase: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ClaseEnVivoScreen(
                            planId: doc.id,
                            planData: data,
                            uid: _uid,
                          ),
                        ),
                      );
                    },
                    onDelete: () => _confirmarEliminarPlan(doc.id, data['titulo'] ?? 'este plan'),
                  );

                  if (isWide) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: card,
                      ),
                    );
                  }
                  return card;
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlanesEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kTarjetaOscura,
                shape: BoxShape.circle,
                border: Border.all(color: _kBordeOscuro),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: GingaColors.brandGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No tienes planes guardados',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Genera una clase estructurada con la IA a partir de tus videos e ideas de la Pizarra.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: _kTextoSecundario,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _mostrarGeneradorClaseIA(context),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('✨ Armar Plan de Clase con IA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalCrearIdea(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalIdea(uid: _uid),
    );
  }

  void _abrirModalEditarIdea(BuildContext context, String ideaId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalIdea(
        uid: _uid,
        ideaId: ideaId,
        initialData: data,
      ),
    );
  }

  void _mostrarGeneradorClaseIA(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GeneradorClaseModal(uid: _uid),
    );
  }
}

// ─────────────────────────────────────────
//  MODAL PARA CREAR O EDITAR IDEA / RECURSO
// ─────────────────────────────────────────
class _ModalIdea extends StatefulWidget {
  final String? uid;
  final String? ideaId;
  final Map<String, dynamic>? initialData;

  const _ModalIdea({
    required this.uid,
    this.ideaId,
    this.initialData,
  });

  bool get isEditing => ideaId != null;

  @override
  State<_ModalIdea> createState() => _ModalIdeaState();
}

class _ModalIdeaState extends State<_ModalIdea> {
  final _tituloCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  String _tipo = 'link'; // 'link' | 'imagen' | 'texto'
  String _publico = 'Adultos';
  String _tipoEjercicio = 'Técnica';
  XFile? _imagenSeleccionada;
  Uint8List? _webImageBytes;
  bool _subiendo = false;

  final List<String> _publicos = ['Adultos', 'Niños', 'Mixto'];
  final List<String> _tiposEjercicio = [
    'Calentamiento',
    'Técnica',
    'Acrobacias',
    'Juegos',
    'Roda',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _tituloCtrl.text = d['titulo'] ?? '';
      _notasCtrl.text = d['notas'] ?? '';
      _urlCtrl.text = d['url'] ?? '';
      _tipo = d['tipo'] ?? 'link';
      _publico = d['publico'] ?? (d['categoria'] == 'Niños' ? 'Niños' : 'Adultos');
      _tipoEjercicio = d['tipo_ejercicio'] ?? (d['categoria'] != 'Adultos' && d['categoria'] != 'Niños' ? d['categoria'] : 'Técnica');
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _notasCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imagenSeleccionada = picked;
          _webImageBytes = bytes;
          _tipo = 'imagen';
        });
      } else {
        setState(() {
          _imagenSeleccionada = picked;
          _tipo = 'imagen';
        });
      }
    }
  }

  Future<void> _guardarIdea() async {
    var titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      if (_tipo == 'link' && _urlCtrl.text.trim().isNotEmpty) {
        final u = _urlCtrl.text.trim().toLowerCase();
        if (u.contains('tiktok.com')) {
          titulo = 'Ejercicio TikTok ($_tipoEjercicio)';
        } else if (u.contains('instagram.com')) {
          titulo = 'Reel Instagram ($_tipoEjercicio)';
        } else if (u.contains('youtube.com') || u.contains('youtu.be')) {
          titulo = 'Video YouTube ($_tipoEjercicio)';
        } else {
          titulo = 'Ejercicio $_tipoEjercicio';
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor escribe un título o nombre del movimiento')),
        );
        return;
      }
    }

    setState(() => _subiendo = true);

    try {
      String? mediaUrl;
      if (_tipo == 'imagen' && _imagenSeleccionada != null) {
        final storageRef = FirebaseStorage.instance
            .ref('instructor_ideas/${widget.uid ?? "anon"}/${DateTime.now().millisecondsSinceEpoch}.jpg');

        if (kIsWeb && _webImageBytes != null) {
          await storageRef.putData(_webImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        } else if (_imagenSeleccionada?.path != null) {
          await storageRef.putFile(File(_imagenSeleccionada!.path));
        }
        mediaUrl = await storageRef.getDownloadURL();
      } else if (_tipo == 'link') {
        var rawUrl = _urlCtrl.text.trim();
        if (rawUrl.isNotEmpty && !rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
          rawUrl = 'https://$rawUrl';
        }
        mediaUrl = rawUrl;
      }

      if (widget.isEditing) {
        final Map<String, dynamic> updateData = {
          'titulo': titulo,
          'notas': _notasCtrl.text.trim(),
          'tipo': _tipo,
          'publico': _publico,
          'tipo_ejercicio': _tipoEjercicio,
          'categoria': _tipoEjercicio,
        };
        if (_tipo == 'imagen' && mediaUrl != null) {
          updateData['url'] = mediaUrl;
          updateData['thumbnail_url'] = mediaUrl;
        } else if (_tipo == 'link') {
          var newUrl = _urlCtrl.text.trim();
          if (newUrl.isNotEmpty && !newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
            newUrl = 'https://$newUrl';
          }
          updateData['url'] = newUrl;
          if (newUrl != widget.initialData?['url']) {
            updateData['thumbnail_url'] = FieldValue.delete();
          }
        }
        await FirebaseFirestore.instance.collection('instructor_ideas').doc(widget.ideaId!).update(updateData);
      } else {
        await FirebaseFirestore.instance.collection('instructor_ideas').add({
          'titulo': titulo,
          'notas': _notasCtrl.text.trim(),
          'tipo': _tipo,
          'url': mediaUrl ?? '',
          'publico': _publico,
          'tipo_ejercicio': _tipoEjercicio,
          'categoria': _tipoEjercicio,
          'completado': false,
          'instructor_id': widget.uid ?? '',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? '¡Ejercicio actualizado con éxito! ✏️' : '¡Idea guardada en tu pizarra! 💡'),
            backgroundColor: GingaColors.brandGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isEditing ? 'Editar Ejercicio / Idea' : 'Nueva Idea de Entrenamiento',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _kTextoSecundario),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selector de tipo
            Row(
              children: [
                _buildTipoOption('link', Icons.link, 'Link (Reel/TikTok)'),
                const SizedBox(width: 8),
                _buildTipoOption('imagen', Icons.photo_camera_outlined, 'Foto/Captura'),
                const SizedBox(width: 8),
                _buildTipoOption('texto', Icons.edit_note, 'Solo Nota'),
              ],
            ),
            const SizedBox(height: 16),

            // Título
            TextField(
              controller: _tituloCtrl,
              style: GoogleFonts.montserrat(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Título o Movimiento *',
                hintText: 'Ej. Esquiva lateral + Martelo',
                labelStyle: GoogleFonts.montserrat(color: _kTextoSecundario),
                hintStyle: GoogleFonts.montserrat(color: Colors.white24),
                filled: true,
                fillColor: _kFondoOscuro,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  borderSide: const BorderSide(color: _kBordeOscuro),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Campo dinámico según tipo
            if (_tipo == 'link') ...[
              TextField(
                controller: _urlCtrl,
                style: GoogleFonts.montserrat(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Link de Instagram Reel, TikTok o YouTube',
                  hintText: 'https://instagram.com/reel/...',
                  prefixIcon: const Icon(Icons.video_library_outlined, color: GingaColors.brandGreen),
                  labelStyle: GoogleFonts.montserrat(color: _kTextoSecundario),
                  hintStyle: GoogleFonts.montserrat(color: Colors.white24),
                  filled: true,
                  fillColor: _kFondoOscuro,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: const BorderSide(color: _kBordeOscuro),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_tipo == 'imagen') ...[
              InkWell(
                onTap: _seleccionarFoto,
                borderRadius: BorderRadius.circular(GingaRadius.md),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _kFondoOscuro,
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    border: Border.all(color: _kBordeOscuro, style: BorderStyle.solid),
                  ),
                  child: _imagenSeleccionada != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          child: kIsWeb && _webImageBytes != null
                              ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                              : Image.file(File(_imagenSeleccionada!.path), fit: BoxFit.cover),
                        )
                      : (widget.initialData?['url'] != null && (widget.initialData!['url'] as String).isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: widget.initialData!['url'],
                                    width: double.infinity,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: Text(
                                      'Toca para cambiar imagen',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_outlined, color: GingaColors.brandGreen, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'Subir captura o foto de pizarra',
                                  style: GoogleFonts.montserrat(color: _kTextoSecundario, fontSize: 13),
                                ),
                              ],
                            )),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 1. Público
            Text(
              '1. ¿Para quién es? (Grupo)',
              style: GoogleFonts.montserrat(color: _kTextoSecundario, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _publicos.map((pub) {
                final isSelected = _publico == pub;
                return ChoiceChip(
                  label: Text(pub),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _publico = pub);
                  },
                  selectedColor: _publicoColor(pub),
                  backgroundColor: _kFondoOscuro,
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black : _kTextoSecundario,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    side: BorderSide(
                      color: isSelected ? _publicoColor(pub) : _kBordeOscuro,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // 2. Tipo / Fase
            Text(
              '2. Tipo de Ejercicio / Fase',
              style: GoogleFonts.montserrat(color: _kTextoSecundario, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tiposEjercicio.map((tipo) {
                final isSelected = _tipoEjercicio == tipo;
                return ChoiceChip(
                  label: Text(tipo),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _tipoEjercicio = tipo);
                  },
                  selectedColor: _faseColor(tipo),
                  backgroundColor: _kFondoOscuro,
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black : _kTextoSecundario,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    side: BorderSide(
                      color: isSelected ? _faseColor(tipo) : _kBordeOscuro,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Notas
            TextField(
              controller: _notasCtrl,
              maxLines: 2,
              style: GoogleFonts.montserrat(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Notas o tips técnicos (opcional)',
                hintText: 'Ej. 3 series de 6 reps. Cuidar postura del torso.',
                labelStyle: GoogleFonts.montserrat(color: _kTextoSecundario),
                hintStyle: GoogleFonts.montserrat(color: Colors.white24),
                filled: true,
                fillColor: _kFondoOscuro,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  borderSide: const BorderSide(color: _kBordeOscuro),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _subiendo ? null : _guardarIdea,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GingaColors.brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                ),
                child: _subiendo
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        widget.isEditing ? 'Guardar Cambios' : 'Guardar en la Pizarra',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoOption(String tipo, IconData icon, String label) {
    final isSelected = _tipo == tipo;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tipo = tipo),
        borderRadius: BorderRadius.circular(GingaRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? GingaColors.brandGreen.withValues(alpha: 0.15) : _kFondoOscuro,
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(
              color: isSelected ? GingaColors.brandGreen : _kBordeOscuro,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? GingaColors.brandGreen : _kTextoSecundario, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : _kTextoSecundario,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TARJETA VISUAL DE LA IDEA
// ─────────────────────────────────────────
class _IdeaCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final ValueChanged<bool> onToggleCompletado;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IdeaCard({
    required this.id,
    required this.data,
    required this.onToggleCompletado,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completado = data['completado'] == true;
    final tipo = data['tipo'] ?? 'texto';
    final url = data['url'] as String?;
    final titulo = data['titulo'] ?? '';
    final notas = data['notas'] as String?;
    final publico = (data['publico'] ?? (data['categoria'] == 'Niños' ? 'Niños' : (data['categoria'] == 'Adultos' ? 'Adultos' : null))) as String?;
    final tipoEjercicio = (data['tipo_ejercicio'] ?? (data['categoria'] != 'Adultos' && data['categoria'] != 'Niños' ? data['categoria'] : 'General')) as String;
    final claseUsada = data['clase_usada'] as String?;
    final int vecesUsada = (data['veces_usada'] as num?)?.toInt() ?? 0;
    final bool tieneUsoEnClase = (claseUsada != null && claseUsada.trim().isNotEmpty) || vecesUsada > 0;

    // Determinar miniatura visual
    String? miniatura = data['thumbnail_url'] as String?;
    if (miniatura == null || miniatura.isEmpty) {
      if (tipo == 'imagen') {
        miniatura = url;
      } else if (tipo == 'link' && url != null) {
        final ytMatch = RegExp(r'(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|shorts\/|embed\/))([a-zA-Z0-9_-]{11})').firstMatch(url);
        if (ytMatch != null) {
          miniatura = 'https://img.youtube.com/vi/${ytMatch.group(1)}/hqdefault.jpg';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(
          color: completado ? GingaColors.brandGreen.withValues(alpha: 0.4) : _kBordeOscuro,
        ),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniatura visual (tanto si es imagen subida, o si es link con miniatura de Reel/TikTok/YouTube)
            if (miniatura != null && miniatura.isNotEmpty)
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(GingaRadius.lg)),
                    child: CachedNetworkImage(
                      imageUrl: miniatura,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 190,
                        color: _kFondoOscuro,
                        child: const Center(
                          child: CircularProgressIndicator(color: GingaColors.brandGreen, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 170,
                        color: _kFondoOscuro,
                        child: const Icon(Icons.broken_image, color: _kTextoSecundario),
                      ),
                    ),
                  ),
                  // Botón Play sobre la miniatura si es un video/link
                  if ((tipo == 'link' || tipo == 'video') && url != null && url.isNotEmpty)
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        mostrarVideoPlayerInApp(
                          context,
                          url: url,
                          titulo: titulo,
                          tipo: tipo,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 2),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                ],
              ),

            // Tocar el contenido de la tarjeta abre edición
            InkWell(
              onTap: onEdit,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(GingaRadius.lg)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila superior: Badges + Botones Editar / Eliminar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              // Badge de Estado en Clase (Historial)
                              if (tieneUsoEnClase)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: GingaColors.accentAmber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(GingaRadius.full),
                                    border: Border.all(color: GingaColors.accentAmber.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bookmark_added_rounded, size: 12, color: GingaColors.accentAmber),
                                      const SizedBox(width: 4),
                                      Text(
                                        vecesUsada > 1 ? 'Usado $vecesUsada veces' : 'En plan: ${claseUsada ?? "Clase"}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: GingaColors.accentAmber,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(GingaRadius.full),
                                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFF00E676)),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Nuevo',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF00E676),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (completado)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: GingaColors.brandGreen.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(GingaRadius.full),
                                    border: Border.all(color: GingaColors.brandGreen.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle, size: 12, color: GingaColors.brandGreen),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Enseñado',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: GingaColors.brandGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (publico != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _publicoColor(publico).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(GingaRadius.full),
                                  ),
                                  child: Text(
                                    publico,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _publicoColor(publico),
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _faseColor(tipoEjercicio).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(GingaRadius.full),
                                ),
                                child: Text(
                                  tipoEjercicio,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _faseColor(tipoEjercicio),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: _kTextoSecundario),
                              onPressed: onEdit,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Editar ejercicio',
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: _kTextoSecundario),
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                  // Título con checkbox de completado
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => onToggleCompletado(!completado),
                        child: Container(
                          margin: const EdgeInsets.only(top: 2, right: 10),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: completado ? GingaColors.brandGreen : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: completado ? GingaColors.brandGreen : _kTextoSecundario,
                              width: 1.5,
                            ),
                          ),
                          child: completado
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          titulo,
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: completado ? _kTextoSecundario : Colors.white,
                            decoration: completado ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Notas opcionales
                  if (notas != null && notas.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        notas,
                        style: GoogleFonts.montserrat(
                          fontSize: 12.5,
                          color: _kTextoSecundario,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],

                  // Detalle de clase donde se utilizó
                  if (claseUsada != null && claseUsada.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Row(
                        children: [
                          const Icon(Icons.history_edu, size: 13, color: _kTextoSecundario),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Usado en: $claseUsada',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: _kTextoSecundario,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Botón si es Link o Video (Reel / TikTok / YouTube / MP4)
                  if ((tipo == 'link' || tipo == 'video') && url != null && url.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          mostrarVideoPlayerInApp(
                            context,
                            url: url,
                            titulo: titulo,
                            tipo: tipo,
                          );
                        },
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _kFondoOscuro,
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(color: _kBordeOscuro),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _detectarIconoLink(url),
                                size: 16,
                                color: GingaColors.brandGreen,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _formatearNombreLink(url),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.play_circle_outline_rounded, size: 15, color: GingaColors.accentAmber),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  MODAL: ARMAR CLASE CON IA (OPENAI / GEMINI)
// ─────────────────────────────────────────
class _GeneradorClaseModal extends StatefulWidget {
  final String? uid;
  final Map<String, dynamic>? initialPlan;
  final String? initialPlanId;

  const _GeneradorClaseModal({
    required this.uid,
    this.initialPlan,
    this.initialPlanId,
  });

  @override
  State<_GeneradorClaseModal> createState() => _GeneradorClaseModalState();
}

class _GeneradorClaseModalState extends State<_GeneradorClaseModal> {
  String _nivel = 'Adultos';
  int _duracion = 60;
  String _enfoque = 'Técnica & Movilidad';
  final _notasCtrl = TextEditingController();

  bool _cargando = false;
  String? _error;
  Map<String, dynamic>? _planGenerado;
  bool _guardandoPlan = false;
  bool _planGuardado = false;
  String? _savedPlanId;
  Map<String, Map<String, dynamic>> _ideasMap = {};
  Set<String> _ideasSeleccionadasIds = {};

  // Modo Edición
  bool _editando = false;
  TextEditingController? _tituloEditCtrl;
  TextEditingController? _objetivoEditCtrl;
  List<Map<String, dynamic>> _bloquesEditables = [];

  final List<String> _niveles = ['Adultos', 'Niños', 'Mixto'];
  final List<int> _duraciones = [45, 60, 90];
  final List<String> _enfoques = [
    'Técnica & Movilidad',
    'Acrobacias & Floreos',
    'Juegos & Agilidad',
    'Roda & Ritmo',
    'Combate / Táctico',
  ];

  @override
  void initState() {
    super.initState();
    _cargarIdeas();
    if (widget.initialPlan != null) {
      _planGenerado = Map<String, dynamic>.from(widget.initialPlan!);
      _planGuardado = true;
      _savedPlanId = widget.initialPlanId;
      if (widget.initialPlan!['nivel'] != null) {
        _nivel = widget.initialPlan!['nivel'].toString();
      }
      if (widget.initialPlan!['duracion_total'] != null) {
        _duracion = (widget.initialPlan!['duracion_total'] as num).toInt();
      }
      if (widget.initialPlan!['enfoque'] != null) {
        _enfoque = widget.initialPlan!['enfoque'].toString();
      }
    }
  }

  Future<void> _cargarIdeas() async {
    if (widget.uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('instructor_ideas')
          .where('instructor_id', isEqualTo: widget.uid)
          .get();
      final map = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        map[doc.id] = doc.data();
      }
      if (mounted) {
        setState(() {
          _ideasMap = map;
        });
      }
    } catch (e) {
      debugPrint('Error cargando ideas en modal: $e');
    }
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _tituloEditCtrl?.dispose();
    _objetivoEditCtrl?.dispose();
    super.dispose();
  }

  Future<void> _generarPlan() async {
    setState(() {
      _cargando = true;
      _error = null;
      _planGuardado = false;
      _editando = false;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generarPlanClaseIA',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final payload = <String, dynamic>{
        'nivel': _nivel,
        'duracion': _duracion,
        'enfoque': _enfoque,
        'instrucciones_adicionales': _notasCtrl.text.trim(),
      };

      if (_ideasSeleccionadasIds.isNotEmpty) {
        payload['ideas_seleccionadas'] = _ideasSeleccionadasIds.map((id) {
          final dat = _ideasMap[id];
          return {
            'id': id,
            'titulo': dat?['titulo'] ?? '',
            'categoria': dat?['categoria'] ?? dat?['tipo_ejercicio'] ?? 'General',
            'publico': dat?['publico'] ?? 'Todos',
            'notas': dat?['notas'] ?? '',
            'tipo': dat?['tipo'] ?? 'link',
            'url': dat?['url'] ?? '',
            'usado_previamente': (dat?['clase_usada'] != null && dat?['clase_usada'].toString().trim().isNotEmpty == true) || dat?['completado'] == true,
            'clase_usada': dat?['clase_usada'],
          };
        }).toList();
      }

      final result = await callable.call(payload);

      if (!mounted) return;
      final parsedPlan = Map<String, dynamic>.from(result.data as Map);
      setState(() {
        _planGenerado = parsedPlan;
        _cargando = false;
      });

      // Trazabilidad automática inmediata al generar el plan
      final tituloGenerado = parsedPlan['titulo'] ?? 'Clase de Capoeira';
      _vincularRecursosAClase(tituloGenerado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error generando el plan: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _vincularRecursosAClase(String tituloPlan) async {
    if (_planGenerado == null || widget.uid == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final bloques = _planGenerado!['bloques'] as List? ?? [];
      final Set<String> ideasIdsModificados = {};

      for (final b in bloques) {
        final mapa = Map<String, dynamic>.from(b as Map);
        final ejercicios = mapa['ejercicios'] as List? ?? [];
        for (final ej in ejercicios) {
          final ejMap = Map<String, dynamic>.from(ej as Map);
          final idea = _buscarIdeaParaEjercicio(ejercicio: ejMap, ideasMap: _ideasMap);
          if (idea != null && idea['id'] != null) {
            final id = idea['id'].toString();
            if (!ideasIdsModificados.contains(id)) {
              ideasIdsModificados.add(id);
              final docRef = FirebaseFirestore.instance.collection('instructor_ideas').doc(id);
              batch.update(docRef, {
                'clase_usada': tituloPlan,
                'clases_asociadas': FieldValue.arrayUnion([tituloPlan]),
                'veces_usada': FieldValue.increment(1),
                'fecha_ultimo_uso': FieldValue.serverTimestamp(),
              });
              if (_ideasMap.containsKey(id)) {
                final current = _ideasMap[id]!;
                final int v = (current['veces_usada'] as num?)?.toInt() ?? 0;
                current['clase_usada'] = tituloPlan;
                current['veces_usada'] = v + 1;
              }
            }
          }
        }
      }

      if (ideasIdsModificados.isNotEmpty) {
        await batch.commit();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error vinculando recursos a la clase: $e');
    }
  }

  Future<void> _guardarEnFirestore() async {
    if (_planGenerado == null || _planGuardado) return;
    setState(() => _guardandoPlan = true);

    try {
      final titulo = _planGenerado!['titulo'] ?? 'Clase de Capoeira';
      final docRef = await FirebaseFirestore.instance.collection('instructor_planes_clase').add({
        'instructor_id': widget.uid,
        'titulo': titulo,
        'duracion_total': _planGenerado!['duracion_total'],
        'objetivo': _planGenerado!['objetivo'],
        'bloques': _planGenerado!['bloques'],
        'consejos_instructor': _planGenerado!['consejos_instructor'],
        'nivel': _nivel,
        'enfoque': _enfoque,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Trazabilidad automática de recursos
      await _vincularRecursosAClase(titulo);

      if (!mounted) return;
      setState(() {
        _guardandoPlan = false;
        _planGuardado = true;
        _savedPlanId = docRef.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ¡Plan de clase guardado con éxito!'),
          backgroundColor: GingaColors.brandGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardandoPlan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando plan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _iniciarEdicion() {
    if (_planGenerado == null) return;
    _tituloEditCtrl?.dispose();
    _objetivoEditCtrl?.dispose();

    _tituloEditCtrl = TextEditingController(text: _planGenerado!['titulo'] ?? '');
    _objetivoEditCtrl = TextEditingController(text: _planGenerado!['objetivo'] ?? '');

    final rawBloques = _planGenerado!['bloques'] as List? ?? [];
    _bloquesEditables = rawBloques.map((b) {
      final bMap = Map<String, dynamic>.from(b as Map);
      final rawEjs = bMap['ejercicios'] as List? ?? [];
      return {
        'fase': bMap['fase']?.toString() ?? 'Fase',
        'duracion_min': (bMap['duracion_min'] as num?)?.toInt() ?? 10,
        'ejercicios': rawEjs.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      };
    }).toList();

    setState(() {
      _editando = true;
    });
  }

  void _cancelarEdicion() {
    setState(() {
      _editando = false;
    });
  }

  Future<void> _guardarEdicion() async {
    if (_planGenerado == null) return;

    final nuevoTitulo = _tituloEditCtrl?.text.trim().isNotEmpty == true
        ? _tituloEditCtrl!.text.trim()
        : (_planGenerado!['titulo'] ?? 'Clase de Capoeira');
    final nuevoObjetivo = _objetivoEditCtrl?.text.trim() ?? '';

    int duracionTotalCalculada = 0;
    for (final b in _bloquesEditables) {
      duracionTotalCalculada += ((b['duracion_min'] as num?)?.toInt() ?? 0);
    }
    if (duracionTotalCalculada <= 0) duracionTotalCalculada = _duracion;

    final planActualizado = Map<String, dynamic>.from(_planGenerado!);
    planActualizado['titulo'] = nuevoTitulo;
    planActualizado['objetivo'] = nuevoObjetivo;
    planActualizado['duracion_total'] = duracionTotalCalculada;
    planActualizado['bloques'] = _bloquesEditables;

    setState(() {
      _planGenerado = planActualizado;
      _editando = false;
    });

    if (_savedPlanId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('instructor_planes_clase')
            .doc(_savedPlanId)
            .update({
          'titulo': nuevoTitulo,
          'objetivo': nuevoObjetivo,
          'duracion_total': duracionTotalCalculada,
          'bloques': _bloquesEditables,
          'updated_at': FieldValue.serverTimestamp(),
        });
        await _vincularRecursosAClase(nuevoTitulo);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ ¡Cambios guardados en tu plan de clase!'),
              backgroundColor: GingaColors.brandGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error actualizando plan en Firestore: $e');
      }
    } else {
      await _guardarEnFirestore();
    }
  }

  void _moverBloque(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _bloquesEditables.length) return;
    setState(() {
      final item = _bloquesEditables.removeAt(index);
      _bloquesEditables.insert(newIndex, item);
    });
  }

  void _eliminarBloque(int index) {
    if (_bloquesEditables.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe haber al menos 1 fase en la clase'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _bloquesEditables.removeAt(index);
    });
  }

  void _agregarNuevoBloque() {
    setState(() {
      _bloquesEditables.add({
        'fase': 'Nueva Fase',
        'duracion_min': 10,
        'ejercicios': <Map<String, dynamic>>[
          {
            'nombre': 'Nuevo Ejercicio',
            'detalle': 'Describe la técnica, drill o dinámica',
            'recurso_relacionado': null,
          }
        ],
      });
    });
  }

  void _mostrarPickerRecursos(Map<String, dynamic> ejercicio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (bottomCtx, setSheetState) {
            final todasLasIdeas = _ideasMap.entries.toList();
            final ideasFiltradas = todasLasIdeas.where((entry) {
              final d = entry.value;
              final t = (d['titulo'] as String? ?? '').toLowerCase();
              final n = (d['notas'] as String? ?? '').toLowerCase();
              final c = (d['categoria'] as String? ?? '').toLowerCase();
              final q = query.toLowerCase().trim();
              if (q.isEmpty) return true;
              return t.contains(q) || n.contains(q) || c.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: _kTarjetaOscura,
                borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.video_library_rounded, color: GingaColors.brandGreen, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Vincular Clip de tu Pizarra',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: _kTextoSecundario),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: TextField(
                      style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, categoría o nota...',
                        hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundario),
                        prefixIcon: const Icon(Icons.search, color: _kTextoSecundario, size: 20),
                        filled: true,
                        fillColor: _kFondoOscuro,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          borderSide: const BorderSide(color: _kBordeOscuro),
                        ),
                      ),
                      onChanged: (val) {
                        setSheetState(() => query = val);
                      },
                    ),
                  ),
                  const Divider(color: _kBordeOscuro, height: 1),
                  Expanded(
                    child: ideasFiltradas.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No se encontraron recursos en tu Pizarra',
                                style: GoogleFonts.montserrat(color: _kTextoSecundario),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: ideasFiltradas.length,
                            itemBuilder: (context, i) {
                              final item = ideasFiltradas[i];
                              final idea = item.value;
                              final titulo = idea['titulo'] as String? ?? 'Sin título';
                              final tipo = idea['tipo'] as String? ?? 'link';
                              final url = idea['url'] as String? ?? '';
                              final thumb = idea['thumbnail_url'] as String?;
                              final clUsada = idea['clase_usada'] as String?;
                              final vUsada = (idea['veces_usada'] as num?)?.toInt() ?? 0;
                              final bool yaUsada = (clUsada != null && clUsada.trim().isNotEmpty) || vUsada > 0;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    ejercicio['recurso_relacionado'] = titulo;
                                    ejercicio['url_recurso'] = url;
                                    ejercicio['thumbnail_url'] = thumb;
                                  });
                                  Navigator.pop(ctx);
                                },
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _kFondoOscuro,
                                    borderRadius: BorderRadius.circular(GingaRadius.md),
                                    border: Border.all(color: _kBordeOscuro),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: (thumb != null && thumb.isNotEmpty)
                                            ? CachedNetworkImage(
                                                imageUrl: thumb,
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                placeholder: (c, u) => Container(width: 50, height: 50, color: Colors.white10),
                                                errorWidget: (c, u, e) => Container(
                                                  width: 50,
                                                  height: 50,
                                                  color: Colors.white10,
                                                  child: const Icon(Icons.broken_image, size: 20, color: _kTextoSecundario),
                                                ),
                                              )
                                            : Container(
                                                width: 50,
                                                height: 50,
                                                color: Colors.white10,
                                                child: Icon(
                                                  tipo == 'video' || tipo == 'link' ? Icons.play_circle_outline : Icons.lightbulb_outline,
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
                                              titulo,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (yaUsada)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: GingaColors.accentAmber.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      vUsada > 1 ? 'Usado $vUsada veces' : 'En plan: ${clUsada ?? "Clase"}',
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: GingaColors.accentAmber,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '✨ Nuevo',
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF00E676),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.add_link_rounded, color: GingaColors.brandGreen),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditorPlan() {
    int totalMinutos = 0;
    for (final b in _bloquesEditables) {
      totalMinutos += ((b['duracion_min'] as num?)?.toInt() ?? 0);
    }
    final bool coincideTiempo = totalMinutos == _duracion;

    return Column(
      children: [
        // ── Banner Superior de Edición ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: GingaColors.accentAmber.withValues(alpha: 0.12),
            border: Border(bottom: BorderSide(color: GingaColors.accentAmber.withValues(alpha: 0.3))),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: GingaColors.accentAmber, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo Edición del Plan',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Personaliza fases, minutos, ejercicios y clips',
                      style: GoogleFonts.montserrat(fontSize: 10.5, color: _kTextoSecundario),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: coincideTiempo ? GingaColors.brandGreen.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                  border: Border.all(
                    color: coincideTiempo ? GingaColors.brandGreen : Colors.orange,
                  ),
                ),
                child: Text(
                  '$totalMinutos / $_duracion min',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: coincideTiempo ? GingaColors.brandGreen : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Formulario de Edición ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              // Título
              Text(
                'Título de la Clase',
                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _tituloEditCtrl,
                style: GoogleFonts.montserrat(fontSize: 13.5, color: Colors.white, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Ej. Clase de Fundamentos & Floreios',
                  hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundario),
                  filled: true,
                  fillColor: _kFondoOscuro,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: const BorderSide(color: _kBordeOscuro),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: const BorderSide(color: GingaColors.brandGreen),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Objetivo
              Text(
                'Objetivo de la Sesión',
                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _objetivoEditCtrl,
                maxLines: 2,
                style: GoogleFonts.montserrat(fontSize: 12.5, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ej. Coordinar transiciones de negativa a rolê y progresión de aú',
                  hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundario),
                  filled: true,
                  fillColor: _kFondoOscuro,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: const BorderSide(color: _kBordeOscuro),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: const BorderSide(color: GingaColors.brandGreen),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Fases y Bloques
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fases de la Clase (${_bloquesEditables.length})',
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  TextButton.icon(
                    onPressed: _agregarNuevoBloque,
                    icon: const Icon(Icons.add, size: 16, color: GingaColors.brandGreen),
                    label: Text(
                      'Añadir Fase',
                      style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: GingaColors.brandGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Lista de Bloques
              ...List.generate(_bloquesEditables.length, (bIndex) {
                final bloque = _bloquesEditables[bIndex];
                final ejercicios = bloque['ejercicios'] as List? ?? [];
                final durMin = (bloque['duracion_min'] as num?)?.toInt() ?? 10;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _kFondoOscuro,
                    borderRadius: BorderRadius.circular(GingaRadius.lg),
                    border: Border.all(color: _kBordeOscuro),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header del bloque con reordenamiento y tiempo
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(GingaRadius.lg)),
                          border: const Border(bottom: BorderSide(color: _kBordeOscuro)),
                        ),
                        child: Row(
                          children: [
                            // Flechas arriba/abajo
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.arrow_upward, size: 18, color: bIndex > 0 ? Colors.white : Colors.white24),
                              onPressed: bIndex > 0 ? () => _moverBloque(bIndex, -1) : null,
                              tooltip: 'Mover arriba',
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.arrow_downward, size: 18, color: bIndex < _bloquesEditables.length - 1 ? Colors.white : Colors.white24),
                              onPressed: bIndex < _bloquesEditables.length - 1 ? () => _moverBloque(bIndex, 1) : null,
                              tooltip: 'Mover abajo',
                            ),
                            const SizedBox(width: 4),

                            // Nombre de la fase editable
                            Expanded(
                              child: TextFormField(
                                initialValue: bloque['fase']?.toString() ?? '',
                                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Nombre de la fase',
                                  hintStyle: TextStyle(color: _kTextoSecundario, fontSize: 12),
                                ),
                                onChanged: (val) => bloque['fase'] = val,
                              ),
                            ),

                            // Control de minutos (- / +)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: _kTextoSecundario),
                                  onPressed: () {
                                    setState(() {
                                      final cur = (bloque['duracion_min'] as num?)?.toInt() ?? 10;
                                      bloque['duracion_min'] = cur > 5 ? cur - 5 : 5;
                                    });
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    '$durMin m',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: GingaColors.brandGreen,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.add_circle_outline, size: 20, color: GingaColors.brandGreen),
                                  onPressed: () {
                                    setState(() {
                                      final cur = (bloque['duracion_min'] as num?)?.toInt() ?? 10;
                                      bloque['duracion_min'] = cur + 5;
                                    });
                                  },
                                ),
                              ],
                            ),

                            // Eliminar bloque
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              onPressed: () => _eliminarBloque(bIndex),
                              tooltip: 'Eliminar fase',
                            ),
                          ],
                        ),
                      ),

                      // Lista de ejercicios del bloque
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ...List.generate(ejercicios.length, (eIndex) {
                              final ej = ejercicios[eIndex] as Map<String, dynamic>;
                              final rawRecurso = ej['recurso_relacionado'];
                              final recursoStr = (rawRecurso is String ? rawRecurso : '').trim();
                              final bool tieneClip = recursoStr.isNotEmpty && recursoStr.toLowerCase() != 'null';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _kTarjetaOscura,
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  border: Border.all(color: _kBordeOscuro),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Fila de Nombre + Botón Eliminar
                                    Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: GingaColors.brandGreen.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${eIndex + 1}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: GingaColors.brandGreen,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: ej['nombre']?.toString() ?? '',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              hintText: 'Nombre del ejercicio...',
                                              hintStyle: TextStyle(color: _kTextoSecundario, fontSize: 12),
                                            ),
                                            onChanged: (val) => ej['nombre'] = val,
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.close, size: 16, color: _kTextoSecundario),
                                          onPressed: () {
                                            setState(() {
                                              ejercicios.removeAt(eIndex);
                                            });
                                          },
                                          tooltip: 'Quitar ejercicio',
                                        ),
                                      ],
                                    ),
                                    const Divider(color: _kBordeOscuro, height: 12),

                                    // Detalle / Repeticiones
                                    TextFormField(
                                      initialValue: ej['detalle']?.toString() ?? '',
                                      maxLines: 2,
                                      style: GoogleFonts.montserrat(fontSize: 11.5, color: _kTextoSecundario),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        hintText: 'Instrucciones paso a paso, número de repeticiones o dinámicas...',
                                        hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                                      ),
                                      onChanged: (val) => ej['detalle'] = val,
                                    ),
                                    const SizedBox(height: 6),

                                    // Recurso Vinculado
                                    if (tieneClip)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: GingaColors.accentAmber.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: GingaColors.accentAmber.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.attach_file, size: 14, color: GingaColors.accentAmber),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Clip: $recursoStr',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: GingaColors.accentAmber,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _mostrarPickerRecursos(ej),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: Text(
                                                  'Cambiar',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  ej['recurso_relacionado'] = null;
                                                  ej['url_recurso'] = null;
                                                  ej['thumbnail_url'] = null;
                                                });
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.only(left: 6),
                                                child: Icon(Icons.close, size: 14, color: Colors.white70),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      InkWell(
                                        onTap: () => _mostrarPickerRecursos(ej),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.add_link_rounded, size: 14, color: GingaColors.brandGreen),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Vincular clip de tu Pizarra',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: GingaColors.brandGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),

                            // Botón Añadir Ejercicio
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  ejercicios.add({
                                    'nombre': 'Nuevo Ejercicio',
                                    'detalle': '',
                                    'recurso_relacionado': null,
                                  });
                                });
                              },
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Añadir Ejercicio'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: _kBordeOscuro),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        // ── Barra de Botones Inferiores del Editor ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: _kTarjetaOscura,
            border: Border(top: BorderSide(color: _kBordeOscuro)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelarEdicion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _kBordeOscuro),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _guardarEdicion,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Guardar Cambios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GingaColors.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                    ),
                    textStyle: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copiarAlPortapapeles() {
    if (_planGenerado == null) return;
    final buffer = StringBuffer();
    buffer.writeln('🥋 *${_planGenerado!['titulo']}* (${_planGenerado!['duracion_total']} min)');
    buffer.writeln('🎯 Objetivo: ${_planGenerado!['objetivo']}\n');

    final bloques = _planGenerado!['bloques'] as List? ?? [];
    for (final b in bloques) {
      final mapa = Map<String, dynamic>.from(b as Map);
      buffer.writeln('⏱️ *${mapa['fase']}* (${mapa['duracion_min']} min)');
      final ejercicios = mapa['ejercicios'] as List? ?? [];
      for (final ej in ejercicios) {
        final ejMap = Map<String, dynamic>.from(ej as Map);
        buffer.writeln('• *${ejMap['nombre']}*: ${ejMap['detalle']}');
        final rawRef = (ejMap['recurso_relacionado'] as String? ?? '').trim();
        if (rawRef.isNotEmpty && rawRef.toLowerCase() != 'null' && rawRef.toLowerCase() != 'none') {
          buffer.writeln('  📌 Ref: $rawRef');
        }
      }
      buffer.writeln();
    }

    if (_planGenerado!['consejos_instructor'] != null) {
      buffer.writeln('💡 *Tip Pedagógico:* ${_planGenerado!['consejos_instructor']}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 ¡Plan copiado al portapapeles listo para WhatsApp!'),
        backgroundColor: GingaColors.brandGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      child: Column(
        children: [
          // ── Manija superior ──
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Encabezado ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GingaColors.brandGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: GingaColors.brandGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _planGenerado != null ? 'Plan de Clase Generado' : '✨ Armar Clase con IA',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _planGenerado != null
                            ? 'Listo para enseñar o compartir'
                            : 'Genera un guión estructurado con tus ideas',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: _kTextoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _kTextoSecundario),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: _kBordeOscuro, height: 1),

          // ── Contenido ──
          Expanded(
            child: _cargando
                ? _buildCargando()
                : _error != null
                    ? _buildError()
                    : _planGenerado != null
                        ? _buildPlanResultado()
                        : _buildFormulario(),
          ),
        ],
      ),
    );
  }

  Widget _buildCargando() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GingaColors.brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: GingaColors.brandGreen.withValues(alpha: 0.3)),
              ),
              child: const CircularProgressIndicator(
                color: GingaColors.brandGreen,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Diseñando tu clase...',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La IA está revisando tus recursos e ideas guardadas para armar la mejor combinación pedagógica.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: _kTextoSecundario,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Ocurrió un problema',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: _kTextoSecundario, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generarPlan,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Nivel ──
        Text(
          '1. ¿Para quién es la clase?',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _niveles.map((niv) {
            final isSel = _nivel == niv;
            return ChoiceChip(
              label: Text(niv),
              selected: isSel,
              selectedColor: GingaColors.brandGreen,
              backgroundColor: _kFondoOscuro,
              labelStyle: GoogleFonts.montserrat(
                fontSize: 12.5,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? Colors.white : _kTextoSecundario,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GingaRadius.md),
                side: BorderSide(color: isSel ? GingaColors.brandGreen : _kBordeOscuro),
              ),
              onSelected: (val) => setState(() => _nivel = niv),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ── Duración ──
        Text(
          '2. Duración de la sesión',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _duraciones.map((dur) {
            final isSel = _duracion == dur;
            return ChoiceChip(
              label: Text('$dur min'),
              selected: isSel,
              selectedColor: GingaColors.brandGreen,
              backgroundColor: _kFondoOscuro,
              labelStyle: GoogleFonts.montserrat(
                fontSize: 12.5,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? Colors.white : _kTextoSecundario,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GingaRadius.md),
                side: BorderSide(color: isSel ? GingaColors.brandGreen : _kBordeOscuro),
              ),
              onSelected: (val) => setState(() => _duracion = dur),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ── Enfoque Temático ──
        Text(
          '3. Enfoque temático',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _enfoques.map((enf) {
            final isSel = _enfoque == enf;
            return ChoiceChip(
              label: Text(enf),
              selected: isSel,
              selectedColor: GingaColors.brandGreen,
              backgroundColor: _kFondoOscuro,
              labelStyle: GoogleFonts.montserrat(
                fontSize: 12.5,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? Colors.white : _kTextoSecundario,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GingaRadius.md),
                side: BorderSide(color: isSel ? GingaColors.brandGreen : _kBordeOscuro),
              ),
              onSelected: (val) => setState(() => _enfoque = enf),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ── Detalle / Notas Opcionales ──
        Text(
          '4. Notas o ejercicios específicos (Opcional)',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Indica si quieres trabajar alguna técnica concreta (ej. esquiva lateral, queixada, rolé, etc.)',
          style: GoogleFonts.montserrat(fontSize: 11, color: _kTextoSecundario),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notasCtrl,
          maxLines: 2,
          style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ej: Trabajar esquiva en parejas y enlazar con patada circular...',
            hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundario),
            filled: true,
            fillColor: _kFondoOscuro,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GingaRadius.md),
              borderSide: const BorderSide(color: _kBordeOscuro),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GingaRadius.md),
              borderSide: const BorderSide(color: GingaColors.brandGreen),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Selector de Recursos de la Pizarra ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '4. Drills o Clips a integrar (${_ideasSeleccionadasIds.length} seleccionados)',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (_ideasMap.isNotEmpty)
              PopupMenuButton<String>(
                color: _kTarjetaOscura,
                icon: const Icon(Icons.more_vert, color: _kTextoSecundario, size: 20),
                onSelected: (val) {
                  setState(() {
                    if (val == 'nuevos') {
                      _ideasSeleccionadasIds = _ideasMap.entries
                          .where((e) {
                            final d = e.value;
                            final bool completado = d['completado'] == true;
                            final cl = d['clase_usada'] as String?;
                            final int v = (d['veces_usada'] as num?)?.toInt() ?? 0;
                            final bool usada = (cl != null && cl.trim().isNotEmpty) || v > 0;
                            return !completado && !usada;
                          })
                          .map((e) => e.key)
                          .toSet();
                    } else if (val == 'todos') {
                      _ideasSeleccionadasIds = _ideasMap.keys.toSet();
                    } else if (val == 'limpiar') {
                      _ideasSeleccionadasIds.clear();
                    }
                  });
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'nuevos',
                    child: Text('✨ Seleccionar solo Nuevos', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12.5)),
                  ),
                  PopupMenuItem(
                    value: 'todos',
                    child: Text('Seleccionar Todos', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12.5)),
                  ),
                  PopupMenuItem(
                    value: 'limpiar',
                    child: Text('Limpiar selección', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12.5)),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Elige qué ejercicios quieres que la IA incorpore en la clase. Puedes ver cuáles son nuevos ✨ y cuáles ya has utilizado antes 🥋:',
          style: GoogleFonts.montserrat(fontSize: 11, color: _kTextoSecundario, height: 1.3),
        ),
        const SizedBox(height: 10),
        if (_ideasMap.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kFondoOscuro,
              borderRadius: BorderRadius.circular(GingaRadius.md),
              border: Border.all(color: _kBordeOscuro),
            ),
            child: Text(
              'Aún no tienes ideas en tu pizarra. La IA creará una sesión desde cero con ejercicios técnicos recomendados.',
              style: GoogleFonts.montserrat(fontSize: 11.5, color: _kTextoSecundario),
            ),
          )
        else
          SizedBox(
            height: 135,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _ideasMap.length,
              itemBuilder: (ctx, index) {
                final entry = _ideasMap.entries.elementAt(index);
                final id = entry.key;
                final idea = entry.value;
                final isSelected = _ideasSeleccionadasIds.contains(id);
                final titulo = idea['titulo'] as String? ?? 'Ejercicio';
                final clUsada = idea['clase_usada'] as String?;
                final vUsada = (idea['veces_usada'] as num?)?.toInt() ?? 0;
                final bool yaUsada = (clUsada != null && clUsada.trim().isNotEmpty) || vUsada > 0;
                final thumb = idea['thumbnail_url'] as String?;

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _ideasSeleccionadasIds.remove(id);
                      } else {
                        _ideasSeleccionadasIds.add(id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 170,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? GingaColors.brandGreen.withValues(alpha: 0.12) : _kFondoOscuro,
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(
                        color: isSelected ? GingaColors.brandGreen : _kBordeOscuro,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: yaUsada
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: GingaColors.accentAmber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        vUsada > 1 ? 'Usado $vUsada veces' : 'En plan: ${clUsada ?? "Clase"}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: GingaColors.accentAmber,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '✨ Nuevo',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF00E676),
                                        ),
                                      ),
                                    ),
                            ),
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: isSelected ? GingaColors.brandGreen : _kTextoSecundario,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            titulo,
                            style: GoogleFonts.montserrat(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.25,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thumb != null && thumb.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.image, size: 12, color: _kTextoSecundario),
                              const SizedBox(width: 4),
                              Text('Con clip', style: GoogleFonts.montserrat(fontSize: 9.5, color: _kTextoSecundario)),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),

        // ── Tarjeta Informativa sobre el buzón ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kFondoOscuro,
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(color: _kBordeOscuro),
          ),
          child: Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, color: GingaColors.accentAmber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La IA integrará de forma prioritaria los videos, reels y notas de tu Pizarra en los bloques de la clase.',
                  style: GoogleFonts.montserrat(fontSize: 11.5, color: _kTextoSecundario, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Botón Generar ──
        ElevatedButton.icon(
          onPressed: _generarPlan,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('✨ Generar Guión de Clase'),
          style: ElevatedButton.styleFrom(
            backgroundColor: GingaColors.brandGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GingaRadius.md),
            ),
            textStyle: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlanResultado() {
    if (_editando) {
      return _buildEditorPlan();
    }

    final titulo = _planGenerado!['titulo'] ?? 'Clase de Entrenamiento';
    final objetivo = _planGenerado!['objetivo'] ?? '';
    final duracionTotal = _planGenerado!['duracion_total'] ?? _duracion;
    final bloques = _planGenerado!['bloques'] as List? ?? [];
    final consejos = _planGenerado!['consejos_instructor'] as String?;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              // ── Header de la clase ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A2F), Color(0xFF13221C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: GingaColors.brandGreen.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: GingaColors.brandGreen,
                            borderRadius: BorderRadius.circular(GingaRadius.full),
                          ),
                          child: Text(
                            '$duracionTotal MIN',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(GingaRadius.full),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _nivel,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _iniciarEdicion,
                          borderRadius: BorderRadius.circular(GingaRadius.full),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                              border: Border.all(color: Colors.white30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Editar Plan',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      titulo,
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (objetivo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '🎯 $objetivo',
                        style: GoogleFonts.montserrat(
                          fontSize: 12.5,
                          color: _kTextoSecundario,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Bloques de la clase ──
              ...bloques.map((b) {
                final bloque = Map<String, dynamic>.from(b as Map);
                final fase = bloque['fase'] ?? 'Bloque';
                final duracionMin = bloque['duracion_min'] ?? 0;
                final ejercicios = bloque['ejercicios'] as List? ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kFondoOscuro,
                    borderRadius: BorderRadius.circular(GingaRadius.lg),
                    border: Border.all(color: _kBordeOscuro),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header del Bloque
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              fase,
                              style: GoogleFonts.montserrat(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: GingaColors.brandGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                            ),
                            child: Text(
                              '$duracionMin min',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.brandGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Ejercicios
                      ...ejercicios.map((e) {
                        final ej = Map<String, dynamic>.from(e as Map);
                        final nombre = ej['nombre'] ?? '';
                        final detalle = ej['detalle'] ?? '';
                        final rawRecurso = ej['recurso_relacionado'];
                        final recursoStr = (rawRecurso is String ? rawRecurso : '').trim();
                        final esRecursoValido = recursoStr.isNotEmpty &&
                            recursoStr.toLowerCase() != 'null' &&
                            recursoStr.toLowerCase() != 'none';

                        final ideaVinculada = _buscarIdeaParaEjercicio(
                          ejercicio: ej,
                          ideasMap: _ideasMap,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: GingaColors.brandGreen, fontSize: 16)),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12.5,
                                          color: Colors.white,
                                          height: 1.35,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '$nombre: ',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          TextSpan(
                                            text: detalle,
                                            style: const TextStyle(color: _kTextoSecundario),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (ideaVinculada != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 14),
                                  child: _EjercicioRecursoMiniaturaWidget(
                                    ideaData: ideaVinculada,
                                    fallbackTitulo: esRecursoValido ? recursoStr : nombre,
                                  ),
                                )
                              else if (esRecursoValido)
                                Padding(
                                  padding: const EdgeInsets.only(left: 14, top: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: GingaColors.accentAmber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.push_pin, size: 12, color: GingaColors.accentAmber),
                                        const SizedBox(width: 4),
                                        Text(
                                          'De tu pizarra: $recursoStr',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: GingaColors.accentAmber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),

              // ── Consejos del instructor ──
              if (consejos != null && consejos.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GingaColors.accentAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    border: Border.all(color: GingaColors.accentAmber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: GingaColors.accentAmber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          consejos,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),

        // ── Botones de acción inferiores ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: _kTarjetaOscura,
            border: Border(top: BorderSide(color: _kBordeOscuro)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Principal: Iniciar Clase en Vivo
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    String? planId = _savedPlanId;
                    if (!_planGuardado && _planGenerado != null) {
                      try {
                        final ref = await FirebaseFirestore.instance.collection('instructor_planes_clase').add({
                          'instructor_id': widget.uid,
                          'titulo': _planGenerado!['titulo'],
                          'duracion_total': _planGenerado!['duracion_total'],
                          'objetivo': _planGenerado!['objetivo'],
                          'bloques': _planGenerado!['bloques'],
                          'consejos_instructor': _planGenerado!['consejos_instructor'],
                          'nivel': _nivel,
                          'enfoque': _enfoque,
                          'created_at': FieldValue.serverTimestamp(),
                        });
                        planId = ref.id;
                        _savedPlanId = planId;
                        _planGuardado = true;
                      } catch (e) {
                        debugPrint('Error auto-guardando plan: $e');
                      }
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ClaseEnVivoScreen(
                          planId: planId,
                          planData: _planGenerado!,
                          uid: widget.uid,
                          ideasInstructor: _ideasMap,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                  label: const Text('Iniciar Clase en Vivo ⏱️'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GingaColors.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                    ),
                    textStyle: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  // Editar
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _iniciarEdicion,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _kBordeOscuro),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Copiar
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copiarAlPortapapeles,
                      icon: const Icon(Icons.copy, size: 15),
                      label: const Text('Copiar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _kBordeOscuro),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Guardar
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _planGuardado ? null : _guardarEnFirestore,
                      icon: _guardandoPlan
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(_planGuardado ? Icons.check : Icons.bookmark_border, size: 16),
                      label: Text(_planGuardado ? 'Guardado' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _planGuardado ? Colors.grey[800] : GingaColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Regenerar
                  IconButton(
                    onPressed: () => setState(() => _planGenerado = null),
                    icon: const Icon(Icons.refresh, color: _kTextoSecundario),
                    tooltip: 'Regenerar o ajustar',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  TARJETA DE PLAN DE CLASE GUARDADO
// ─────────────────────────────────────────
class _PlanClaseCard extends StatelessWidget {
  final String planId;
  final Map<String, dynamic> data;
  final String? uid;
  final VoidCallback onVerFicha;
  final VoidCallback onIniciarClase;
  final VoidCallback onDelete;

  const _PlanClaseCard({
    required this.planId,
    required this.data,
    required this.uid,
    required this.onVerFicha,
    required this.onIniciarClase,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = data['titulo'] ?? 'Clase de Capoeira';
    final duracion = data['duracion_total'] ?? 60;
    final nivel = data['nivel'] ?? 'Adultos';
    final enfoque = data['enfoque'] ?? 'Técnica & Movilidad';
    final objetivo = data['objetivo'] ?? '';
    final bloques = data['bloques'] as List? ?? [];
    final vecesImpartida = (data['veces_impartida'] as num?)?.toInt() ?? 0;

    // Fecha formateada
    String fechaStr = '';
    if (data['created_at'] is Timestamp) {
      final dt = (data['created_at'] as Timestamp).toDate();
      fechaStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: _kBordeOscuro),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header superior ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(GingaRadius.lg)),
              border: const Border(bottom: BorderSide(color: _kBordeOscuro)),
            ),
            child: Row(
              children: [
                // Duración
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GingaColors.brandGreen,
                    borderRadius: BorderRadius.circular(GingaRadius.full),
                  ),
                  child: Text(
                    '$duracion MIN',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nivel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _publicoColor(nivel).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(GingaRadius.full),
                  ),
                  child: Text(
                    nivel,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _publicoColor(nivel),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Enfoque
                Expanded(
                  child: Text(
                    enfoque,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _kTextoSecundario,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Fecha
                if (fechaStr.isNotEmpty)
                  Text(
                    fechaStr,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _kTextoSecundario.withValues(alpha: 0.7),
                    ),
                  ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: _kTextoSecundario),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Eliminar plan',
                ),
              ],
            ),
          ),

          // ── Cuerpo del Plan ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (objetivo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🎯 $objetivo',
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      color: _kTextoSecundario,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Resumen de fases/bloques
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: bloques.map((b) {
                    final bm = Map<String, dynamic>.from(b as Map);
                    final fase = bm['fase'] ?? 'Bloque';
                    final min = bm['duracion_min'] ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kFondoOscuro,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: _kBordeOscuro),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: _faseColor(fase)),
                          const SizedBox(width: 5),
                          Text(
                            '$fase ($min m)',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                if (vecesImpartida > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: GingaColors.brandGreen),
                      const SizedBox(width: 4),
                      Text(
                        'Impartida $vecesImpartida ${vecesImpartida == 1 ? "vez" : "veces"} en vivo',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: GingaColors.brandGreen,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // ── Botones de Acción ──
                Row(
                  children: [
                    // Botón Iniciar Clase en Vivo
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: onIniciarClase,
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                        label: const Text('Iniciar Clase ⏱️'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                          ),
                          textStyle: GoogleFonts.montserrat(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Botón Ver Ficha / Copiar
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: onVerFicha,
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Ver Ficha'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _kBordeOscuro),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                          ),
                          textStyle: GoogleFonts.montserrat(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  PANTALLA: CLASE EN VIVO (ASISTENTE EN TATAMI)
// ─────────────────────────────────────────
class _ClaseEnVivoScreen extends StatefulWidget {
  final String? planId;
  final Map<String, dynamic> planData;
  final String? uid;
  final Map<String, Map<String, dynamic>>? ideasInstructor;

  const _ClaseEnVivoScreen({
    this.planId,
    required this.planData,
    required this.uid,
    this.ideasInstructor,
  });

  @override
  State<_ClaseEnVivoScreen> createState() => _ClaseEnVivoScreenState();
}

class _ClaseEnVivoScreenState extends State<_ClaseEnVivoScreen> {
  late List<Map<String, dynamic>> _bloques;
  int _bloqueActual = 0;
  int _segundosRestantes = 0;
  int _segundosTotalesBloque = 0;
  bool _isCorriendo = false;
  Timer? _timer;
  int _totalTranscurridoSeg = 0;
  final Set<String> _ejerciciosCompletados = {}; // 'bIndex_eIndex'
  Map<String, Map<String, dynamic>> _ideasInstructor = {};

  @override
  void initState() {
    super.initState();
    final rawBloques = widget.planData['bloques'] as List? ?? [];
    _bloques = rawBloques.map((b) => Map<String, dynamic>.from(b as Map)).toList();
    _iniciarBloque(0);
    if (widget.ideasInstructor != null && widget.ideasInstructor!.isNotEmpty) {
      _ideasInstructor = Map.from(widget.ideasInstructor!);
    } else {
      _cargarIdeasInstructor();
    }
    // Auto-iniciar el cronómetro al entrar para que corra de inmediato
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isCorriendo) {
        _toggleTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarBloque(int index) {
    if (index < 0 || index >= _bloques.length) return;
    _bloqueActual = index;
    final durMin = (_bloques[index]['duracion_min'] as num?)?.toInt() ?? 10;
    _segundosRestantes = durMin * 60;
    _segundosTotalesBloque = _segundosRestantes;
  }

  Future<void> _cargarIdeasInstructor() async {
    if (widget.uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('instructor_ideas')
          .where('instructor_id', isEqualTo: widget.uid)
          .get();
      final map = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        map[doc.id] = doc.data();
      }
      if (mounted) {
        setState(() {
          _ideasInstructor = map;
        });
      }
    } catch (e) {
      debugPrint('Error cargando ideas para asistente en vivo: $e');
    }
  }

  void _toggleTimer() {
    if (_isCorriendo) {
      _timer?.cancel();
      setState(() => _isCorriendo = false);
    } else {
      setState(() => _isCorriendo = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _totalTranscurridoSeg++;
          if (_segundosRestantes > 0) {
            _segundosRestantes--;
          } else {
            _timer?.cancel();
            _isCorriendo = false;
            HapticFeedback.heavyImpact();
            _mostrarAvisoFinBloque();
          }
        });
      });
    }
  }

  void _ajustarTiempo(int deltaSegundos) {
    setState(() {
      final nuevo = _segundosRestantes + deltaSegundos;
      _segundosRestantes = nuevo < 0 ? 0 : nuevo;
      if (deltaSegundos > 0) {
        _segundosTotalesBloque += deltaSegundos;
      }
    });
  }

  void _reiniciarBloqueActual() {
    setState(() {
      _timer?.cancel();
      _isCorriendo = false;
      final durMin = (_bloques[_bloqueActual]['duracion_min'] as num?)?.toInt() ?? 10;
      _segundosRestantes = durMin * 60;
      _segundosTotalesBloque = _segundosRestantes;
    });
  }

  void _cambiarABloque(int index) {
    if (index < 0 || index >= _bloques.length) return;
    final wasRunning = _isCorriendo;
    setState(() {
      _timer?.cancel();
      _iniciarBloque(index);
      if (wasRunning) {
        _isCorriendo = false;
        _toggleTimer();
      }
    });
  }

  void _mostrarAvisoFinBloque() {
    final fase = _bloques[_bloqueActual]['fase'] ?? 'Bloque';
    final hasNext = _bloqueActual < _bloques.length - 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.alarm_on, color: GingaColors.accentAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '¡Tiempo cumplido de "$fase"! ${hasNext ? "¿Pasamos a la siguiente fase?" : "¡Última fase completada!"}',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: hasNext
            ? SnackBarAction(
                label: 'Siguiente Bloque',
                textColor: GingaColors.brandGreen,
                onPressed: () => _cambiarABloque(_bloqueActual + 1),
              )
            : null,
        backgroundColor: _kTarjetaOscura,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  List<Map<String, dynamic>> _obtenerIdeasUtilizadasEnElPlan() {
    final List<Map<String, dynamic>> encontradas = [];
    final Set<String> idsAgregados = {};

    for (final b in _bloques) {
      final ejercicios = b['ejercicios'] as List? ?? [];
      for (final ej in ejercicios) {
        final ejMap = Map<String, dynamic>.from(ej as Map);
        final idea = _buscarIdeaParaEjercicio(ejercicio: ejMap, ideasMap: _ideasInstructor);
        if (idea != null) {
          for (final entry in _ideasInstructor.entries) {
            if (entry.value == idea && !idsAgregados.contains(entry.key)) {
              idsAgregados.add(entry.key);
              encontradas.add({
                'id': entry.key,
                'titulo': idea['titulo'] ?? 'Ejercicio de Pizarra',
                'completado': idea['completado'] == true,
                'url': idea['url'],
              });
              break;
            }
          }
        }
      }
    }
    return encontradas;
  }

  Future<void> _abrirDialogoFinalizarClase() async {
    final ideasDetectadas = _obtenerIdeasUtilizadasEnElPlan();
    final Map<String, bool> seleccionados = {
      for (final item in ideasDetectadas) item['id'] as String: true,
    };

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: _kTarjetaOscura,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GingaRadius.xl),
                side: const BorderSide(color: _kBordeOscuro),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flag_rounded, color: GingaColors.brandGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Finalizar Sesión',
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Excelente entrenamiento! Has estado en sesión por ${(_totalTranscurridoSeg / 60).floor()} minutos.',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: _kTextoSecundario,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (ideasDetectadas.isNotEmpty) ...[
                      Text(
                        'Marcar ejercicios como "Ya Enseñados":',
                        style: GoogleFonts.montserrat(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Se registrarán con la etiqueta "🥋 En plan" en tu Pizarra para que lleves el historial de lo impartido, manteniéndose siempre listos para volver a enseñarse.',
                        style: GoogleFonts.montserrat(
                          fontSize: 11.5,
                          color: _kTextoSecundario,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: _kFondoOscuro,
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: _kBordeOscuro),
                        ),
                        child: Column(
                          children: ideasDetectadas.map((item) {
                            final id = item['id'] as String;
                            final titulo = item['titulo'] as String;
                            final isChecked = seleccionados[id] ?? false;

                            return CheckboxListTile(
                              value: isChecked,
                              dense: true,
                              activeColor: GingaColors.brandGreen,
                              checkColor: Colors.black,
                              title: Text(
                                titulo,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  seleccionados[id] = val ?? false;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kFondoOscuro,
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: _kBordeOscuro),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: _kTextoSecundario),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No se detectaron recursos específicos de tu Pizarra vinculados a este plan.',
                                style: GoogleFonts.montserrat(fontSize: 11.5, color: _kTextoSecundario),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(
                    'Seguir en Clase',
                    style: GoogleFonts.montserrat(color: _kTextoSecundario),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GingaColors.brandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Finalizar y Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final tituloPlan = widget.planData['titulo'] ?? 'Clase de Capoeira';

      for (final entry in seleccionados.entries) {
        if (entry.value) {
          final docRef = FirebaseFirestore.instance.collection('instructor_ideas').doc(entry.key);
          batch.update(docRef, {
            'completado': true,
            'fecha_ultimo_uso': FieldValue.serverTimestamp(),
            'clase_usada': tituloPlan,
            'clases_asociadas': FieldValue.arrayUnion([tituloPlan]),
            'veces_usada': FieldValue.increment(1),
          });
        }
      }

      if (widget.planId != null) {
        final planRef = FirebaseFirestore.instance.collection('instructor_planes_clase').doc(widget.planId);
        batch.update(planRef, {
          'ultima_ejecucion': FieldValue.serverTimestamp(),
          'veces_impartida': FieldValue.increment(1),
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🥋 ¡Clase finalizada con éxito! Recursos actualizados en tu Pizarra.'),
          backgroundColor: GingaColors.brandGreen,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando finalización: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatearTiempo(int totalSegundos) {
    final minutos = totalSegundos ~/ 60;
    final segundos = totalSegundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  Color _obtenerColorTimer() {
    if (_segundosTotalesBloque == 0) return GingaColors.brandGreen;
    final pct = _segundosRestantes / _segundosTotalesBloque;
    if (pct > 0.4) return GingaColors.brandGreen;
    if (pct > 0.15) return GingaColors.accentAmber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_bloques.isEmpty) {
      return Scaffold(
        backgroundColor: _kFondoOscuro,
        appBar: AppBar(backgroundColor: _kTarjetaOscura),
        body: const Center(
          child: Text('El plan no contiene bloques válidos', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final bloqueActualData = _bloques[_bloqueActual];
    final fase = bloqueActualData['fase'] ?? 'Fase Actual';
    final ejercicios = bloqueActualData['ejercicios'] as List? ?? [];
    final tituloPlan = widget.planData['titulo'] ?? 'Clase en Vivo';
    final nivel = widget.planData['nivel'] ?? 'Adultos';
    final duracionTotalMin = widget.planData['duracion_total'] ?? 60;

    final minutosTranscurridos = _totalTranscurridoSeg ~/ 60;
    final pctBloque = _segundosTotalesBloque > 0
        ? (1.0 - (_segundosRestantes / _segundosTotalesBloque)).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: _kFondoOscuro,
      appBar: AppBar(
        backgroundColor: _kTarjetaOscura,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isCorriendo) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _kTarjetaOscura,
                  title: const Text('¿Salir de la clase en vivo?', style: TextStyle(color: Colors.white)),
                  content: const Text('El temporizador se detendrá.', style: TextStyle(color: _kTextoSecundario)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Quedarse')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tituloPlan,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Text(
                  '$nivel • $duracionTotalMin min',
                  style: GoogleFonts.montserrat(fontSize: 11, color: _kTextoSecundario),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Transcurrido: $minutosTranscurridos min',
                  style: GoogleFonts.montserrat(fontSize: 11, color: GingaColors.brandGreen),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _abrirDialogoFinalizarClase,
            icon: const Icon(Icons.flag_rounded, color: GingaColors.brandGreen, size: 18),
            label: Text(
              'Finalizar',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                color: GingaColors.brandGreen,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra Stepper de Fases/Bloques ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _kTarjetaOscura,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_bloques.length, (i) {
                    final b = _bloques[i];
                    final isActivo = i == _bloqueActual;
                    final isPasado = i < _bloqueActual;
                    final faseName = b['fase'] ?? 'Bloque ${i + 1}';
                    final bDur = b['duracion_min'] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => _cambiarABloque(i),
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActivo
                                ? GingaColors.brandGreen.withValues(alpha: 0.2)
                                : (isPasado ? Colors.white.withValues(alpha: 0.04) : _kFondoOscuro),
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(
                              color: isActivo
                                  ? GingaColors.brandGreen
                                  : (isPasado ? GingaColors.brandGreen.withValues(alpha: 0.4) : _kBordeOscuro),
                              width: isActivo ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPasado)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.check, size: 14, color: GingaColors.brandGreen),
                                )
                              else if (isActivo)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                    color: GingaColors.brandGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                '${i + 1}. $faseName (${bDur}m)',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11.5,
                                  fontWeight: isActivo ? FontWeight.w800 : FontWeight.w500,
                                  color: isActivo
                                      ? Colors.white
                                      : (isPasado ? Colors.white70 : _kTextoSecundario),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ── Bloque Principal: Timer Gigante + Ejercicios Scrollables ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // ── Tarjeta del Temporizador Gigante ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _obtenerColorTimer().withValues(alpha: 0.14),
                          _kTarjetaOscura,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(GingaRadius.xl),
                      border: Border.all(
                        color: _obtenerColorTimer().withValues(alpha: 0.5),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _obtenerColorTimer().withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Encabezado del bloque: Fase + Badge Estado EN VIVO / EN PAUSA
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.sports_kabaddi, size: 16, color: _obtenerColorTimer()),
                                const SizedBox(width: 8),
                                Text(
                                  fase.toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: _obtenerColorTimer(),
                                  ),
                                ),
                              ],
                            ),
                            // Badge Estado
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isCorriendo
                                    ? GingaColors.brandGreen.withValues(alpha: 0.2)
                                    : GingaColors.accentAmber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isCorriendo ? GingaColors.brandGreen : GingaColors.accentAmber,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _isCorriendo ? GingaColors.brandGreen : GingaColors.accentAmber,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isCorriendo ? 'EN VIVO' : 'EN PAUSA',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: _isCorriendo ? GingaColors.brandGreen : GingaColors.accentAmber,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Reloj Digital Gigante (Táctil para pausar/reanudar)
                        InkWell(
                          onTap: _toggleTimer,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                Text(
                                  _formatearTiempo(_segundosRestantes),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 58,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isCorriendo ? Icons.touch_app_outlined : Icons.play_circle_outline,
                                      size: 13,
                                      color: _kTextoSecundario,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isCorriendo ? 'Toca los números para pausar' : 'Toca los números para reanudar',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: _kTextoSecundario,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Barra de progreso del bloque
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pctBloque,
                            minHeight: 6,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(_obtenerColorTimer()),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Controles Táctiles Rápidos ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // -1 min
                            OutlinedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _ajustarTiempo(-60);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: _kBordeOscuro),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              child: Text(
                                '-1 m',
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Botón Central PLAY / PAUSA con TEXTO CLARO
                            ElevatedButton.icon(
                              onPressed: _toggleTimer,
                              icon: Icon(
                                _isCorriendo ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 24,
                                color: _isCorriendo ? Colors.black : Colors.white,
                              ),
                              label: Text(
                                _isCorriendo ? 'PAUSAR' : 'REANUDAR',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: _isCorriendo ? Colors.black : Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isCorriendo ? GingaColors.brandGreen : GingaColors.accentAmber,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.full),
                                ),
                                elevation: 4,
                                shadowColor: (_isCorriendo ? GingaColors.brandGreen : GingaColors.accentAmber).withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // +1 min
                            OutlinedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _ajustarTiempo(60);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: _kBordeOscuro),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              child: Text(
                                '+1 m',
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Reset
                            IconButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _reiniciarBloqueActual();
                              },
                              icon: const Icon(Icons.replay, color: _kTextoSecundario, size: 22),
                              tooltip: 'Reiniciar tiempo del bloque',
                            ),
                          ],
                        ),

                        // Botón de paso a la siguiente fase si el tiempo concluyó
                        if (_segundosRestantes == 0 && _bloqueActual < _bloques.length - 1) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _cambiarABloque(_bloqueActual + 1),
                              icon: const Icon(Icons.skip_next_rounded, size: 20),
                              label: Text(
                                'Pasar a: ${_bloques[_bloqueActual + 1]["fase"] ?? "Siguiente Fase"} ⏭',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GingaColors.brandGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Encabezado de Ejercicios ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ejercicios & Drills de la Fase',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_ejerciciosCompletados.where((k) => k.startsWith("${_bloqueActual}_")).length} de ${ejercicios.length} listos',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: _kTextoSecundario,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Lista de Ejercicios del Bloque Actual ──
                  ...List.generate(ejercicios.length, (idx) {
                    final ej = Map<String, dynamic>.from(ejercicios[idx] as Map);
                    final nombre = ej['nombre'] ?? 'Ejercicio';
                    final detalle = ej['detalle'] ?? '';
                    final key = '${_bloqueActual}_$idx';
                    final isChecked = _ejerciciosCompletados.contains(key);

                    // Buscar recurso o video vinculado en la pizarra
                    final ideaVinculada = _buscarIdeaParaEjercicio(
                      ejercicio: ej,
                      ideasMap: _ideasInstructor,
                    );

                    final rawRecurso = ej['recurso_relacionado'];
                    final recursoStr = (rawRecurso is String ? rawRecurso : '').trim();
                    final esRecursoValido = recursoStr.isNotEmpty &&
                        recursoStr.toLowerCase() != 'null' &&
                        recursoStr.toLowerCase() != 'none';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isChecked ? _kTarjetaOscura.withValues(alpha: 0.6) : _kTarjetaOscura,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(
                          color: isChecked ? GingaColors.brandGreen.withValues(alpha: 0.4) : _kBordeOscuro,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Checkbox grande para marcar durante la clase
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isChecked) {
                                        _ejerciciosCompletados.remove(key);
                                      } else {
                                        _ejerciciosCompletados.add(key);
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    margin: const EdgeInsets.only(top: 2, right: 12),
                                    decoration: BoxDecoration(
                                      color: isChecked ? GingaColors.brandGreen : Colors.transparent,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: isChecked ? GingaColors.brandGreen : _kTextoSecundario,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: isChecked
                                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                                        : null,
                                  ),
                                ),
                                // Título y Detalle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isChecked ? _kTextoSecundario : Colors.white,
                                          decoration: isChecked ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      if (detalle.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          detalle,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12.5,
                                            color: _kTextoSecundario,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // ── Miniatura Visual de Video de TikTok / Instagram / YouTube ──
                            if (ideaVinculada != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 38),
                                child: _EjercicioRecursoMiniaturaWidget(
                                  ideaData: ideaVinculada,
                                  fallbackTitulo: esRecursoValido ? recursoStr : nombre,
                                ),
                              ),
                            ] else if (esRecursoValido) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 38, top: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: GingaColors.accentAmber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.push_pin, size: 12, color: GingaColors.accentAmber),
                                      const SizedBox(width: 4),
                                      Text(
                                        'De tu pizarra: $recursoStr',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: GingaColors.accentAmber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  // ── Vista previa de la siguiente fase ──
                  if (_bloqueActual < _bloques.length - 1) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: _kBordeOscuro),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.skip_next_rounded, size: 18, color: _kTextoSecundario),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Siguiente fase: ${_bloques[_bloqueActual + 1]['fase'] ?? "Bloque"} (${_bloques[_bloqueActual + 1]['duracion_min']} min)',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: _kTextoSecundario,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _cambiarABloque(_bloqueActual + 1),
                            child: const Text('Saltar ahora', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Barra Inferior Fija de Navegación entre Bloques ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: _kTarjetaOscura,
                border: Border(top: BorderSide(color: _kBordeOscuro)),
              ),
              child: Row(
                children: [
                  // Botón Anterior
                  OutlinedButton.icon(
                    onPressed: _bloqueActual > 0
                        ? () => _cambiarABloque(_bloqueActual - 1)
                        : null,
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text('Anterior'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _kBordeOscuro),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Indicador de Fase
                  Text(
                    'Fase ${_bloqueActual + 1} de ${_bloques.length}',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextoSecundario,
                    ),
                  ),
                  const Spacer(),

                  // Botón Siguiente o Finalizar
                  if (_bloqueActual < _bloques.length - 1)
                    ElevatedButton.icon(
                      onPressed: () => _cambiarABloque(_bloqueActual + 1),
                      icon: const Icon(Icons.arrow_forward_ios, size: 14),
                      label: const Text('Siguiente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                        textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _abrirDialogoFinalizarClase,
                      icon: const Icon(Icons.flag_rounded, size: 16),
                      label: const Text('Finalizar 🏁'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.accentAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                        textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


