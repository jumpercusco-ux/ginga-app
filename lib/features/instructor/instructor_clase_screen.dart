import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import '../perfil/progreso_screen.dart';
import 'qr_generator_screen.dart';
import 'instructor_alumnos_screen.dart';
import '../biblioteca/cancionero_screen.dart';

// Función global de navegación al QR Generator
void _navigateToQrGenerator(
    BuildContext context, String claseId, String nivel, String hora) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (BuildContext ctx) => QrGeneratorScreen(
        claseId: claseId,
        nivel: nivel,
        hora: hora,
      ),
    ),
  );
}

class InstructorClaseScreen extends StatefulWidget {
  const InstructorClaseScreen({super.key});

  @override
  State<InstructorClaseScreen> createState() => _InstructorClaseScreenState();
}

class _InstructorClaseScreenState extends State<InstructorClaseScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          _InstructorDashboard(),
          InstructorAlumnosScreen(),
          ProgresoScreen(),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/crear-clase'),
              backgroundColor: GingaColors.brandGreen,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add),
              label: Text(
                'Crea tu clase',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      bottomNavigationBar: _InstructorBottomNav(
        currentIndex: _selectedTab,
        onTap: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
      ),
    );
  }
}

class _InstructorDashboard extends StatelessWidget {
  const _InstructorDashboard();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // ── Header ──────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vista Instructor',
                        style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary)),
                    Text('Gestión de clases',
                        style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: GingaColors.textSecondary)),
                  ],
                ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: GingaColors.brandGreen,
                  child: Text('I',
                      style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 18)),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text('Clases de hoy',
                style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clases')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: GingaColors.brandGreen),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GingaColors.cardLight,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                    ),
                    child: Center(
                      child: Text('No hay clases registradas',
                          style: GoogleFonts.nunito(
                              color: GingaColors.textSecondary)),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ClaseInstructorCard(
                        claseId: doc.id,
                        hora: data['hora'] ?? '',
                        nivel: data['nivel'] ?? '',
                        badge: data['badge'] ?? '',
                        dias: data['dias'] ?? '',
                        cuposDisponibles: data['cupos_disponibles'] ?? 0,
                        cuposMax: data['cupos_max'] ?? 10,
                        tipo: data['tipo'] ?? 'regular',
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            Text('Gestión de Tienda 📦',
                style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(GingaRadius.lg),
                border: Border.all(color: GingaColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Inventario & Catálogo',
                            style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Administra precios, stock o agrega nuevos productos para que los alumnos los reserven.',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: GingaColors.textSecondary,
                                height: 1.4)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => context.push('/instructor-tienda'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GingaColors.brandGreen,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text('Gestionar Tienda',
                              style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text('Gestión de Biblioteca 📽️',
                style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(GingaRadius.lg),
                border: Border.all(color: GingaColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tutoriales & Clases',
                            style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Crea, edita o elimina los tutoriales on-demand que los alumnos practican desde la biblioteca.',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: GingaColors.textSecondary,
                                height: 1.4)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => context.push('/instructor-tutoriales'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GingaColors.brandGreen,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text('Gestionar Tutoriales',
                              style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(GingaRadius.lg),
                border: Border.all(color: GingaColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cancionero & Karaoke 🎤',
                            style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Sincroniza las letras de cantigas de capoeira en tiempo real para activar el modo Karaoke de tus alumnos.',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: GingaColors.textSecondary,
                                height: 1.4)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CancioneroScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GingaColors.brandGreen,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text('Ver Cancionero',
                              style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text('Historial de Sesiones y Asistencias 📅',
                style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clases')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: GingaColors.brandGreen),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GingaColors.cardLight,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      border: Border.all(color: GingaColors.borderLight),
                    ),
                    child: Center(
                      child: Text('No hay clases registradas aún',
                          style: GoogleFonts.nunito(
                              color: GingaColors.textSecondary)),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final claseId = doc.id;
                    final nivel = data['nivel'] ?? 'Clase';
                    final hora = data['hora'] ?? '';
                    final badge = data['badge'] ?? '';
                    final dias = data['dias'] ?? '';
                    final tipo = data['tipo'] ?? 'regular';

                    return _ClaseHistorialGroupCard(
                      claseId: claseId,
                      nivel: nivel,
                      hora: hora,
                      badge: badge,
                      dias: dias,
                      tipo: tipo,
                    );
                  }).toList(),
                );
              },
            ),



            const SizedBox(height: 100), // Espacio extra para que el FAB no oculte contenido importante al final del scroll
          ],
        ),
      ),
    );
  }
}

