import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import '../perfil/progreso_screen.dart';
import 'qr_generator_screen.dart';
import 'instructor_alumnos_screen.dart';

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

            Text('Reservas recientes',
                style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservas')
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GingaColors.cardLight,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                    ),
                    child: Center(
                      child: Text('No hay reservas aún',
                          style: GoogleFonts.nunito(
                              color: GingaColors.textSecondary)),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _ReservaCard(
                      nivel: data['nivel'] ?? '',
                      hora: data['hora'] ?? '',
                      dias: data['dias'] ?? '',
                      status: data['status'] ?? 'confirmado',
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen,
                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                ),
                child: Text(hora,
                    style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(nivel,
                            style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
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
                          style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: GingaColors.textSecondary)),
                  ],
                ),
              ),
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