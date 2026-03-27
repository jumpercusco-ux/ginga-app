import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';
import '../eventos/eventos_screen.dart';
import '../perfil/progreso_screen.dart';
import '../biblioteca/biblioteca_screen.dart';
import 'qr_scanner_screen.dart';

// Función global de navegación al QR Scanner
void _navigateToQrScanner(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (BuildContext ctx) => QrScannerScreen()),
  );
}

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
            const SizedBox(height: 20),
            _SectionTitle(title: 'Clases del día', actionLabel: 'Ver todas'),
            const SizedBox(height: 12),
            _ClasesFirestore(),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Últimas noticias', actionLabel: 'Ver todas'),
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
//  CLASES DESDE FIRESTORE
// ─────────────────────────────────────────

class _ClasesFirestore extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: GingaColors.brandGreen,
              strokeWidth: 2,
            ),
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
              child: Text(
                'No hay clases disponibles hoy',
                style: GoogleFonts.nunito(
                    fontSize: 14, color: GingaColors.textSecondary),
              ),
            ),
          );
        }

        final clases = snapshot.data!.docs;

        return Column(
          children: clases.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final cuposDisponibles = data['cupos_disponibles'] ?? 0;
            final cuposMax = data['cupos_max'] ?? 10;
            final badgeColor = data['tipo'] == 'roda'
                ? GingaColors.accentAmber
                : GingaColors.brandGreen;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ClaseCardFirestore(
                claseId: doc.id,
                hora: data['hora'] ?? '',
                nivel: data['nivel'] ?? '',
                badge: data['badge'] ?? '',
                badgeColor: badgeColor,
                instructor: data['instructor'] ?? '',
                dias: data['dias'] ?? '',
                cuposDisponibles: cuposDisponibles,
                cuposMax: cuposMax,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  CLASE CARD CON RESERVA REAL
// ─────────────────────────────────────────

class _ClaseCardFirestore extends StatefulWidget {
  final String claseId;
  final String hora;
  final String nivel;
  final String badge;
  final Color badgeColor;
  final String instructor;
  final String dias;
  final int cuposDisponibles;
  final int cuposMax;

  const _ClaseCardFirestore({
    required this.claseId,
    required this.hora,
    required this.nivel,
    required this.badge,
    required this.badgeColor,
    required this.instructor,
    required this.dias,
    required this.cuposDisponibles,
    required this.cuposMax,
  });

  @override
  State<_ClaseCardFirestore> createState() => _ClaseCardFirestoreState();
}

class _ClaseCardFirestoreState extends State<_ClaseCardFirestore> {
  bool _isReservado = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkReserva();
  }

  Future<void> _checkReserva() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final reserva = await FirebaseFirestore.instance
        .collection('reservas')
        .where('user_id', isEqualTo: uid)
        .where('clase_id', isEqualTo: widget.claseId)
        .get();

    if (mounted && reserva.docs.isNotEmpty) {
      setState(() => _isReservado = true);
    }
  }

  Future<void> _reservar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (widget.cuposDisponibles <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay cupos disponibles',
              style: GoogleFonts.nunito(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final claseRef = FirebaseFirestore.instance
            .collection('clases')
            .doc(widget.claseId);

        final claseDoc = await transaction.get(claseRef);
        final cupos = claseDoc['cupos_disponibles'] as int;

        if (cupos <= 0) throw Exception('Sin cupos');

        transaction.update(claseRef, {'cupos_disponibles': cupos - 1});

        final reservaRef =
            FirebaseFirestore.instance.collection('reservas').doc();
        transaction.set(reservaRef, {
          'user_id': uid,
          'clase_id': widget.claseId,
          'nivel': widget.nivel,
          'hora': widget.hora,
          'dias': widget.dias,
          'status': 'confirmado',
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        setState(() => _isReservado = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Reserva confirmada! 🎉',
                style: GoogleFonts.nunito(color: Colors.white)),
            backgroundColor: GingaColors.brandGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reservar. Intenta de nuevo.',
                style: GoogleFonts.nunito(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuposText = widget.cuposDisponibles == 0
        ? 'Sin cupos'
        : '${widget.cuposDisponibles} cupos disponibles';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(
          color: _isReservado
              ? GingaColors.brandGreen.withOpacity(0.4)
              : GingaColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(widget.hora,
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
                    Text(widget.nivel,
                        style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(widget.badge,
                          style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: widget.badgeColor,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (widget.dias.isNotEmpty)
                  Text(widget.dias,
                      style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: GingaColors.textSecondary)),
                Text(widget.instructor,
                    style: GoogleFonts.nunito(
                        fontSize: 12, color: GingaColors.textSecondary)),
                Text(cuposText,
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: widget.cuposDisponibles == 0
                            ? Colors.red
                            : GingaColors.textSecondary)),
              ],
            ),
          ),
          _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: GingaColors.brandGreen, strokeWidth: 2),
                )
              : GestureDetector(
                  onTap: _isReservado ? null : _reservar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _isReservado
                          ? GingaColors.cardLight
                          : widget.cuposDisponibles == 0
                              ? GingaColors.borderLight
                              : GingaColors.brandGreen,
                      borderRadius:
                          BorderRadius.circular(GingaRadius.full),
                    ),
                    child: Text(
                      _isReservado ? '✓ Reservado' : 'Reservar',
                      style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isReservado
                              ? GingaColors.brandGreen
                              : Colors.white),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HEADER
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
                  Text('¡Hola,',
                      style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: GingaColors.textSecondary)),
                  Text(nombre,
                      style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary)),
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
                      Text(corda,
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: GingaColors.brandGreen,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
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
            CircleAvatar(
              radius: 20,
              backgroundColor: GingaColors.cardLight,
              child: Text(inicial,
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      color: GingaColors.brandGreen,
                      fontSize: 16)),
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
                Text('Taller Intensivo con Prof.',
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF412402))),
                Text('Daniel Vereau \n13 al 28 Abril',
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
          ClipRRect(
            borderRadius: BorderRadius.circular(GingaRadius.md),
            child: Image.asset('assets/images/dani.jpg',
                width: 120, height: 120, fit: BoxFit.cover),
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
          GestureDetector(
            onTap: () => _navigateToQrScanner(context),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: GingaColors.cardLight,
                borderRadius: BorderRadius.circular(GingaRadius.md),
              ),
              child: const Icon(Icons.qr_code_scanner,
                  size: 30, color: GingaColors.brandGreen),
            ),
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
            titulo: 'Roda de Sábado',
            subtitulo: 'Preparate para poner a prueba...',
            imagePath: 'assets/images/roda.jpg',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _NoticiaCard(
            titulo: 'Tips: Movimientos',
            subtitulo: 'Mejora tu ginga y técnica en casa...',
            imagePath: 'assets/images/moves.jpg',
          ),
        ),
      ],
    );
  }
}

class _NoticiaCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String? imagePath;

  const _NoticiaCard({
    required this.titulo,
    required this.subtitulo,
    this.imagePath,
  });

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
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(GingaRadius.lg),
              topRight: Radius.circular(GingaRadius.lg),
            ),
            child: imagePath != null
                ? Image.asset(imagePath!,
                    height: 90,
                    width: double.infinity,
                    fit: BoxFit.cover)
                : Container(
                    height: 90,
                    color: GingaColors.backgroundDark,
                    child: const Center(
                      child: Icon(Icons.sports_martial_arts,
                          color: GingaColors.brandGreen, size: 32),
                    ),
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