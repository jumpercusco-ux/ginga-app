import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/ginga_theme.dart';

const Color _kFondoOscuro = Color(0xFF121212);
const Color _kTarjetaOscura = Color(0xFF1E1E1E);
const Color _kBordeOscuro = Color(0xFF2C2C2C);
const Color _kTextoSecundario = Color(0xFFA0A0A0);

class InstructorPizarraScreen extends StatefulWidget {
  const InstructorPizarraScreen({super.key});

  @override
  State<InstructorPizarraScreen> createState() => _InstructorPizarraScreenState();
}

class _InstructorPizarraScreenState extends State<InstructorPizarraScreen> {
  String _filtroCategoria = 'Todos';
  final List<String> _categorias = [
    'Todos',
    'Niños',
    'Adultos',
    'Acrobacias',
    'Calentamiento',
    'Roda'
  ];

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
              'Banco de ideas, videos y notas rápidas',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: _kTextoSecundario,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Selector de categorías ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _categorias.map((cat) {
                final isSelected = _filtroCategoria == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filtroCategoria = cat);
                      }
                    },
                    selectedColor: GingaColors.brandGreen,
                    backgroundColor: _kTarjetaOscura,
                    labelStyle: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : _kTextoSecundario,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                      side: BorderSide(
                        color: isSelected ? GingaColors.brandGreen : _kBordeOscuro,
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                  if (_filtroCategoria == 'Todos') return true;
                  return data['categoria'] == _filtroCategoria;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay ideas en "$_filtroCategoria"',
                      style: GoogleFonts.montserrat(color: _kTextoSecundario),
                    ),
                  );
                }

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
                      onDelete: () => _confirmarEliminar(doc.id, data['titulo'] ?? 'esta idea'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GingaColors.brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Nueva Idea',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        onPressed: () => _abrirModalCrearIdea(context),
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

  void _abrirModalCrearIdea(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalCrearIdea(uid: _uid),
    );
  }
}

// ─────────────────────────────────────────
//  MODAL PARA AGREGAR NUEVA IDEA / RECURSO
// ─────────────────────────────────────────
class _ModalCrearIdea extends StatefulWidget {
  final String? uid;
  const _ModalCrearIdea({required this.uid});

  @override
  State<_ModalCrearIdea> createState() => _ModalCrearIdeaState();
}

class _ModalCrearIdeaState extends State<_ModalCrearIdea> {
  final _tituloCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  String _tipo = 'link'; // 'link' | 'imagen' | 'texto'
  String _categoria = 'Niños';
  XFile? _imagenSeleccionada;
  Uint8List? _webImageBytes;
  bool _subiendo = false;

  final List<String> _categorias = ['Niños', 'Adultos', 'Acrobacias', 'Calentamiento', 'Roda'];

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
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe un título o nombre del movimiento')),
      );
      return;
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
        mediaUrl = _urlCtrl.text.trim();
      }

      await FirebaseFirestore.instance.collection('instructor_ideas').add({
        'titulo': titulo,
        'notas': _notasCtrl.text.trim(),
        'tipo': _tipo,
        'url': mediaUrl ?? '',
        'categoria': _categoria,
        'completado': false,
        'instructor_id': widget.uid ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Idea guardada en tu pizarra! 💡'),
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
                  'Nueva Idea de Entrenamiento',
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
            const SizedBox(height: 12),

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
              const SizedBox(height: 12),
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
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Categoría
            Text(
              'Categoría / Disciplina',
              style: GoogleFonts.montserrat(color: _kTextoSecundario, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _categorias.map((cat) {
                final isSelected = _categoria == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _categoria = cat);
                  },
                  selectedColor: GingaColors.brandGreen,
                  backgroundColor: _kFondoOscuro,
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: isSelected ? Colors.white : _kTextoSecundario,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

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
                        'Guardar en la Pizarra',
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
  final VoidCallback onDelete;

  const _IdeaCard({
    required this.id,
    required this.data,
    required this.onToggleCompletado,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completado = data['completado'] == true;
    final tipo = data['tipo'] ?? 'texto';
    final url = data['url'] as String?;
    final titulo = data['titulo'] ?? '';
    final notas = data['notas'] as String?;
    final categoria = data['categoria'] ?? 'General';

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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(
          color: completado ? GingaColors.brandGreen.withValues(alpha: 0.3) : _kBordeOscuro,
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
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 170,
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
                if (tipo == 'link')
                  InkWell(
                    onTap: () async {
                      if (url != null && url.isNotEmpty) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
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

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila superior: Chip de categoría + Botón de acción / eliminar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _categoriaColor(categoria).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                      child: Text(
                        categoria,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _categoriaColor(categoria),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: _kTextoSecundario),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

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

                // Botón si es Link (Reel / TikTok / YouTube)
                if (tipo == 'link' && url != null && url.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: InkWell(
                      onTap: () async {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
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
                            const Icon(Icons.open_in_new, size: 14, color: _kTextoSecundario),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _categoriaColor(String cat) {
    switch (cat) {
      case 'Niños':
        return GingaColors.brandGreen;
      case 'Adultos':
        return Colors.lightBlueAccent;
      case 'Acrobacias':
        return GingaColors.accentAmber;
      case 'Calentamiento':
        return Colors.orangeAccent;
      case 'Roda':
        return Colors.purpleAccent;
      default:
        return _kTextoSecundario;
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
}
