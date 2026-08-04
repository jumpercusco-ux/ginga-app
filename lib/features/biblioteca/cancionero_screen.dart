import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/ginga_theme.dart';
import 'song_detail_screen.dart';
import 'crear_cantiga_screen.dart';

class Cantiga {
  final String id;
  final String titulo;
  final String ritmo;
  final String autor;
  final String interprete;
  final String duracion;
  final String contexto;
  final String letraPt;
  final String letraEs;
  final String audioUrl;
  final List<dynamic>? letraPtSincronizada;

  Cantiga({
    required this.id,
    required this.titulo,
    required this.ritmo,
    required this.autor,
    required this.interprete,
    required this.duracion,
    required this.contexto,
    required this.letraPt,
    required this.letraEs,
    required this.audioUrl,
    this.letraPtSincronizada,
  });
}

class CancioneroScreen extends StatefulWidget {
  const CancioneroScreen({super.key});

  @override
  State<CancioneroScreen> createState() => _CancioneroScreenState();
}

class _CancioneroScreenState extends State<CancioneroScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  final TextEditingController _searchController = TextEditingController();
  bool _esProfesor = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          final rol = doc.data()?['rol'] ?? 'alumno';
          setState(() {
            _esProfesor = rol == 'profesor';
          });
        }
      }
    } catch (e) {
      debugPrint("Error al validar rol en cancionero: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _obtenerCantigasStream() {
    return FirebaseFirestore.instance.collection('cantigas').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
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
                    icon: Icon(Icons.arrow_back_ios_new, size: 18, color: GingaColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Cantigas de Capoeira',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Buscador de Cantigas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar canciones, letras...',
                  hintStyle: GoogleFonts.montserrat(color: GingaColors.textSecondary.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: GingaColors.textSecondary),
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
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    borderSide: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                  ),
                ),
              ),
            ),

            // Filtro horizontal de Ritmos
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['Todos', 'Corrido', 'Ladainha', 'Samba de Roda'].map((ritmo) {
                  final isSelected = _selectedCategory == ritmo;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = ritmo;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? GingaColors.brandGreen : cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? GingaColors.brandGreen : borderColor,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        ritmo,
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

            // Listado de canciones desde Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _obtenerCantigasStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Error de Firestore: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: GingaColors.brandGreen),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No hay canciones en la base de datos',
                        style: GoogleFonts.montserrat(color: GingaColors.textSecondary),
                      ),
                    );
                  }

                  // Mapear los documentos de Firestore a la clase Cantiga
                  final allCantigas = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Cantiga(
                      id: doc.id,
                      titulo: data['titulo'] ?? '',
                      ritmo: data['ritmo'] ?? 'Corrido',
                      autor: data['autor'] ?? 'Tradicional',
                      interprete: data['interprete'] ?? 'Tradicional',
                      duracion: data['duracion'] ?? '2:00',
                      contexto: data['contexto'] ?? '',
                      letraPt: data['letraPt'] ?? '',
                      letraEs: data['letraEs'] ?? '',
                      audioUrl: data['audio_url'] ?? '',
                      letraPtSincronizada: data['letraPtSincronizada'] as List<dynamic>?,
                    );
                  }).toList();

                  // Aplicar búsqueda y filtros
                  final filtered = allCantigas.where((cantiga) {
                    final matchesSearch = cantiga.titulo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        cantiga.letraPt.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        cantiga.letraEs.toLowerCase().contains(_searchQuery.toLowerCase());
                    final matchesCategory = _selectedCategory == 'Todos' || cantiga.ritmo == _selectedCategory;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_music_outlined, size: 48, color: GingaColors.borderLight),
                          const SizedBox(height: 12),
                          Text(
                            'No se encontraron cantigas',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prueba con otra búsqueda o filtro',
                            style: GoogleFonts.montserrat(
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
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cantiga = filtered[index];
                      return _StaggeredListItem(
                        index: index,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: borderColor),
                          boxShadow: isDark ? [] : [
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
                                  builder: (_) => SongDetailScreen(cantiga: cantiga),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: GingaColors.brandGreen.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(GingaRadius.md),
                                    ),
                                    child: const Icon(
                                      Icons.music_video_rounded,
                                      color: GingaColors.brandGreen,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cantiga.titulo,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: GingaColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                                cantiga.ritmo,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w800,
                                                  color: cantiga.ritmo == 'Ladainha'
                                                      ? Colors.purple
                                                      : (cantiga.ritmo == 'Samba de Roda'
                                                          ? GingaColors.accentAmber
                                                          : GingaColors.brandGreen),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                cantiga.autor == cantiga.interprete
                                                    ? cantiga.autor
                                                    : '${cantiga.autor} (cantado por ${cantiga.interprete})',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: GingaColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: GingaColors.brandGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
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
        ),
      ),
      floatingActionButton: _esProfesor
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CrearCantigaScreen()),
                );
              },
              backgroundColor: GingaColors.brandGreen,
              elevation: 4,
              icon: const Icon(Icons.mic_external_on_rounded, color: Colors.white),
              label: Text(
                'Agregar Cantiga',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 12.5,
                  letterSpacing: 0.3,
                ),
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────
//  STAGGERED LIST ITEM ANIMATION
// ─────────────────────────────────────────

class _StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredListItem({
    required this.index,
    required this.child,
  });

  @override
  State<_StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<_StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Ejecutar con un sutil retraso desfasado
    final delay = Duration(milliseconds: widget.index * 40);
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: FractionalTranslation(
            translation: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

