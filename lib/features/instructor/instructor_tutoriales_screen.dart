import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/tutoriales_service.dart';

class InstructorTutorialesScreen extends StatefulWidget {
  const InstructorTutorialesScreen({super.key});

  @override
  State<InstructorTutorialesScreen> createState() => _InstructorTutorialesScreenState();
}

class _InstructorTutorialesScreenState extends State<InstructorTutorialesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _eliminarTutorialConConfirmacion(BuildContext context, String id, String titulo) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
          ),
          title: Text(
            '¿Eliminar lección?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              color: GingaColors.textPrimary,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar la lección "$titulo"? Esta acción no se puede deshacer y desaparecerá de la biblioteca de alumnos.',
            style: GoogleFonts.nunito(
              color: GingaColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: GingaColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await TutorialesService.instance.eliminarTutorial(id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lección "$titulo" eliminada con éxito 🚮'),
                        backgroundColor: Colors.red.shade700,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Eliminar',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Barra Superior Personalizada (App Bar) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: GingaColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Gestión de Biblioteca',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.help_outline, color: GingaColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Buscador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar lección en administración...',
                  hintStyle: GoogleFonts.nunito(color: GingaColors.textSecondary.withOpacity(0.6)),
                  prefixIcon: const Icon(Icons.search, color: GingaColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Listado de administración
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tutoriales')
                    .orderBy('titulo')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: GingaColors.brandGreen),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_outline, size: 56, color: GingaColors.borderLight),
                          const SizedBox(height: 12),
                          Text(
                            'Biblioteca sin lecciones',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Presiona el botón "+" de abajo para crear una.',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: GingaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['titulo'] ?? '').toString().toLowerCase();
                    final desc = (data['descripcion'] ?? '').toString().toLowerCase();
                    return title.contains(_searchQuery.toLowerCase()) ||
                        desc.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No hay resultados que coincidan con la búsqueda.',
                        style: GoogleFonts.nunito(color: GingaColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final id = doc.id;
                      final data = doc.data() as Map<String, dynamic>;
                      final titulo = data['titulo'] ?? '';
                      final categoria = data['categoria'] ?? 'Ataques';
                      final nivel = data['nivel'] ?? 'Iniciante';
                      final duracion = data['duracion'] ?? '6 min';
                      final imagenUrl = data['imagen_url'] ?? '';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.015),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Portada miniatura
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: GingaColors.brandGreen.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imagenUrl.isNotEmpty
                                    ? (imagenUrl.startsWith('assets/')
                                        ? Image.asset(imagenUrl, fit: BoxFit.cover)
                                        : Image.network(imagenUrl, fit: BoxFit.cover, errorBuilder: (c, o, s) {
                                            return const Icon(Icons.play_circle_fill, color: GingaColors.brandGreen);
                                          }))
                                    : const Icon(Icons.play_circle_fill, color: GingaColors.brandGreen, size: 28),
                              ),
                              const SizedBox(width: 14),

                              // Textos descriptivos
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      titulo,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: GingaColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: GingaColors.cardLight,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            nivel,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              color: nivel == 'Iniciante'
                                                  ? GingaColors.brandGreen
                                                  : (nivel == 'Graduado'
                                                      ? GingaColors.accentAmber
                                                      : Colors.red),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$categoria • $duracion',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            color: GingaColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Botones de acción
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Botón Editar
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: GingaColors.brandGreen, size: 20),
                                    onPressed: () => context.push('/crear-tutorial?tutorialId=$id'),
                                  ),
                                  // Botón Eliminar
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                    onPressed: () => _eliminarTutorialConConfirmacion(context, id, titulo),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/crear-tutorial'),
        backgroundColor: GingaColors.brandGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add),
      ),
    );
  }
}
