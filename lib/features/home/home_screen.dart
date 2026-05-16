import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';
import '../eventos/eventos_screen.dart';
import '../perfil/progreso_screen.dart';
import '../biblioteca/biblioteca_screen.dart';
import 'qr_scanner_screen.dart';

// Constantes de estado
class UserStatus {
  static const nuevo    = 'nuevo';
  static const prueba   = 'prueba';
  static const activo   = 'activo';
  static const inactivo = 'inactivo';
}

// Función global navegación QR
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: GingaColors.brandGreen),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final status = data['status'] ?? UserStatus.nuevo;
        final nombre = data['nombre'] ?? 'Alumno';
        final corda = data['corda'] ?? 'Iniciación';
        final claseId = data['clase_id'] ?? '';

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header siempre visible
                _Header(nombre: nombre, corda: corda),
                const SizedBox(height: 20),

                // Banner según estado
                _StatusBanner(status: status),
                const SizedBox(height: 20),

                // Contenido según estado
                _ContentByStatus(
                  status: status,
                  claseId: claseId,
                  uid: uid ?? '',
                ),

                const SizedBox(height: 20),

                // Noticias — siempre visible
                _SectionTitle(
                    title: 'Últimas noticias', actionLabel: 'Ver todas'),
                const SizedBox(height: 12),
                _NoticiasRow(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  BANNER POR ESTADO
// ─────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case UserStatus.nuevo:
        return _Banner(
          color: GingaColors.brandGreen,
          icono: Icons.celebration_outlined,
          titulo: '¡Tu primera clase es GRATIS!',
          subtitulo: 'Elige un horario y reserva tu lugar ahora.',
          accion: 'Reservar ahora',
          onTap: () {},
        );
      case UserStatus.prueba:
        return _Banner(
          color: GingaColors.accentAmber,
          icono: Icons.access_time_outlined,
          titulo: '¡Te esperamos en tu primera clase!',
          subtitulo: 'Revisa tu horario reservado y llega 10 min antes.',
          accion: 'Ver mi reserva',
          onTap: () {},
        );
      case UserStatus.inactivo:
        return _Banner(
          color: Colors.red.shade400,
          icono: Icons.warning_amber_outlined,
          titulo: 'Renueva tu mensualidad',
          subtitulo: 'Tu acceso está pausado. Contáctanos para renovar.',
          accion: 'Contactar',
          onTap: () {},
        );
      default:
        // Activo — banner del workshop
        return _WorkshopBanner();
    }
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String accion;
  final VoidCallback onTap;

  const _Banner({
    required this.color,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.accion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icono, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(titulo,
                          style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(subtitulo,
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                    ),
                    child: Text(accion,
                        style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color)),
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

// ─────────────────────────────────────────
//  CONTENIDO POR ESTADO
// ─────────────────────────────────────────

class _ContentByStatus extends StatelessWidget {
  final String status;
  final String claseId;
  final String uid;

  const _ContentByStatus({
    required this.status,
    required this.claseId,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {

      // NUEVO — ve todas las clases para elegir la de prueba
      case UserStatus.nuevo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
                title: 'Clases disponibles', actionLabel: ''),
            const SizedBox(height: 12),
            _ClasesNuevo(uid: uid),
          ],
        );

      // PRUEBA — ve su reserva pendiente
      case UserStatus.prueba:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Tu reserva', actionLabel: ''),
            const SizedBox(height: 12),
            _ReservaPendiente(uid: uid),
          ],
        );

      // ACTIVO — ve su clase + check-in QR
      case UserStatus.activo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Tu clase', actionLabel: ''),
            const SizedBox(height: 12),
            _ClaseActivo(claseId: claseId),
            const SizedBox(height: 16),
            _CheckInCard(),
          ],
        );

      // INACTIVO — ve su clase bloqueada
      case UserStatus.inactivo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Tu clase', actionLabel: ''),
            const SizedBox(height: 12),
            _ClaseInactivo(claseId: claseId),
          ],
        );

      default:
        return const SizedBox();
    }
  }
}

// ─────────────────────────────────────────
//  CLASES PARA NUEVO (todas disponibles)
// ─────────────────────────────────────────

