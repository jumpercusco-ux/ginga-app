import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/widgets/ginga_cached_image.dart';

class InstructorTiendaScreen extends StatelessWidget {
  const InstructorTiendaScreen({super.key});

  Future<void> _eliminarProducto(BuildContext context, String docId, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
          ),
          title: Text(
            '¿Eliminar producto?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              color: GingaColors.textPrimary,
              fontSize: 16,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar "$nombre"? Esta acción no se puede deshacer y el artículo desaparecerá del catálogo de los alumnos.',
            style: GoogleFonts.nunito(
              color: GingaColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: GingaColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                'Eliminar',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        await FirebaseFirestore.instance.collection('productos').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$nombre" ha sido eliminado con éxito.'),
              backgroundColor: GingaColors.brandGreen,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar producto: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
          'Administración de Catálogo',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: GingaColors.textPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/crear-producto'),
        backgroundColor: GingaColors.brandGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(
          'Nuevo Artículo',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('productos')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    size: 64,
                    color: GingaColors.textSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay productos en la tienda aún.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: GingaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/crear-producto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      minimumSize: const Size(180, 44),
                    ),
                    child: Text(
                      'Agregar el Primero',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final productos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final doc = productos[index];
              final data = doc.data() as Map<String, dynamic>;
              final String id = doc.id;
              final String nombre = data['nombre'] ?? '';
              final double precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
              final int stock = (data['stock'] as num?)?.toInt() ?? 0;
              final String categoria = data['categoria'] ?? 'ropa';
              final String imagenUrl = data['imagen_url'] ?? '';

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
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: GingaColors.borderLight),
                ),
                child: Row(
                  children: [
                    // Miniatura
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GingaCachedImage(
                        imageUrl: imagenUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        category: categoria,
                        errorWidget: Icon(
                          categoryIcon,
                          color: categoryColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Detalles
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: GoogleFonts.montserrat(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                categoria.toUpperCase(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: categoryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: GingaColors.textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                stock <= 0
                                    ? 'SIN STOCK'
                                    : 'Stock: $stock un.',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: stock <= 3 ? FontWeight.w800 : FontWeight.w600,
                                  color: stock <= 0
                                      ? Colors.red
                                      : stock <= 3
                                          ? GingaColors.accentAmber
                                          : GingaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'S/ ${precio.toStringAsFixed(2)}',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: GingaColors.brandGreen,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Acciones de administración
                    Row(
                      children: [
                        // Editar
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22),
                          onPressed: () => context.push('/crear-producto?productoId=$id'),
                        ),
                        // Eliminar
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                          onPressed: () => _eliminarProducto(context, id, nombre),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
