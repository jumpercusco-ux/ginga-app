import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/tutoriales_service.dart';

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
  String _selectedCategory = 'Ataques';
  String _selectedLevel = 'Iniciante';
  String _existingImageUrl = '';

  // Selector de imagen
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categorias = ['Ataques', 'Defensas', 'Esquivas', 'Floreos'];
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
          _selectedCategory = data['categoria'] ?? 'Ataques';
          _selectedLevel = data['nivel'] ?? 'Iniciante';
          _existingImageUrl = data['imagen_url'] ?? '';
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

    setState(() => _isLoading = true);
    try {
      String finalImageUrl = _existingImageUrl;

      // 1. Subir imagen a Firebase Storage si se seleccionó una nueva
      if (_selectedImageFile != null) {
        finalImageUrl = await TutorialesService.instance.subirPortadaTutorial(_selectedImageFile!);
      } else if (finalImageUrl.isEmpty) {
        // Fallback por defecto si se crea sin imagen
        finalImageUrl = 'assets/images/placeholder_custom.jpg';
      }

      // 2. Guardar o actualizar en Firestore
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
                    // ── Selector Visual de Portada ────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _seleccionarImagen,
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(GingaRadius.lg),
                            border: Border.all(color: GingaColors.borderLight),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedImageFile != null
                              ? Image.file(_selectedImageFile!, fit: BoxFit.cover)
                              : (_existingImageUrl.isNotEmpty
                                  ? (_existingImageUrl.startsWith('assets/')
                                      ? Image.asset(_existingImageUrl, fit: BoxFit.cover)
                                      : Image.network(_existingImageUrl, fit: BoxFit.cover, errorBuilder: (c, o, s) {
                                          return const Center(child: Icon(Icons.broken_image_outlined));
                                        }))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            size: 40, color: GingaColors.textSecondary.withOpacity(0.6)),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Añadir foto de portada',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: GingaColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Recomendado: 16:9 horizontal',
                                          style: GoogleFonts.nunito(
                                            fontSize: 10,
                                            color: GingaColors.textSecondary.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    )),
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
                    const SizedBox(height: 32),

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
