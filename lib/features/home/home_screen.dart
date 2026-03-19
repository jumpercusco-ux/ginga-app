import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';
import '../eventos/eventos_screen.dart';
import '../perfil/progreso_screen.dart';
import '../biblioteca/biblioteca_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          _HomeDashboard(),
          EventosScreen(),
          BibliotecaScreen(),
          ProgresoScreen(),
        ],
      ),
      bottomNavigationBar: _GingaBottomNav(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  DASHBOARD PRINCIPAL
// ─────────────────────────────────────────

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const _Header(),
            const SizedBox(height: 20),
            _WorkshopBanner(),
            const SizedBox(height: 20),
            _CheckInCard(),
            const SizedBox(height: 12),

            // Botón temporal Instructor
            GestureDetector(
              onTap: () => context.go('/instructor-clase'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('Vista Instructor (Prueba)',
                        style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            _SectionTitle(title: 'Clases del día', actionLabel: 'Ver todas'),
            const SizedBox(height: 12),
            _ClaseCard(
              hora: '18:00',
              nivel: 'Iniciantes',
              badge: 'INICIO',
              badgeColor: GingaColors.brandGreen,
              instructor: 'Contra Mestre Orue',
              cupos: '4 cupos disponibles',
            ),
            const SizedBox(height: 10),
            _ClaseCard(
              hora: '19:30',
              nivel: 'Adultos',
              badge: 'MAGISTRAL',
              badgeColor: GingaColors.accentAmber,
              instructor: 'Contra Mestre Cam',
              cupos: '2 cupos restantes',
            ),
            const SizedBox(height: 10),
            _ClaseCard(
              hora: '21:00',
              nivel: 'Avanzados',
              badge: 'PRO',
              badgeColor: GingaColors.brandGreen,
              instructor: 'Mestre Orue',
              cupos: '11 cupos disponibles',
            ),
            const SizedBox(height: 20),
            _SectionTitle(
                title: 'Últimas noticias', actionLabel: 'JUMPER STUDIO'),
            const SizedBox(height: 12),
            _NoticiasRow(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HEADER — datos reales de Firestore
// ─────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Datos por defecto mientras carga
        String nombre = 'Alumno';
        String corda = 'Iniciación';
        String inicial = 'A';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          nombre = data['nombre'] ?? 'Alumno';
          corda = data['corda'] ?? 'Iniciación';
          inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';
        }

        return Row(
          children: [
            Flexible(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('¡Hola, $nombre!',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: GingaColors.brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      corda,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: GingaColors.brandGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),),
            const Spacer(),
            // Timer
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: GingaColors.cardLight,
                borderRadius: BorderRadius.circular(GingaRadius.full),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: GingaColors.brandGreen),
                  const SizedBox(width: 4),
                  Text('2a 4m',
                      style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GingaColors.brandGreen)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Avatar con inicial real
            CircleAvatar(
              radius: 20,
              backgroundColor: GingaColors.cardLight,
              child: Text(
                inicial,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: GingaColors.brandGreen,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  WORKSHOP BANNER
// ─────────────────────────────────────────

class _WorkshopBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GingaColors.accentAmber,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workshop con Prof.',
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF412402))),
                Text('Daniel - Abril',
                    style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF412402))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF412402),
                    borderRadius: BorderRadius.circular(GingaRadius.full),
                  ),
                  child: Text('Reservar',
                      style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF412402).withOpacity(0.15),
              borderRadius: BorderRadius.circular(GingaRadius.md),
            ),
            child: const Icon(Icons.sports_martial_arts,
                size: 40, color: Color(0xFF412402)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CHECK-IN RÁPIDO
// ─────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text('Check-in rápido',
                    style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Escanea el código al llegar a la academia',
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: GingaColors.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: GingaColors.cardLight,
              borderRadius: BorderRadius.circular(GingaRadius.md),
            ),
            child: const Icon(Icons.qr_code_scanner,
                size: 30, color: GingaColors.brandGreen),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CLASE CARD
// ─────────────────────────────────────────

class _ClaseCard extends StatelessWidget {
  final String hora;
  final String nivel;
  final String badge;
  final Color badgeColor;
  final String instructor;
  final String cupos;

  const _ClaseCard({
    required this.hora,
    required this.nivel,
    required this.badge,
    required this.badgeColor,
    required this.instructor,
    required this.cupos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(hora,
                style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 40, color: GingaColors.borderLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(nivel,
                        style: GoogleFonts.montserrat(
                            fontSize: 14,
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
                              color: badgeColor,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(instructor,
                    style: GoogleFonts.nunito(
                        fontSize: 12, color: GingaColors.textSecondary)),
                Text(cupos,
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: GingaColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: GingaColors.brandGreen,
              borderRadius: BorderRadius.circular(GingaRadius.full),
            ),
            child: Text('Reservar',
                style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SECTION TITLE
// ─────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  const _SectionTitle({required this.title, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: GingaColors.textPrimary)),
        Text(actionLabel,
            style: GoogleFonts.nunito(
                fontSize: 12,
                color: GingaColors.brandGreen,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  NOTICIAS ROW
// ─────────────────────────────────────────

class _NoticiasRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _NoticiaCard(
                titulo: 'Nueva Roda de Domingo',
                subtitulo: 'Preparate para la entrega...')),
        const SizedBox(width: 12),
        Expanded(
            child: _NoticiaCard(
                titulo: 'Tips: Movimientos',
                subtitulo: 'Mejora tu ginga en casa...')),
      ],
    );
  }
}

class _NoticiaCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  const _NoticiaCard({required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: GingaColors.backgroundDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(GingaRadius.lg),
                topRight: Radius.circular(GingaRadius.lg),
              ),
            ),
            child: const Center(
              child: Icon(Icons.sports_martial_arts,
                  color: GingaColors.brandGreen, size: 32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(subtitulo,
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: GingaColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  BOTTOM NAV
// ─────────────────────────────────────────

class _GingaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GingaBottomNav({
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'A Roda'),
        BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Biblioteca'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil'),
      ],
    );
  }
}