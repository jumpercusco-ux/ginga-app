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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _productStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: GingaColors.backgroundLight,
            body: Center(child: CircularProgressIndicator(color: GingaColors.brandGreen)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: GingaColors.backgroundLight,
            appBar: AppBar(),
            body: Center(
              child: Text(
                'El producto no se encuentra disponible.',
                style: GoogleFonts.nunito(color: GingaColors.textSecondary),
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

        return Scaffold(
          backgroundColor: GingaColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: GingaColors.backgroundLight,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: GingaColors.textPrimary),
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
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                height: 54,
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
                                        style: GoogleFonts.nunito(color: Colors.white),
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
                                      style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600),
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
                        ),
                        child: Text(
                          stock <= 0 ? 'Artículo Agotado' : 'Añadir al Carrito de Reservas',
                          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ── Gran Cabecera de Imagen ───────────────────────────
                Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(GingaRadius.lg),
                    border: Border.all(color: GingaColors.borderLight),
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
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(color: GingaColors.borderLight),
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

                const SizedBox(height: 20),

                // ── Título y Precio ──────────────────────────────────
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
                            style: GoogleFonts.nunito(
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

                const SizedBox(height: 24),

                // ── Descripción del Producto ──────────────────────────
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
                  style: GoogleFonts.nunito(
                    fontSize: 13.5,
                    color: GingaColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Tallas / Medidas Disponibles ───────────────────────
                if (categoria != 'membresias' && hasSizes && stock > 0) ...[
                  Text(
                    'Selecciona variante o talla',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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
                            color: isSelected ? GingaColors.brandGreen : Colors.white,
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(
                              color: isSelected ? GingaColors.brandGreen : GingaColors.borderLight,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            talla,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : GingaColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Selector de Volumen / Cantidad ───────────────────
                if (categoria != 'membresias' && stock > 0) ...[
                  Text(
                    'Cantidad a reservar',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: GingaColors.borderLight),
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: () {
                                if (_cantidad > 1) {
                                  setState(() => _cantidad--);
                                }
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '$_cantidad',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
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
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
