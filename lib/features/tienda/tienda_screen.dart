import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/tienda_service.dart';
import '../../core/widgets/ginga_cached_image.dart';

class TiendaScreen extends StatefulWidget {
  final bool isTab;
  const TiendaScreen({super.key, this.isTab = false});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  String _categoriaSeleccionada = 'todos';

  final List<Map<String, String>> _categorias = [
    {'id': 'todos', 'label': 'Todos'},
    {'id': 'membresias', 'label': 'Membresías'},
    {'id': 'ropa', 'label': 'Ropa'},
    {'id': 'instrumentos', 'label': 'Instrumentos'},
    {'id': 'accesorios', 'label': 'Accesorios'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: GingaColors.backgroundLight,
        elevation: 0,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back,
                    color: GingaColors.textPrimary),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
        title: Text(
          'Ginga Store',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: GingaColors.textPrimary,
          ),
        ),
        actions: [
          // Icono del Carrito con Badge reactivo
          ValueListenableBuilder<Map<String, CartItem>>(
            valueListenable: TiendaService.instance.carritoNotifier,
            builder: (context, carrito, child) {
              final count = TiendaService.instance.totalItemsCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(Icons.shopping_bag_outlined,
                        color: GingaColors.textPrimary, size: 26),
                    onPressed: () => context.push('/carrito'),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: GingaColors.brandGreen,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selector de Categorías (Horizontal) ────────────────────────
          Container(
            height: 46,
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categorias.length,
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final isSelected = _categoriaSeleccionada == cat['id'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat['label']!,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : GingaColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _categoriaSeleccionada = cat['id']!;
                        });
                      }
                    },
                    selectedColor: GingaColors.brandGreen,
                    backgroundColor: cardBg,
                    disabledColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                      side: BorderSide(
                        color: isSelected
                            ? GingaColors.brandGreen
                            : borderColor,
                        width: 1,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),

          // ── Grid del Catálogo de Productos ──────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('productos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: GingaColors.brandGreen));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 64,
                            color: GingaColors.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No hay productos disponibles por ahora',
                          style: GoogleFonts.nunito(
                              color: GingaColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Filtrado por categoría en memoria
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (_categoriaSeleccionada == 'todos') return true;
                  return (data['categoria'] ?? '') == _categoriaSeleccionada;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay productos en esta categoría',
                      style: GoogleFonts.nunito(
                          color: GingaColors.textSecondary, fontSize: 14),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 10,
                    bottom: 150,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String id = doc.id;
                    final String nombre = data['nombre'] ?? '';
                    final String descripcion = data['descripcion'] ?? '';
                    final double precio =
                        (data['precio'] as num?)?.toDouble() ?? 0.0;
                    final String categoria = data['categoria'] ?? 'ropa';
                    final String imagenUrl = data['imagen_url'] ?? '';
                    final int stock = (data['stock'] as num?)?.toInt() ?? 0;
                    final double rating =
                        (data['rating'] as num?)?.toDouble() ?? 4.5;

                    return _ProductCard(
                      id: id,
                      nombre: nombre,
                      descripcion: descripcion,
                      precio: precio,
                      categoria: categoria,
                      imagenUrl: imagenUrl,
                      stock: stock,
                      rating: rating,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String categoria;
  final String imagenUrl;
  final int stock;
  final double rating;

  const _ProductCard({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.categoria,
    required this.imagenUrl,
    required this.stock,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    IconData categoryIcon = Icons.shopping_bag_outlined;
    Color categoryColor = GingaColors.brandGreen;

    if (categoria == 'ropa') {
      categoryIcon = Icons.checkroom_outlined;
    } else if (categoria == 'instrumentos') {
      categoryIcon = Icons.music_note_outlined;
      categoryColor = GingaColors.accentAmber;
    } else if (categoria == 'accesorios') {
      categoryIcon = Icons.grade_outlined;
      categoryColor = Colors.purple;
    } else if (categoria == 'membresias') {
      categoryIcon = Icons.card_membership_outlined;
      categoryColor = Colors.teal;
    }

    return GestureDetector(
      onTap: () => context.push('/producto-detail?productoId=$id'),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Imagen / Miniatura del Producto ────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Contenedor elegante de marcador de posición (Fallback robusto)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: categoryColor.withOpacity(0.08),
                    child: Hero(
                      tag: 'product-image-$id',
                      child: GingaCachedImage(
                        imageUrl: imagenUrl,
                        fit: BoxFit.cover,
                        category: categoria,
                        errorWidget: Center(
                          child: Icon(
                            categoryIcon,
                            color: categoryColor.withOpacity(0.4),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Indicador de Stock Bajo
                  if (stock <= 5 && stock > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Últimos $stock',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Indicador de Sin Stock
                  if (stock == 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Agotado',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Rating Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? GingaColors.backgroundDark.withOpacity(0.9) : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(GingaRadius.sm),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              color: GingaColors.accentAmber, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: GoogleFonts.montserrat(
                              color: GingaColors.textPrimary,
                              fontSize: 9,
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

            // ── Datos del Producto ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categoria.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: categoryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'S/ ${precio.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      // Botón rápido de agregar al carrito
                      if (stock > 0)
                        GestureDetector(
                          onTap: () {
                            if (categoria == 'ropa' || categoria == 'membresias') {
                              // Si es ropa o membresia requiere ir al detalle
                              context.push('/producto-detail?productoId=$id');
                            } else {
                              // Si es instrumento/accesorio se añade directamente
                              TiendaService.instance.agregarAlCarrito(
                                id: id,
                                nombre: nombre,
                                precio: precio,
                                imagenUrl: imagenUrl,
                                categoria: categoria,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '¡$nombre añadido al carrito! 🛒',
                                    style: GoogleFonts.nunito(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
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
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: GingaColors.brandGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
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
      ),
    );
  }
}
