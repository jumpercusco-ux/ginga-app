import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Lista estática de tutoriales de Capoeira
  final List<TutorialItem> _tutoriales = [
    TutorialItem(
      title: 'Passape',
      category: 'Ataques',
      level: 'Iniciante',
      duration: '6 min',
      imageUrl: 'assets/images/passape.jpg',
      description: 'El passape es un movimiento de ataque circular que utiliza la parte externa del pie. Es fundamental mantener la pierna de apoyo firme y la guardia alta en todo momento para evitar contraataques rápidos.',
      tipMestre: 'No quites la vista del oponente durante el giro del pie y mantén la guardia firme.',
      tipError: 'Inclinar el tronco demasiado hacia atrás te hace perder el equilibrio y la potencia del golpe.',
    ),
    TutorialItem(
      title: 'Au Batido',
      category: 'Floreos',
      level: 'Graduado',
      duration: '8 min',
      imageUrl: 'assets/images/au_batido.jpg',
      description: 'El Au Batido (también conocido como Au de Bico) es una de las acrobacias más icónicas y funcionales de la capoeira. Combina un giro de Au (rueda) bloqueado a mitad de camino sobre una sola mano, lanzando una patada defensiva/ofensiva con la pierna libre mientras proteges el rostro.',
      tipMestre: 'Fortalece tus muñecas y empuja activamente el suelo con el hombro del brazo de apoyo para ganar altura.',
      tipError: 'Dejar caer la cadera antes de completar el bloqueo arruina la postura y puede sobrecargar tu hombro.',
    ),
    TutorialItem(
      title: 'Meia Lua de Frente',
      category: 'Ataques',
      level: 'Iniciante',
      duration: '6 min',
      imageUrl: 'assets/images/meia_lua.jpg',
      description: 'Un movimiento semicircular básico de ataque de afuera hacia adentro. La pierna describe un semicírculo amplio y extendido frente al cuerpo cruzando la línea de guardia del oponente.',
      tipMestre: 'Mantén el talón de la pierna de apoyo completamente plantado en el suelo para no perder estabilidad.',
      tipError: 'Bajar los brazos durante el recorrido de la patada expone tu cabeza a una contrapatada directa.',
    ),
    TutorialItem(
      title: 'Cocorinha',
      category: 'Esquivas',
      level: 'Iniciante',
      duration: '4 min',
      imageUrl: 'assets/images/cocorinha.jpg',
      description: 'Una esquiva baja esencial de protección. Se realiza agachándose completamente sobre ambos pies, manteniendo los talones abajo y protegiendo el lateral de la cabeza con el brazo de guardia levantado.',
      tipMestre: 'Mantén la mano contraria al brazo de guardia firmemente plantada en el suelo para mayor resorte y velocidad de escape.',
      tipError: 'Levantar los talones del suelo al agacharte reduce drásticamente tu estabilidad y velocidad de reacción.',
    ),
    TutorialItem(
      title: 'Vingativa',
      category: 'Defensas',
      level: 'Avanzado',
      duration: '7 min',
      imageUrl: 'assets/images/vingativa.jpg',
      description: 'Una proyección de desequilibrio clásica y muy efectiva. Consiste en entrar profundamente detrás de la pierna de apoyo de tu oponente, bloqueando su retirada mientras aplicas fuerza en dirección opuesta con tu tronco/codo.',
      tipMestre: 'Coloca tu cadera siempre más baja que la de tu oponente para lograr un centro de gravedad y apalancamiento ideales.',
      tipError: 'Intentar empujar con fuerza bruta en los hombros en lugar de pivotar y barrer con la técnica de palanca.',
    ),
  ];

  List<TutorialItem> get _filteredTutoriales {
    return _tutoriales.where((tutorial) {
      final matchesSearch = tutorial.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tutorial.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todos' || tutorial.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
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
                children: ['Todos', 'Ataques', 'Defensas', 'Esquivas', 'Floreos'].map((categoria) {
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

            // Listado de tutoriales
            Expanded(
              child: _filteredTutoriales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_outline, size: 48, color: GingaColors.borderLight),
                          const SizedBox(height: 12),
                          Text(
                            'No se encontraron micro-lecciones',
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
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: _filteredTutoriales.length,
                      itemBuilder: (context, index) {
                        final item = _filteredTutoriales[index];
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
                                      title: item.title,
                                      category: item.category,
                                      level: item.level,
                                      description: item.description,
                                      tipMestre: item.tipMestre,
                                      tipError: item.tipError,
                                      imageUrl: item.imageUrl,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Miniatura/Icono
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: GingaColors.brandGreen.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(GingaRadius.md),
                                      ),
                                      child: const Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: GingaColors.brandGreen,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Detalles del tutorial
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: GingaColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: GingaColors.cardLight,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.level,
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    color: item.level == 'Iniciante'
                                                        ? GingaColors.brandGreen
                                                        : (item.level == 'Graduado'
                                                            ? GingaColors.accentAmber
                                                            : Colors.red),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.access_time, size: 12, color: GingaColors.textSecondary),
                                              const SizedBox(width: 3),
                                              Text(
                                                item.duration,
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
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class TutorialItem {
  final String title;
  final String category;
  final String level;
  final String duration;
  final String imageUrl;
  final String description;
  final String tipMestre;
  final String tipError;

  TutorialItem({
    required this.title,
    required this.category,
    required this.level,
    required this.duration,
    required this.imageUrl,
    required this.description,
    required this.tipMestre,
    required this.tipError,
  });
}
