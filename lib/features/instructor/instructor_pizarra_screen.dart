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
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/ginga_theme.dart';

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

class InstructorPizarraScreen extends StatefulWidget {
  const InstructorPizarraScreen({super.key});

  @override
  State<InstructorPizarraScreen> createState() => _InstructorPizarraScreenState();
}

class _InstructorPizarraScreenState extends State<InstructorPizarraScreen> {
  String _filtroPublico = 'Todos';
  String _filtroFase = 'Todos';

  final List<String> _filtrosPublico = ['Todos', 'Adultos', 'Niños'];
  final List<String> _filtrosFase = [
    'Todos',
    'Calentamiento',
    'Técnica',
    'Acrobacias',
    'Juegos',
    'Roda',
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            children: [
          // ── Botón Destacado: Armar Clase con IA ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
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

          // ── Selector de Filtros (Grupo y Fase) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

                  final matchPublico = _filtroPublico == 'Todos' || pub == _filtroPublico || pub == 'Todos' || pub == 'Mixto';
                  final matchFase = _filtroFase == 'Todos' || fase.toLowerCase() == _filtroFase.toLowerCase();

                  return matchPublico && matchFase;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No hay ejercicios para Grupo: "$_filtroPublico" y Fase: "$_filtroFase"',
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
        ],
      ),
    ),
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
                if (tipo == 'link')
                  InkWell(
                    onTap: () => _abrirEnlace(context, url),
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

                // Botón si es Link (Reel / TikTok / YouTube)
                if (tipo == 'link' && url != null && url.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: InkWell(
                      onTap: () => _abrirEnlace(context, url),
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
        ),
      ],
    ),
  );
}


  Future<void> _abrirEnlace(BuildContext context, String? urlRaw) async {
    if (urlRaw == null || urlRaw.trim().isEmpty) return;
    var clean = urlRaw.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    try {
      final uri = Uri.parse(clean);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el enlace: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

// ─────────────────────────────────────────
//  MODAL: ARMAR CLASE CON IA (OPENAI / GEMINI)
// ─────────────────────────────────────────
class _GeneradorClaseModal extends StatefulWidget {
  final String? uid;
  const _GeneradorClaseModal({required this.uid});

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
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _generarPlan() async {
    setState(() {
      _cargando = true;
      _error = null;
      _planGuardado = false;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generarPlanClaseIA',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final result = await callable.call({
        'nivel': _nivel,
        'duracion': _duracion,
        'enfoque': _enfoque,
        'instrucciones_adicionales': _notasCtrl.text.trim(),
      });

      if (!mounted) return;
      setState(() {
        _planGenerado = Map<String, dynamic>.from(result.data as Map);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error generando el plan: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _guardarEnFirestore() async {
    if (_planGenerado == null || _planGuardado) return;
    setState(() => _guardandoPlan = true);

    try {
      await FirebaseFirestore.instance.collection('instructor_planes_clase').add({
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

      if (!mounted) return;
      setState(() {
        _guardandoPlan = false;
        _planGuardado = true;
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
        if (ejMap['recurso_relacionado'] != null) {
          buffer.writeln('  📌 Ref: ${ejMap['recurso_relacionado']}');
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
                        final recurso = ej['recurso_relacionado'] as String?;

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
                              if (recurso != null && recurso.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 14, top: 4),
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
                                          'De tu pizarra: $recurso',
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
          child: Row(
            children: [
              // Copiar
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copiarAlPortapapeles,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _kBordeOscuro),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(_planGuardado ? Icons.check : Icons.bookmark_border, size: 18),
                  label: Text(_planGuardado ? 'Guardado' : 'Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _planGuardado ? Colors.grey[800] : GingaColors.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
        ),
      ],
    );
  }
}

