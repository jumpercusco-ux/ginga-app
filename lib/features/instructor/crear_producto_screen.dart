import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/widgets/ginga_cached_image.dart';

class CrearProductoScreen extends StatefulWidget {
  final String productoId;
  const CrearProductoScreen({super.key, required this.productoId});

  @override
  State<CrearProductoScreen> createState() => _CrearProductoScreenState();
}

class _CrearProductoScreenState extends State<CrearProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _stockController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _tallasController = TextEditingController();
  
  String _categoriaSeleccionada = 'ropa';
  bool _isLoading = false;
  bool _isEditMode = false;

  File? _imageFile;
  String? _imagenUrlExistente;

  final List<Map<String, String>> _categorias = [
    {'id': 'ropa', 'label': 'Ropa / Uniformes'},
    {'id': 'instrumentos', 'label': 'Instrumentos'},
    {'id': 'accesorios', 'label': 'Accesorios'},
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.productoId.isNotEmpty;
    if (_isEditMode) {
      _cargarDatosProducto();
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    _descripcionController.dispose();
    _tallasController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosProducto() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('productos')
          .doc(widget.productoId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _nombreController.text = data['nombre'] ?? '';
        _precioController.text = (data['precio'] as num?)?.toDouble().toString() ?? '0.0';
        _stockController.text = (data['stock'] as num?)?.toInt().toString() ?? '0';
        _descripcionController.text = data['descripcion'] ?? '';
        _categoriaSeleccionada = data['categoria'] ?? 'ropa';
        _tallasController.text = (data['tallas'] as List?)?.join(', ') ?? '';
        _imagenUrlExistente = data['imagen_url'];
      }
    } catch (e) {
      debugPrint('Error al cargar producto: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarImagen() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final String nombre = _nombreController.text.trim();
    final double precio = double.tryParse(_precioController.text.trim()) ?? 0.0;
    final int stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final String descripcion = _descripcionController.text.trim();
    final List<String> tallas = _tallasController.text.trim().isNotEmpty
        ? _tallasController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : [];

    try {
      String imagenUrl = _imagenUrlExistente ?? 'assets/images/placeholder_custom.jpg';

      // Si seleccionó una nueva foto, la subimos a Firebase Storage
      if (_imageFile != null) {
        final String fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child('productos_imagenes/$fileName');
        
        await storageRef.putFile(_imageFile!);
        imagenUrl = await storageRef.getDownloadURL();
      }

      final Map<String, dynamic> productData = {
        'nombre': nombre,
        'precio': precio,
        'stock': stock,
        'descripcion': descripcion,
        'categoria': _categoriaSeleccionada,
        'tallas': tallas,
        'imagen_url': imagenUrl,
      };

      if (_isEditMode) {
        // Actualizar producto existente
        await FirebaseFirestore.instance
            .collection('productos')
            .doc(widget.productoId)
            .update(productData);
      } else {
        // Registrar nuevo producto (añadimos rating 5.0 por defecto)
        productData['rating'] = 5.0;
        await FirebaseFirestore.instance.collection('productos').add(productData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? '¡Producto actualizado correctamente! 📦'
                  : '¡Nuevo producto registrado con éxito! 🎉',
              style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: GingaColors.brandGreen,
          ),
        );
        context.pop(); // Vuelve a la administración
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el producto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: GingaColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: GingaColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditMode ? 'Editar Producto' : 'Nuevo Producto',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: GingaColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading && _nombreController.text.isEmpty
          ? const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? 'Modifica los datos del artículo' : 'Completa los datos del nuevo artículo para la tienda',
                      style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // ── Selector de Imagen de Producto ───────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _seleccionarImagen,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: GingaColors.brandGreen.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(GingaRadius.lg),
                            border: Border.all(color: GingaColors.brandGreen.withOpacity(0.18), width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _imageFile != null
                              ? Image.file(_imageFile!, fit: BoxFit.cover)
                              : (_imagenUrlExistente != null && (_imagenUrlExistente!.startsWith('http') || _imagenUrlExistente!.startsWith('assets/')))
                                  ? GingaCachedImage(
                                      imageUrl: _imagenUrlExistente!,
                                      fit: BoxFit.cover,
                                      category: _categoriaSeleccionada,
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_a_photo_outlined, color: GingaColors.brandGreen, size: 36),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Añadir Foto',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: GingaColors.brandGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Nombre del Producto ───────────────────────────
                    Text(
                      'Nombre del Artículo *',
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: GingaColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nombreController,
                      style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Ej. Berimbau de Biriba Profesional',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el nombre del producto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Categoría del Producto ─────────────────────────
                    Text(
                      'Categoría *',
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: GingaColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                      decoration: InputDecoration(
                        fillColor: GingaColors.backgroundLight,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          borderSide: BorderSide(color: GingaColors.borderLight),
                        ),
                      ),
                      items: _categorias.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['id'],
                          child: Text(
                            cat['label']!,
                            style: GoogleFonts.nunito(color: GingaColors.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _categoriaSeleccionada = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Precio y Stock (Fila) ──────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Precio
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Precio (S/) *',
                                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: GingaColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _precioController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Ej. 85.00',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ingresa el precio';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Número inválido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Stock
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stock Inicial *',
                                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: GingaColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Ej. 10',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ingresa el stock';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Número entero inválido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Descripción del Producto ───────────────────────
                    Text(
                      'Descripción del Producto *',
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: GingaColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descripcionController,
                      maxLines: 5,
                      style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Describe el material, la talla de referencia, el tipo de sonido en caso de instrumentos, etc.',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa la descripción';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Tallas / Medidas ─────────────────────────────────
                    Text(
                      'Tallas / Medidas Disponibles',
                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: GingaColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _tallasController,
                      style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Ej. S, M, L, XL o Pandeiro de 10", Pandeiro de 12" (separados por comas)',
                        helperText: 'Deja vacío si el artículo no tiene variantes de tamaño.',
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Botón Guardar / Registrar ───────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _guardarProducto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.full),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _isEditMode ? 'Guardar Cambios' : 'Registrar Artículo',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
