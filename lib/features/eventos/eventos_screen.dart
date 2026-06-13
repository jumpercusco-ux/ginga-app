import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/widgets/ginga_cached_image.dart';
import 'evento_detalle_screen.dart';

class EventosScreen extends StatefulWidget {
  final bool isTab;
  const EventosScreen({super.key, this.isTab = false});

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  int _selectedFilterIndex = 0; // 0 = Próximos, 1 = Mis Inscripciones, 2 = Pasados
  String _userSede = 'Cusco';
  Set<String> _registeredEventIds = {};
  bool _loadingRegistrations = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // 1. Cargar sede del alumno
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userSede = userDoc.data()?['sede'] ?? 'Cusco';
        });
      }

      // 2. Cargar eventos a los que se inscribió
      await _cargarRegistrosUsuario();
    } catch (e) {
      debugPrint('Error cargando datos de usuario: $e');
    }
  }

  Future<void> _cargarRegistrosUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (mounted) {
      setState(() => _loadingRegistrations = true);
    }
    try {
      final query = await FirebaseFirestore.instance.collection('eventos').get();
      final Set<String> registered = {};
      final futures = query.docs.map((doc) async {
        final regDoc = await doc.reference.collection('registros').doc(uid).get();
        if (regDoc.exists) {
          registered.add(doc.id);
        }
      });
      await Future.wait(futures);
      if (mounted) {
        setState(() {
          _registeredEventIds = registered;
          _loadingRegistrations = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando registros de eventos: $e');
      if (mounted) {
        setState(() => _loadingRegistrations = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: GingaColors.textPrimary, size: 18),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
        title: Text(
          'Eventos y Talleres',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: GingaColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: GingaColors.brandGreen),
                const SizedBox(width: 4),
                Text(
                  _userSede,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // ── Filtros Rápidos (Categorías) ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterTab(0, 'Próximos'),
                  const SizedBox(width: 8),
                  _buildFilterTab(1, 'Inscrito 🎟️'),
                  const SizedBox(width: 8),
                  _buildFilterTab(2, 'Historial'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Lista de eventos ─────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('eventos')
                    .orderBy('fecha_inicio', descending: _selectedFilterIndex == 2)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting || _loadingRegistrations) {
                    return const Center(
                      child: CircularProgressIndicator(color: GingaColors.brandGreen),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final now = DateTime.now();
                  final allDocs = snapshot.data!.docs;

                  // Filtrar client-side según la pestaña seleccionada
                  final List<QueryDocumentSnapshot> filteredDocs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final bool publicado = data['publicar_inmediatamente'] ?? true;
                    if (!publicado) return false;

                    final Timestamp? endTs = data['fecha_fin'] as Timestamp?;
                    final DateTime? end = endTs?.toDate();

                    if (_selectedFilterIndex == 0) {
                      // Próximos: que no hayan pasado
                      return end == null || end.isAfter(now);
                    } else if (_selectedFilterIndex == 1) {
                      // Inscrito: que el ID esté en los registrados y que no hayan pasado
                      final isReg = _registeredEventIds.contains(doc.id);
                      final isFuture = end == null || end.isAfter(now);
                      return isReg && isFuture;
                    } else {
                      // Pasados: que ya hayan culminado
                      return end != null && end.isBefore(now);
                    }
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isRegistered = _registeredEventIds.contains(doc.id);

                      return _EventoCard(
                        eventId: doc.id,
                        data: data,
                        isRegistered: isRegistered,
                        onTapDetails: () async {
                          await context.push('/evento-detalle?eventId=${doc.id}');
                          // Al regresar, refrescar la lista de registros
                          _cargarRegistrosUsuario();
                        },
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

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;
    final unselectedTextColor = isDark ? GingaColors.textMuted : GingaColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? GingaColors.brandGreen : unselectedBg,
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(
              color: isSelected ? GingaColors.brandGreen : borderColor,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: GingaColors.brandGreen.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : unselectedTextColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title = 'No hay eventos programados';
    String desc = 'Vuelve a revisar pronto para conocer los talleres y rodas especiales.';
    IconData icon = Icons.event_busy_rounded;

    if (_selectedFilterIndex == 1) {
      title = 'Aún no estás inscrito';
      desc = 'Explora la pestaña "Próximos" e inscríbete a los talleres para ver tus tickets aquí.';
      icon = Icons.confirmation_number_outlined;
    } else if (_selectedFilterIndex == 2) {
      title = 'No hay eventos pasados';
      desc = 'Los eventos que finalicen aparecerán aquí en tu historial.';
      icon = Icons.history_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GingaColors.cardLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: GingaColors.brandGreen.withOpacity(0.6), size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: GingaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: GingaColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  EVENTO CARD (DINÁMICO)
// ─────────────────────────────────────────

class _EventoCard extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> data;
  final bool isRegistered;
  final VoidCallback onTapDetails;

  const _EventoCard({
    required this.eventId,
    required this.data,
    required this.isRegistered,
    required this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = data['titulo'] ?? 'Taller Especial';
    final fechaTexto = data['fecha_texto'] ?? 'Fecha por confirmar';
    final lugar = data['lugar'] ?? 'Por definir';
    final imagenUrl = data['imagen_url'] ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;
    final textColor = isDark ? GingaColors.textWhite : GingaColors.textPrimary;
    final subtitleColor = isDark ? GingaColors.textMuted : GingaColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Imagen ──────────────────────────────
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(GingaRadius.lg),
                  topRight: Radius.circular(GingaRadius.lg),
                ),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: GingaColors.backgroundDark,
                  child: GingaCachedImage(
                    imageUrl: imagenUrl,
                    fit: BoxFit.cover,
                    category: 'evento',
                    errorWidget: const Center(
                      child: Icon(
                        Icons.sports_martial_arts,
                        color: GingaColors.brandGreen,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
              // Badge de Inscrito
              if (isRegistered)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen,
                      borderRadius: BorderRadius.circular(GingaRadius.sm),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'INSCRITO',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Info ────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: subtitleColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fechaTexto,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: subtitleColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lugar,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Botón Ver Detalles
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onTapDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Ver Detalles',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}