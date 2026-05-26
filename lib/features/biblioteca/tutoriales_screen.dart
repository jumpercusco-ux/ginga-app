import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';
import 'tutor_detail_screen.dart';

class TutorialesScreen extends StatefulWidget {
  const TutorialesScreen({super.key});

  @override
  State<TutorialesScreen> createState() => _TutorialesScreenState();
}

class _TutorialesScreenState extends State<TutorialesScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<QuerySnapshot> _obtenerTutoriales() async {
    try {
      final cacheSnap = await FirebaseFirestore.instance
          .collection('tutoriales')
          .orderBy('titulo')
          .get(const GetOptions(source: Source.cache));
      if (cacheSnap.docs.isNotEmpty) {
        return cacheSnap;
      }
    } catch (_) {}
    return await FirebaseFirestore.instance
        .collection('tutoriales')
        .orderBy('titulo')
        .get();
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
                      'Tutoriales On-Demand',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.tune_outlined, color: GingaColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Buscador de Lecciones
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
                  hintText: 'Buscar técnicas, movimientos...',
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
            const SizedBox(height: 8),

            // Filtro horizontal de Categorías
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['Todos', 'Fundamentos', 'Ataques', 'Defensas', 'Esquivas', 'Floreos'].map((categoria) {
                  final isSelected = _selectedCategory == categoria;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = categoria;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? GingaColors.brandGreen : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? GingaColors.brandGreen : GingaColors.borderLight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        categoria,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : GingaColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Listado de tutoriales en tiempo real desde Firestore
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: _obtenerTutoriales(),
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
                          const Icon(Icons.play_circle_outline, size: 48, color: GingaColors.borderLight),
                          const SizedBox(height: 12),
                          Text(
                            'No hay micro-lecciones',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filtrar localmente por búsqueda y categoría
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final titulo = (data['titulo'] ?? '').toString().toLowerCase();
                    final descripcion = (data['descripcion'] ?? '').toString().toLowerCase();
                    final categoria = data['categoria'] ?? 'Ataques';

                    final matchesSearch = titulo.contains(_searchQuery.toLowerCase()) ||
                        descripcion.contains(_searchQuery.toLowerCase());
                    final matchesCategory = _selectedCategory == 'Todos' || categoria == _selectedCategory;

                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: GingaColors.borderLight),
                          const SizedBox(height: 12),
                          Text(
                            'No se encontraron resultados',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prueba con otra palabra o categoría',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: GingaColors.textSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final titulo = data['titulo'] ?? '';
                      final categoria = data['categoria'] ?? 'Ataques';
                      final nivel = data['nivel'] ?? 'Iniciante';
                      final duracion = data['duracion'] ?? '6 min';
                      final imagenUrl = data['imagen_url'] ?? '';
                      final descripcion = data['descripcion'] ?? '';
                      final tipMestre = data['tipMestre'] ?? '';
                      final tipError = data['tipError'] ?? '';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TutorialDetailScreen(
                                    title: titulo,
                                    category: categoria,
                                    level: nivel,
                                    description: descripcion,
                                    tipMestre: tipMestre,
                                    tipError: tipError,
                                    imageUrl: imagenUrl,
                                    videoUrl: data['video_url'] ?? '',
                                    duracion: duracion,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Miniatura de Portada
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: GingaColors.brandGreen.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(GingaRadius.md),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: imagenUrl.isNotEmpty
                                        ? (imagenUrl.startsWith('assets/')
                                            ? Image.asset(imagenUrl, fit: BoxFit.cover)
                                            : Image.network(imagenUrl, fit: BoxFit.cover, errorBuilder: (c, o, s) {
                                                return const Icon(Icons.play_circle_fill_rounded, color: GingaColors.brandGreen);
                                              }))
                                        : const Icon(Icons.play_circle_fill_rounded, color: GingaColors.brandGreen, size: 28),
                                  ),
                                  const SizedBox(width: 14),

                                  // Detalles del tutorial
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
                                            const Icon(Icons.access_time, size: 12, color: GingaColors.textSecondary),
                                            const SizedBox(width: 3),
                                            Text(
                                              duracion,
                                              style: GoogleFonts.nunito(
                                                fontSize: 11,
                                                color: GingaColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Botón play circular lateral
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: GingaColors.brandGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    );
  }
}