class _InstructorBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _InstructorBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: GingaColors.brandGreen,
      unselectedItemColor: GingaColors.textSecondary,
      selectedLabelStyle:
          GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 11),
      elevation: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.class_outlined),
          activeIcon: Icon(Icons.class_),
          label: 'Clases',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Alumnos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Mi Perfil',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  CLASE INSTRUCTOR CARD
// ─────────────────────────────────────────

class _ClaseInstructorCard extends StatelessWidget {
  final String claseId;
  final String hora;
  final String nivel;
  final String badge;
  final String dias;
  final int cuposDisponibles;
  final int cuposMax;
  final String tipo;

  const _ClaseInstructorCard({
    required this.claseId,
    required this.hora,
    required this.nivel,
    required this.badge,
    required this.dias,
    required this.cuposDisponibles,
    required this.cuposMax,
    required this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = tipo == 'roda'
        ? GingaColors.accentAmber
        : GingaColors.brandGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: hora.contains('-') || hora.length > 5 ? 82 : 62,
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen,
                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                ),
                child: Center(
                  child: Text(
                    hora,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                        fontSize: hora.contains('-') || hora.length > 5 ? 10 : 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nivel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge,
                              style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor)),
                        ),
                      ],
                    ),
                    if (dias.isNotEmpty)
                      Text(dias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: GingaColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$cuposDisponibles/$cuposMax',
                      style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cuposDisponibles == 0
                              ? Colors.red
                              : GingaColors.brandGreen)),
                  Text('cupos',
                      style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: GingaColors.textSecondary)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _navigateToQrGenerator(context, claseId, nivel, hora),
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.qr_code, size: 18),
              label: Text('Generar QR de asistencia',
                  style: GoogleFonts.montserrat(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  RESERVA CARD
// ─────────────────────────────────────────

class _ReservaCard extends StatelessWidget {
  final String nivel;
  final String hora;
  final String dias;
  final String status;

  const _ReservaCard({
    required this.nivel,
    required this.hora,
    required this.dias,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GingaColors.brandGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(GingaRadius.sm),
            ),
            child: const Icon(Icons.person_outline,
                color: GingaColors.brandGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nivel,
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary)),
                Text('$hora — $dias',
                    style: GoogleFonts.nunito(
                        fontSize: 12, color: GingaColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: GingaColors.brandGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(GingaRadius.full),
            ),
            child: Text(status,
                style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.brandGreen)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HISTORIAL DE SESIONES & DETALLES CARD
// ─────────────────────────────────────────

// ─────────────────────────────────────────
//  HISTORIAL DE SESIONES AGRUPADAS POR CLASE
// ─────────────────────────────────────────

class _ClaseHistorialGroupCard extends StatefulWidget {
  final String claseId;
  final String nivel;
  final String hora;
  final String badge;
  final String dias;
  final String tipo;

  const _ClaseHistorialGroupCard({
    required this.claseId,
    required this.nivel,
    required this.hora,
    required this.badge,
    required this.dias,
    required this.tipo,
  });

  @override
  State<_ClaseHistorialGroupCard> createState() => _ClaseHistorialGroupCardState();
}

class _ClaseHistorialGroupCardState extends State<_ClaseHistorialGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.tipo == 'roda'
        ? GingaColors.accentAmber
        : GingaColors.brandGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              onExpansionChanged: (val) {
                setState(() => _expanded = val);
              },
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: badgeColor.withValues(alpha: 0.1),
                child: Icon(
                  Icons.class_outlined,
                  color: badgeColor,
                  size: 18,
                ),
              ),
              title: Text(
                widget.nivel,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: GingaColors.textPrimary,
                ),
              ),
              subtitle: Text(
                '${widget.hora} — ${widget.dias}',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: GingaColors.textSecondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.badge,
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: GingaColors.textSecondary,
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sesiones')
                        .where('clase_id', isEqualTo: widget.claseId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: GingaColors.brandGreen, strokeWidth: 2),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No se han iniciado sesiones de esta clase aún.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: GingaColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs.toList();
                      
                      docs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTime = aData['created_at'] as Timestamp?;
                        final bTime = bData['created_at'] as Timestamp?;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 1,
                            color: GingaColors.borderLight,
                            margin: const EdgeInsets.only(bottom: 12),
                          ),
                          Text(
                            'Sesiones registradas:',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...docs.map((doc) {
                            final sesionData = doc.data() as Map<String, dynamic>;
                            final String sesionId = doc.id;
                            final String fecha = sesionData['fecha'] ?? '';
                            final String hora = sesionData['hora'] ?? '';
                            final bool activa = sesionData['activa'] ?? false;

                            return _SessionDateItem(
                              sesionId: sesionId,
                              nivel: widget.nivel,
                              hora: hora,
                              fecha: fecha,
                              activa: activa,
                            );
                          }),
                        ],
                      );
                    },
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

