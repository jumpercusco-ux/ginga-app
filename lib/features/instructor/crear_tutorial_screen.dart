import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/tutoriales_service.dart';
import '../biblioteca/widgets/tutorial_thumbnail.dart';

class CrearTutorialScreen extends StatefulWidget {
  final String tutorialId;

  const CrearTutorialScreen({super.key, this.tutorialId = ''});

  @override
  State<CrearTutorialScreen> createState() => _CrearTutorialScreenState();
}

class _CrearTutorialScreenState extends State<CrearTutorialScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  // Controladores de texto
  final _tituloController = TextEditingController();
  final _duracionController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _tipMestreController = TextEditingController();
  final _tipErrorController = TextEditingController();

  // Variables de selectores
  String _selectedCategory = 'Fundamentos';
  String _selectedLevel = 'Iniciante';
  String _existingImageUrl = '';
  String _existingVideoUrl = '';
  bool _visible = true;

  // Selector de imagen y video
  File? _selectedImageFile;
  File? _selectedVideoFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categorias = ['Fundamentos', 'Ataques', 'Defensas', 'Esquivas', 'Floreos'];
  final List<String> _niveles = ['Iniciante', 'Graduado', 'Avanzado'];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.tutorialId.isNotEmpty;
    if (_isEditMode) {
      _cargarDatosTutorial();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _duracionController.dispose();
    _descripcionController.dispose();
    _tipMestreController.dispose();
    _tipErrorController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosTutorial() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tutoriales')
          .doc(widget.tutorialId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _tituloController.text = data['titulo'] ?? '';
          _duracionController.text = data['duracion'] ?? '6 min';
          _descripcionController.text = data['descripcion'] ?? '';
          _tipMestreController.text = data['tipMestre'] ?? '';
          _tipErrorController.text = data['tipError'] ?? '';
          _selectedCategory = data['categoria'] ?? 'Fundamentos';
          _selectedLevel = data['nivel'] ?? 'Iniciante';
          _existingImageUrl = data['imagen_url'] ?? '';
          _existingVideoUrl = data['video_url'] ?? '';
          _visible = data['visible'] ?? true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la lección: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarVideo() async {
    try {
      final pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (pickedFile != null) {
        setState(() {
          _selectedVideoFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar video: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _seleccionarImagen() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _guardarTutorial() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVideoFile == null && _existingVideoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona o sube un video demostrativo para esta lección 📽️'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String finalImageUrl = _existingImageUrl;
      String finalVideoUrl = _existingVideoUrl;

      // 1. Subir imagen a Firebase Storage si se seleccionó una nueva
      if (_selectedImageFile != null) {
        finalImageUrl = await TutorialesService.instance.subirPortadaTutorial(_selectedImageFile!);
      } else if (finalImageUrl.isEmpty) {
        // Fallback por defecto si se crea sin imagen de portada
        finalImageUrl = 'assets/images/placeholder_custom.jpg';
      }

      // 2. Subir video a Firebase Storage si se seleccionó uno nuevo
      if (_selectedVideoFile != null) {
        finalVideoUrl = await TutorialesService.instance.subirVideoTutorial(_selectedVideoFile!);
      }

      // 3. Guardar o actualizar en Firestore
      await TutorialesService.instance.crearOActualizarTutorial(
        id: _isEditMode ? widget.tutorialId : null,
        titulo: _tituloController.text.trim(),
        categoria: _selectedCategory,
        nivel: _selectedLevel,
        duracion: _duracionController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        tipMestre: _tipMestreController.text.trim(),
        tipError: _tipErrorController.text.trim(),
        imagenUrl: finalImageUrl,
        videoUrl: finalVideoUrl,
        visible: _visible,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Lección modificada con éxito ✏️'
                : '¡Nueva lección agregada a la biblioteca! 📽️'),
            backgroundColor: GingaColors.brandGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Editar Lección' : 'Crear Lección',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        backgroundColor: GingaColors.backgroundLight,
        elevation: 0,
        foregroundColor: GingaColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && _tituloController.text.isEmpty
          ? const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Selector de Video Demostrativo (Requerido) ──────────
                    _buildLabel('Video Demostrativo del Movimiento *'),
                    GestureDetector(
                      onTap: _seleccionarVideo,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedVideoFile != null || _existingVideoUrl.isNotEmpty
                              ? GingaColors.brandGreen.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(
                            color: _selectedVideoFile != null || _existingVideoUrl.isNotEmpty
                                ? GingaColors.brandGreen
                                : GingaColors.borderLight,
                            width: _selectedVideoFile != null || _existingVideoUrl.isNotEmpty ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedVideoFile != null || _existingVideoUrl.isNotEmpty
                                  ? Icons.video_camera_back_rounded
                                  : Icons.video_library_outlined,
                              size: 40,
                              color: _selectedVideoFile != null || _existingVideoUrl.isNotEmpty
                                  ? GingaColors.brandGreen
                                  : GingaColors.textSecondary.withOpacity(0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedVideoFile != null
                                  ? '¡Video Seleccionado!'
                                  : (_existingVideoUrl.isNotEmpty
                                      ? 'Video Cargado en la Nube'
                                      : 'Seleccionar Video Demostrativo'),
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedVideoFile != null || _existingVideoUrl.isNotEmpty
                                    ? GingaColors.brandGreen
                                    : GingaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedVideoFile != null
                                  ? _selectedVideoFile!.path.split('/').last
                                  : (_existingVideoUrl.isNotEmpty
                                      ? 'Toca para cambiar el video actual'
                                      : 'Sube un video en formato MP4 (máx. 10 min)'),
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: GingaColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Selector de Portada (Opcional) ─────────────────────
                    _buildLabel('Imagen de Portada / Miniatura (Opcional)'),
                    GestureDetector(
                      onTap: _seleccionarImagen,
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _selectedImageFile != null
                            ? Image.file(_selectedImageFile!, fit: BoxFit.cover)
                            : TutorialThumbnail(
                                imagenUrl: _existingImageUrl,
                                categoria: _selectedCategory,
                                titulo: _tituloController.text,
                                iconSize: 26,
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Título de la Lección
                    _buildLabel('Título del movimiento / lección *'),
                    TextFormField(
                      controller: _tituloController,
                      style: GoogleFonts.nunito(color: GingaColors.textPrimary),
                      decoration: _buildInputDecoration('Ej: Queixada, Armada, Cocorinha...'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Ingresa el nombre de la lección' : null,
                    ),
                    const SizedBox(height: 16),

                    // Fila de Categoría y Nivel
                    Row(
                      children: [
                        // Categoría
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Categoría *'),
                              DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                items: _categorias.map((cat) {
                                  return DropdownMenuItem(value: cat, child: Text(cat, style: GoogleFonts.nunito()));
                                }).toList(),
                                onChanged: (value) => setState(() => _selectedCategory = value!),
                                decoration: _buildInputDecoration(''),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Nivel
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Nivel *'),
                              DropdownButtonFormField<String>(
                                value: _selectedLevel,
                                items: _niveles.map((niv) {
                                  return DropdownMenuItem(value: niv, child: Text(niv, style: GoogleFonts.nunito()));
                                }).toList(),
                                onChanged: (value) => setState(() => _selectedLevel = value!),
                                decoration: _buildInputDecoration(''),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Duración
                    _buildLabel('Duración estimada de la práctica *'),
                    TextFormField(
                      controller: _duracionController,
                      style: GoogleFonts.nunito(color: GingaColors.textPrimary),
                      decoration: _buildInputDecoration('Ej: 6 min, 10 min, 15 min...'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Ingresa la duración estimada' : null,
                    ),
                    const SizedBox(height: 16),

                    // Descripción Técnica
                    _buildLabel('Descripción técnica del movimiento *'),
                    TextFormField(
                      controller: _descripcionController,
                      maxLines: 4,
                      style: GoogleFonts.nunito(color: GingaColors.textPrimary),
                      decoration: _buildInputDecoration(
                          'Explica paso a paso cómo posicionar los pies, balancear el tronco, elevar la cadera y rotar...'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Describe técnicamente el movimiento' : null,
                    ),
                    const SizedBox(height: 16),

                    // Consejo del Mestre
                    _buildLabel('Consejo clave del Mestre'),
                    TextFormField(
                      controller: _tipMestreController,
                      maxLines: 2,
                      style: GoogleFonts.nunito(color: GingaColors.textPrimary),
                      decoration: _buildInputDecoration('Ej: No quites la vista de tu oponente al girar...'),
                    ),
                    const SizedBox(height: 16),

                    // Error Común
                    _buildLabel('Error postural o técnico común'),
                    TextFormField(
                      controller: _tipErrorController,
                      maxLines: 2,
                      style: GoogleFonts.nunito(color: GingaColors.textPrimary),
                      decoration: _buildInputDecoration('Ej: Apoyar el talón completo frena tu velocidad de escape...'),
                    ),
                    // Visibilidad / Borrador Switch
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: SwitchListTile(
                        value: _visible,
                        activeColor: GingaColors.brandGreen,
                        title: Text(
                          'Publicar en la Biblioteca',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _visible
                              ? 'Visible para todos los alumnos en su biblioteca.'
                              : 'Guardado como borrador (oculto para alumnos).',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: GingaColors.textSecondary,
                          ),
                        ),
                        onChanged: (bool val) {
                          setState(() {
                            _visible = val;
                          });
                        },
                      ),
                    ),

                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.md)),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _guardarTutorial,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _isEditMode ? 'Guardar Cambios' : 'Registrar Lección',
                                style: GoogleFonts.montserrat(
                                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: GingaColors.textPrimary,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textSecondary.withOpacity(0.5)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        borderSide: const BorderSide(color: GingaColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        borderSide: const BorderSide(color: GingaColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        borderSide: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}
