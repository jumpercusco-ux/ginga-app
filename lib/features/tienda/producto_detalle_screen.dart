import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/tienda_service.dart';
import '../../core/widgets/ginga_cached_image.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final String productoId;
  const ProductoDetalleScreen({super.key, required this.productoId});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  int _cantidad = 1;
  String? _tallaSeleccionada;
  late Stream<DocumentSnapshot> _productStream;

  @override
  void initState() {
    super.initState();
    _productStream = FirebaseFirestore.instance
        .collection('productos')
        .doc(widget.productoId)
        .snapshots();
  }

  Future<void> _launchWhatsApp(BuildContext context, String planNombre, double planPrecio) async {
    final String message = 
        '🥋 *¡Hola! Deseo adquirir/renovar mi membresía en Capoeira Ginga.*\n\n'
        '📋 *Detalle del Plan:* $planNombre\n'
        '💰 *Precio:* S/ ${planPrecio.toStringAsFixed(2)}\n\n'
        '¿Me podrían indicar los medios de pago para coordinar la activación? ¡Muchas gracias! 👋';
    const String telefonoGinga = '51954642457';
    final String url = 'https://wa.me/$telefonoGinga?text=${Uri.encodeComponent(message)}';
    
    try {
      final Uri uri = Uri.parse(url);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('WhatsApp lanzado con éxito');
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp. Por favor, comunícate con la academia directamente.'),
          ),
        );
      }
    }
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      color: isDark ? Colors.white12 : Colors.black12,
      thickness: 1,
    );
  }

  Widget _buildSizesWrap(List<String> tallas, Color cardBg, Color borderColor) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tallas.map((talla) {
        final isSelected = _tallaSeleccionada == talla;
        return GestureDetector(
          onTap: () {
            setState(() {
              _tallaSeleccionada = talla;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? GingaColors.brandGreen : cardBg,
              borderRadius: BorderRadius.circular(GingaRadius.md),
              border: Border.all(
                color: isSelected ? GingaColors.brandGreen : borderColor,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: GingaColors.brandGreen.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                ],
                Text(
                  talla,
                  style: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : GingaColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuantityPicker(Color cardBg, Color borderColor, int stock) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(GingaRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () {
                  if (_cantidad > 1) {
                    setState(() => _cantidad--);
                  }
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$_cantidad',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () {
                  if (_cantidad < stock) {
                    setState(() => _cantidad++);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Llegaste al límite del stock disponible'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String categoria,
    required String nombre,
    required double precio,
    required String imagenUrl,
    required int stock,
    required bool hasSizes,
  }) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: categoria == 'membresias'
          ? ElevatedButton.icon(
              onPressed: () => _launchWhatsApp(context, nombre, precio),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // Verde WhatsApp
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: Text(
                'Adquirir por WhatsApp 🥋',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: stock <= 0
                  ? null
                  : () {
                      if (hasSizes && _tallaSeleccionada == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Por favor, selecciona una talla/medida antes de agregar. 🥋',
                              style: GoogleFonts.montserrat(color: Colors.white),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      TiendaService.instance.agregarAlCarrito(
                        id: widget.productoId,
                        nombre: nombre,
                        precio: precio,
                        imagenUrl: imagenUrl,
                        categoria: categoria,
                        cantidad: _cantidad,
                        talla: hasSizes ? _tallaSeleccionada : null,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '¡$nombre ${hasSizes ? "($_tallaSeleccionada) " : ""}añadido al carrito! 🛒',
                            style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: GingaColors.brandGreen,
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'VER',
                            textColor: Colors.white,
                            onPressed: () => context.push('/carrito'),
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                elevation: 0,
              ),
              child: Text(
                stock <= 0 ? 'Artículo Agotado' : 'Añadir al Carrito de Reservas',
                style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return StreamBuilder<DocumentSnapshot>(
      stream: _productStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: GingaColors.backgroundLight,
            body: Center(child: CircularProgressIndicator(color: GingaColors.brandGreen)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: GingaColors.backgroundLight,
            appBar: AppBar(
              centerTitle: true,
            ),
            body: Center(
              child: Text(
                'El producto no se encuentra disponible.',
                style: GoogleFonts.montserrat(color: GingaColors.textSecondary),
              ),
            ),
          );
        }

        final product = snapshot.data!.data() as Map<String, dynamic>;
        final String nombre = product['nombre'] ?? '';
        final String descripcion = product['descripcion'] ?? '';
        final double precio = (product['precio'] as num?)?.toDouble() ?? 0.0;
        final String categoria = product['categoria'] ?? 'ropa';
        final String imagenUrl = product['imagen_url'] ?? '';
        final int stock = (product['stock'] as num?)?.toInt() ?? 0;
        final double rating = (product['rating'] as num?)?.toDouble() ?? 4.5;
        
        final List<dynamic> tallasRaw = product['tallas'] ?? [];
        final List<String> tallas = tallasRaw.map((e) => e.toString()).toList();
        final bool hasSizes = tallas.isNotEmpty;

        Color categoryColor = GingaColors.brandGreen;
        IconData categoryIcon = Icons.shopping_bag_outlined;

        if (categoria == 'instrumentos') {
          categoryColor = GingaColors.accentAmber;
          categoryIcon = Icons.music_note_outlined;
        } else if (categoria == 'accesorios') {
          categoryColor = Colors.purple;
          categoryIcon = Icons.grade_outlined;
        } else if (categoria == 'ropa') {
          categoryIcon = Icons.checkroom_outlined;
        } else if (categoria == 'membresias') {
          categoryColor = Colors.teal;
          categoryIcon = Icons.card_membership_outlined;
        }

        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isLargeScreen = screenWidth > 720;

        return Scaffold(
          backgroundColor: GingaColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: GingaColors.backgroundLight,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: GingaColors.textPrimary),
              onPressed: () async {
                if (context.canPop()) {
                  context.pop();
                } else {
                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      final doc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .get();
                      final role = doc.data()?['rol'] ?? 'alumno';
                      if (role == 'profesor') {
                        if (context.mounted) context.go('/instructor-clase');
                        return;
                      }
                    }
                  } catch (e) {
                    debugPrint("Error al validar rol para navegacion back: $e");
                  }
                  if (context.mounted) context.go('/home');
                }
              },
            ),
            title: Text(
              'Detalle de Artículo',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: GingaColors.textPrimary,
              ),
            ),
          ),
          bottomNavigationBar: isLargeScreen
              ? null
              : SafeArea(
                  child: Center(
                    heightFactor: 1.0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: _buildActionButton(
                          context: context,
                          categoria: categoria,
                          nombre: nombre,
                          precio: precio,
                          imagenUrl: imagenUrl,
                          stock: stock,
                          hasSizes: hasSizes,
                        ),
                      ),
                    ),
                  ),
                ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: isLargeScreen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── COLUMNA IZQUIERDA: Imagen ─────────────────
                          Expanded(
                            flex: 10,
                            child: Column(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: categoryColor.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                                      border: Border.all(color: borderColor),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: GingaCachedImage(
                                            imageUrl: imagenUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            category: categoria,
                                            errorWidget: Center(
                                              child: Icon(
                                                categoryIcon,
                                                color: categoryColor.withOpacity(0.4),
                                                size: 90,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Badge de Rating
                                        Positioned(
                                          top: 16,
                                          right: 16,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: cardBg.withOpacity(0.92),
                                              borderRadius: BorderRadius.circular(GingaRadius.md),
                                              border: Border.all(color: borderColor),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star, color: GingaColors.accentAmber, size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  rating.toStringAsFixed(1),
                                                  style: GoogleFonts.montserrat(
                                                    color: GingaColors.textPrimary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          // ── COLUMNA DERECHA: Detalles ─────────────────
                          Expanded(
                            flex: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge de Categoría
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(GingaRadius.sm),
                                    border: Border.all(color: categoryColor.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(categoryIcon, color: categoryColor, size: 12),
                                      const SizedBox(width: 6),
                                      Text(
                                        categoria.toUpperCase(),
                                        style: GoogleFonts.montserrat(
                                          color: categoryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Nombre
                                Text(
                                  nombre,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: GingaColors.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Precio
                                Text(
                                  'S/ ${precio.toStringAsFixed(2)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: GingaColors.brandGreen,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Stock
                                Text(
                                  categoria == 'membresias'
                                      ? 'Membresía Oficial Ginga App'
                                      : (stock <= 0
                                          ? 'Sin unidades disponibles'
                                          : 'Stock disponible: $stock unidades'),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    color: stock <= 0 && categoria != 'membresias'
                                        ? Colors.red
                                        : stock <= 5 && categoria != 'membresias'
                                            ? GingaColors.accentAmber
                                            : GingaColors.textSecondary,
                                    fontWeight: stock <= 5 && categoria != 'membresias' ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildDivider(),
                                const SizedBox(height: 16),
                                // Descripción
                                Text(
                                  'Descripción del producto',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  descripcion,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13.5,
                                    color: GingaColors.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Tallas
                                if (categoria != 'membresias' && hasSizes && stock > 0) ...[
                                  _buildDivider(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Selecciona variante o talla',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: GingaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildSizesWrap(tallas, cardBg, borderColor),
                                  const SizedBox(height: 16),
                                ],
                                // Cantidad
                                if (categoria != 'membresias' && stock > 0) ...[
                                  _buildDivider(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Cantidad a reservar',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: GingaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildQuantityPicker(cardBg, borderColor, stock),
                                  const SizedBox(height: 24),
                                ],
                                // Botón de acción directo para pantallas grandes
                                _buildActionButton(
                                  context: context,
                                  categoria: categoria,
                                  nombre: nombre,
                                  precio: precio,
                                  imagenUrl: imagenUrl,
                                  stock: stock,
                                  hasSizes: hasSizes,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── IMAGEN MÓVIL ─────────────────────────────
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(GingaRadius.lg),
                                border: Border.all(color: borderColor),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  Center(
                                    child: GingaCachedImage(
                                      imageUrl: imagenUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      category: categoria,
                                      errorWidget: Center(
                                        child: Icon(
                                          categoryIcon,
                                          color: categoryColor.withOpacity(0.4),
                                          size: 90,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Badge de Categoría
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: categoryColor,
                                        borderRadius: BorderRadius.circular(GingaRadius.sm),
                                      ),
                                      child: Text(
                                        categoria.toUpperCase(),
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Badge de Rating
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cardBg.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(GingaRadius.md),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star, color: GingaColors.accentAmber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: GoogleFonts.montserrat(
                                              color: GingaColors.textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Título y Precio
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: GingaColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      categoria == 'membresias'
                                          ? 'Membresía Oficial Ginga App'
                                          : (stock <= 0
                                              ? 'Sin unidades disponibles'
                                              : 'Stock disponible: $stock unidades'),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        color: stock <= 0 && categoria != 'membresias'
                                            ? Colors.red
                                            : stock <= 5 && categoria != 'membresias'
                                                ? GingaColors.accentAmber
                                                : GingaColors.textSecondary,
                                        fontWeight: stock <= 5 && categoria != 'membresias' ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'S/ ${precio.toStringAsFixed(2)}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: GingaColors.brandGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildDivider(),
                          const SizedBox(height: 20),
                          // Descripción
                          Text(
                            'Descripción del producto',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            descripcion,
                            style: GoogleFonts.montserrat(
                              fontSize: 13.5,
                              color: GingaColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Tallas
                          if (categoria != 'membresias' && hasSizes && stock > 0) ...[
                            _buildDivider(),
                            const SizedBox(height: 20),
                            Text(
                              'Selecciona variante o talla',
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildSizesWrap(tallas, cardBg, borderColor),
                            const SizedBox(height: 20),
                          ],
                          // Cantidad
                          if (categoria != 'membresias' && stock > 0) ...[
                            _buildDivider(),
                            const SizedBox(height: 20),
                            Text(
                              'Cantidad a reservar',
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildQuantityPicker(cardBg, borderColor, stock),
                            const SizedBox(height: 32),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