class _ClasesNuevo extends StatelessWidget {
  final String uid;
  const _ClasesNuevo({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: GingaColors.brandGreen, strokeWidth: 2),
          );
        }

        final clases = snapshot.data!.docs;

        return Column(
          children: clases.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ClaseCardNuevo(
                claseId: doc.id,
                hora: data['hora'] ?? '',
                nivel: data['nivel'] ?? '',
                badge: data['badge'] ?? '',
                dias: data['dias'] ?? '',
                instructor: data['instructor'] ?? '',
                cuposDisponibles: data['cupos_disponibles'] ?? 0,
                tipo: data['tipo'] ?? 'regular',
                uid: uid,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ClaseCardNuevo extends StatefulWidget {
  final String claseId;
  final String hora;
  final String nivel;
  final String badge;
  final String dias;
  final String instructor;
  final int cuposDisponibles;
  final String tipo;
  final String uid;

  const _ClaseCardNuevo({
    required this.claseId,
    required this.hora,
    required this.nivel,
    required this.badge,
    required this.dias,
    required this.instructor,
    required this.cuposDisponibles,
    required this.tipo,
    required this.uid,
  });

  @override
  State<_ClaseCardNuevo> createState() => _ClaseCardNuevoState();
}

class _ClaseCardNuevoState extends State<_ClaseCardNuevo> {
  bool _isLoading = false;
  bool _isReservado = false;

  @override
  void initState() {
    super.initState();
    _checkReserva();
  }

  Future<void> _checkReserva() async {
    final reserva = await FirebaseFirestore.instance
        .collection('reservas')
        .where('user_id', isEqualTo: widget.uid)
        .where('clase_id', isEqualTo: widget.claseId)
        .get();
    if (mounted && reserva.docs.isNotEmpty) {
      setState(() => _isReservado = true);
    }
  }

  Future<void> _reservarPrueba() async {
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
          'user_id': widget.uid,
          'clase_id': widget.claseId,
          'nivel': widget.nivel,
          'hora': widget.hora,
          'dias': widget.dias,
          'status': 'confirmado',
          'tipo': 'prueba',
          'created_at': FieldValue.serverTimestamp(),
        });

        // Cambia status del usuario a "prueba"
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid);
        transaction.update(userRef, {'status': UserStatus.prueba});
      });

      if (mounted) {
        setState(() => _isReservado = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Clase de prueba reservada! 🎉',
              style: GoogleFonts.nunito(color: Colors.white)),
          backgroundColor: GingaColors.brandGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al reservar. Intenta de nuevo.',
              style: GoogleFonts.nunito(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.tipo == 'roda'
        ? GingaColors.accentAmber
        : GingaColors.brandGreen;

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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textPrimary)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(widget.badge,
                          style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: badgeColor)),
                    ),
                  ],
                ),
                if (widget.dias.isNotEmpty)
                  Text(widget.dias,
                      style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: GingaColors.textSecondary)),
                Text(widget.instructor,
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: GingaColors.textSecondary)),
              ],
            ),
          ),
          _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: GingaColors.brandGreen, strokeWidth: 2))
              : GestureDetector(
                  onTap: _isReservado ? null : _reservarPrueba,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _isReservado
                          ? GingaColors.cardLight
                          : GingaColors.brandGreen,
                      borderRadius:
                          BorderRadius.circular(GingaRadius.full),
                    ),
                    child: Text(
                      _isReservado ? '✓ Reservado' : 'Gratis',
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
//  RESERVA PENDIENTE (PRUEBA)
// ─────────────────────────────────────────

class _ReservaPendiente extends StatelessWidget {
  final String uid;
  const _ReservaPendiente({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservas')
          .where('user_id', isEqualTo: uid)
          .where('tipo', isEqualTo: 'prueba')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GingaColors.cardLight,
              borderRadius: BorderRadius.circular(GingaRadius.lg),
            ),
            child: Text('No se encontró tu reserva.',
                style: GoogleFonts.nunito(
                    color: GingaColors.textSecondary)),
          );
        }

        final reserva =
            snapshot.data!.docs.first.data() as Map<String, dynamic>;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            border: Border.all(
                color: GingaColors.accentAmber.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GingaColors.accentAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                child: const Icon(Icons.event_available,
                    color: GingaColors.accentAmber, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reserva['nivel'] ?? '',
                        style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textPrimary)),
                    Text('${reserva['hora']} — ${reserva['dias']}',
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: GingaColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GingaColors.accentAmber.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(GingaRadius.full),
                      ),
                      child: Text('CLASE DE PRUEBA',
                          style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.accentAmber)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  CLASE ACTIVO (su clase matriculada)
// ─────────────────────────────────────────

class _ClaseActivo extends StatelessWidget {
  final String claseId;
  const _ClaseActivo({required this.claseId});

  @override
  Widget build(BuildContext context) {
    if (claseId.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GingaColors.cardLight,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
        ),
        child: Text('Contacta al instructor para asignarte una clase.',
            style: GoogleFonts.nunito(
                color: GingaColors.textSecondary)),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .doc(claseId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator(
              color: GingaColors.brandGreen);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            border: Border.all(
                color: GingaColors.brandGreen.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 14),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen,
                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                ),
                child: Text(data['hora'] ?? '',
                    style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['nivel'] ?? '',
                        style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textPrimary)),
                    Text(data['dias'] ?? '',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: GingaColors.textSecondary)),
                    Text(data['instructor'] ?? '',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: GingaColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                child: Text('ACTIVO',
                    style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.brandGreen)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  CLASE INACTIVO (bloqueada)
// ─────────────────────────────────────────

class _ClaseInactivo extends StatelessWidget {
  final String claseId;
  const _ClaseInactivo({required this.claseId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: GingaColors.borderLight,
              borderRadius: BorderRadius.circular(GingaRadius.sm),
            ),
            child: const Icon(Icons.lock_outline,
                color: GingaColors.textSecondary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Acceso pausado',
                    style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textSecondary)),
                Text('Renueva tu mensualidad para continuar',
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: GingaColors.textSecondary)),
              ],
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
  final String nombre;
  final String corda;
  const _Header({required this.nombre, required this.corda});

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';

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
  }
}

// ─────────────────────────────────────────
//  WORKSHOP BANNER (para activos)
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
                Text('Daniel Vereau\n13 al 28 Abril',
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
        if (actionLabel.isNotEmpty)
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