// Item individual para cada fecha de sesión dentro del acordeón
class _SessionDateItem extends StatelessWidget {
  final String sesionId;
  final String nivel;
  final String hora;
  final String fecha;
  final bool activa;

  const _SessionDateItem({
    required this.sesionId,
    required this.nivel,
    required this.hora,
    required this.fecha,
    required this.activa,
  });

  void _mostrarAsistencias(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: GingaColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detalles de Asistencia',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$nivel — $fecha ($hora)',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: GingaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('asistencias')
                          .where('sesion_id', isEqualTo: sesionId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: GingaColors.brandGreen),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'Ningún alumno registró asistencia en esta sesión.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: GingaColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs.toList();
                        docs.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aTime = aData['created_at'] as Timestamp?;
                          final bTime = bData['created_at'] as Timestamp?;
                          if (aTime == null && bTime == null) return 0;
                          if (aTime == null) return 1;
                          if (bTime == null) return -1;
                          return bTime.compareTo(aTime);
                        });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${docs.length} ${docs.length == 1 ? 'alumno registrado' : 'alumnos registrados'}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.brandGreen,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.builder(
                                controller: scrollController,
                                itemCount: docs.length,
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).padding.bottom > 0
                                      ? MediaQuery.of(context).padding.bottom + 16
                                      : 16,
                                ),
                                itemBuilder: (context, index) {
                                  final data = docs[index].data() as Map<String, dynamic>;
                                  return _AttendeeHistorialTile(attendance: data);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: GingaColors.backgroundLight,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(
          activa ? Icons.qr_code_scanner : Icons.calendar_today_outlined,
          color: activa ? GingaColors.brandGreen : GingaColors.textSecondary,
          size: 16,
        ),
        title: Text(
          fecha,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: GingaColors.textPrimary,
          ),
        ),
        subtitle: Text(
          hora,
          style: GoogleFonts.nunito(
            fontSize: 10,
            color: GingaColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: activa
                    ? GingaColors.brandGreen.withValues(alpha: 0.1)
                    : GingaColors.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                activa ? 'ACTIVA' : 'CERRADA',
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: activa ? GingaColors.brandGreen : GingaColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: GingaColors.textSecondary,
              size: 16,
            ),
          ],
        ),
        onTap: () => _mostrarAsistencias(context),
      ),
    );
  }
}

// Tile local para renderizar el alumno en el historial de asistencia de la sesión
class _AttendeeHistorialTile extends StatelessWidget {
  final Map<String, dynamic> attendance;

  const _AttendeeHistorialTile({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final String userId = attendance['user_id'] ?? '';
    final String? cachedName = attendance['user_name'];
    final String? cachedEmail = attendance['user_email'];
    final Timestamp? createdAt = attendance['created_at'] as Timestamp?;

    final String timeStr = createdAt != null 
        ? _formatTime(createdAt.toDate()) 
        : (attendance['hora'] ?? '');

    if (cachedName != null && cachedName.isNotEmpty) {
      return _buildTile(cachedName, cachedEmail ?? 'Sin correo', timeStr);
    }

    // Fallback para asistencias antiguas sin denormalización
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildTile('Cargando...', '...', timeStr);
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final name = userData['nombre'] ?? 'Sin nombre';
        final email = userData['email'] ?? 'Sin correo';
        return _buildTile(name, email, timeStr);
      },
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildTile(String name, String email, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GingaColors.backgroundLight,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: GingaColors.brandGreen.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: GingaColors.brandGreen, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    color: GingaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: GingaColors.brandGreen,
            ),
          ),
        ],
      ),
    );
  }
}