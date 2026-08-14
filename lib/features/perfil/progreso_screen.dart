import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/ginga_theme.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../core/models/cuerdas_fiu.dart';

// Paleta oscura fija — mismo tratamiento que el resto de la app: un solo
// tema, sin selector claro/oscuro/sistema.
const Color _kFondoOscuro = Colors.black;
const Color _kTarjetaOscura = Color(0xFF161616);
const Color _kBordeOscuro = Color(0x33FFFFFF);
const Color _kTextoSecundarioOscuro = Colors.white70;

int _obtenerAsistenciasObjetivo(String cordaUsuario) {
  final cordaObj = CuerdasFIU.encontrarCordaFIU(cordaUsuario);
  if (cordaObj != null) {
    return CuerdasFIU.obtenerClasesObjetivo(cordaObj.index);
  }
  return 100;
}




class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key});

  @override
  State<ProgresoScreen> createState() => _ProgresoScreenState();
}

class _ProgresoScreenState extends State<ProgresoScreen> {
  String? _cachedUid;
  Stream<DocumentSnapshot>? _userStream;
  Stream<QuerySnapshot>? _asistenciasStream;
  Stream<QuerySnapshot>? _pagosStream;
  Stream<QuerySnapshot>? _compensacionesStream;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Suscribir al tema para regenerar la pantalla al alternar claro/oscuro
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != _cachedUid) {
      _cachedUid = uid;
      if (uid == null) {
        _userStream = null;
        _asistenciasStream = null;
        _pagosStream = null;
        _compensacionesStream = null;
      } else {
        _userStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
        _asistenciasStream = FirebaseFirestore.instance
            .collection('asistencias')
            .where('user_id', isEqualTo: uid)
            .snapshots();
        _pagosStream = FirebaseFirestore.instance
            .collection('pagos')
            .where('user_id', isEqualTo: uid)
            .snapshots();
        _compensacionesStream = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('compensaciones')
            .snapshots();
      }
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream ?? const Stream.empty(),
      builder: (context, snapshot) {
        // Datos por defecto mientras carga
        String nombre = 'Alumno';
        String corda = 'Crua';
        String sede = 'Lima';
        String inicial = 'A';
        String? fotoUrl;
        String userStatus = 'nuevo';
        Timestamp? membresiaInicio;
        Timestamp? membresiaFin;
        bool notificationsEnabled = true;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          nombre = data['nombre'] ?? 'Alumno';
          corda = data['corda'] ?? 'Crua';
          sede = data['sede'] ?? 'Lima';
          inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';
          fotoUrl = data['foto_url'];
          userStatus = data['status'] ?? 'nuevo';
          membresiaInicio = data['membresia_inicio'] as Timestamp?;
          membresiaFin = data['membresia_fin'] as Timestamp?;
          notificationsEnabled = data['notifications_enabled'] != false;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _asistenciasStream ?? const Stream.empty(),
          builder: (context, asistenciasSnapshot) {
            int totalAsistencias = 0;
            if (asistenciasSnapshot.hasData) {
              totalAsistencias = asistenciasSnapshot.data!.docs.length;
            }

            final Set<String> asistenciasFechas = asistenciasSnapshot.hasData
                ? asistenciasSnapshot.data!.docs
                    .map((doc) => (doc.data() as Map<String, dynamic>)['fecha'] as String)
                    .toSet()
                : {};

            final int objetivo = _obtenerAsistenciasObjetivo(corda);
            final double porcentaje =
                (totalAsistencias / objetivo).clamp(0.0, 1.0);
            final int porcentajeInt = (porcentaje * 100).toInt();

            const textColor = Colors.white;
            const subtitleColor = _kTextoSecundarioOscuro;
            const cardBg = _kTarjetaOscura;
            const cardThemeBg = _kTarjetaOscura;
            const borderColor = _kBordeOscuro;

            final screenWidth = MediaQuery.of(context).size.width;
            final isDesktop = screenWidth > 850;

            if (isDesktop) {
              return DefaultTabController(
                length: 3,
                child: Scaffold(
                  backgroundColor: _kFondoOscuro,
                  body: SafeArea(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna Izquierda (Sidebar)
                        Container(
                          width: 320,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: _kBordeOscuro,
                              ),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.arrow_back, color: textColor),
                                      onPressed: () {
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        } else {
                                          context.go('/home');
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Perfil',
                                        style: GoogleFonts.montserrat(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: textColor),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await FirebaseAuth.instance.signOut();
                                        if (context.mounted) context.go('/splash');
                                      },
                                      icon: Icon(Icons.logout,
                                          color: subtitleColor, size: 22),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardThemeBg,
                                    borderRadius: BorderRadius.circular(GingaRadius.lg),
                                    border: Border.all(
                                        color: GingaColors.brandGreen.withOpacity(0.15)),
                                  ),
                                  child: Stack(
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: GingaColors.brandGreen,
                                            backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                                                ? NetworkImage(fotoUrl)
                                                : null,
                                            child: fotoUrl != null && fotoUrl.isNotEmpty
                                                ? null
                                                : Text(
                                                    inicial,
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nombre,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: textColor,
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
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 12,
                                                        color: GingaColors.brandGreen,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on_outlined,
                                                        size: 12,
                                                        color: subtitleColor),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      sede,
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 11,
                                                        color: subtitleColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        top: -6,
                                        right: -6,
                                        child: IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.edit_note_rounded,
                                            color: GingaColors.brandGreen,
                                            size: 24,
                                          ),
                                          onPressed: () => context.push('/editar-perfil'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _SectionHeader(title: 'Ajustes de la App', actionLabel: ''),
                                const SizedBox(height: 12),
                                _NotificationToggleCard(
                                  uid: uid,
                                  notificationsEnabled: notificationsEnabled,
                                ),
                                const SizedBox(height: 32),
                                Center(
                                  child: Text(
                                    'Versión 1.0.131 (v131)',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Columna Derecha (Contenido de Pestañas: Progreso, Logros, Membresía)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Container(
                                  height: 38,
                                  constraints: const BoxConstraints(maxWidth: 500),
                                  decoration: BoxDecoration(
                                    color: _kTarjetaOscura.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: TabBar(
                                    dividerColor: Colors.transparent,
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    indicator: BoxDecoration(
                                      color: GingaColors.brandGreen,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    labelColor: Colors.white,
                                    unselectedLabelColor: _kTextoSecundarioOscuro,
                                    labelStyle: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    unselectedLabelStyle: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    tabs: const [
                                      Tab(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Progreso'),
                                        ),
                                      ),
                                      Tab(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Logros'),
                                        ),
                                      ),
                                      Tab(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Membresía'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    // Pestaña 1: Progreso (Desktop)
                                    SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _ProgressCircle(
                                                inicial: inicial,
                                                porcentaje: porcentaje,
                                                porcentajeInt: porcentajeInt,
                                                fotoUrl: fotoUrl,
                                              ),
                                              const SizedBox(width: 32),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Progreso de Graduación',
                                                        style: GoogleFonts.montserrat(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w700,
                                                            color: textColor)),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 12, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: GingaColors.brandGreen.withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(GingaRadius.full),
                                                      ),
                                                      child: Text('Grado: $corda',
                                                          style: GoogleFonts.montserrat(
                                                              fontSize: 13,
                                                              color: GingaColors.brandGreen,
                                                              fontWeight: FontWeight.w600)),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    _XpBar(
                                                      total: totalAsistencias,
                                                      objetivo: objetivo,
                                                      porcentaje: porcentaje,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 36),
                                          _SectionHeader(
                                              title: 'Asistencia del Mes', actionLabel: ''),
                                          const SizedBox(height: 12),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 600),
                                            child: _AsistenciaMensual(asistenciasFechas: asistenciasFechas),
                                          ),
                                          const SizedBox(height: 24),
                                        ],
                                      ),
                                    ),

                                    // Pestaña 2: Logros (Desktop)
                                    SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _SectionHeader(title: 'Tus Logros', actionLabel: ''),
                                          const SizedBox(height: 16),
                                          _LogrosRow(totalAsistencias: totalAsistencias),
                                          const SizedBox(height: 24),
                                        ],
                                      ),
                                    ),

                                    // Pestaña 3: Membresía (Desktop)
                                    SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (uid != null) ...[
                                            _SectionHeader(
                                                title: 'Mi Membresía y Pagos', actionLabel: ''),
                                            const SizedBox(height: 12),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 700),
                                              child: _MembresiaYPagosSection(
                                                uid: uid,
                                                userStatus: userStatus,
                                                membresiaInicio: membresiaInicio,
                                                membresiaFin: membresiaFin,
                                                pagosStream: _pagosStream,
                                                compensacionesStream: _compensacionesStream,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 24),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Vista Móvil / Tablet Vertical (ancho <= 850)
            return DefaultTabController(
              length: 4,
              child: Scaffold(
                backgroundColor: _kFondoOscuro,
                body: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // ── Header ──────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.arrow_back, color: textColor),
                                  onPressed: () {
                                    if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    } else {
                                      context.go('/home');
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Progreso y Logros',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: textColor),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                    if (context.mounted) context.go('/splash');
                                  },
                                  icon: Icon(Icons.logout,
                                      color: subtitleColor, size: 22),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Tarjeta de perfil
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardThemeBg,
                                borderRadius: BorderRadius.circular(GingaRadius.lg),
                                border: Border.all(
                                    color: GingaColors.brandGreen.withOpacity(0.15)),
                              ),
                              child: Stack(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 32,
                                        backgroundColor: GingaColors.brandGreen,
                                        backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                                            ? NetworkImage(fotoUrl)
                                            : null,
                                        child: fotoUrl != null && fotoUrl.isNotEmpty
                                            ? null
                                            : Text(
                                                inicial,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nombre,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
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
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 13,
                                                    color: GingaColors.brandGreen,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on_outlined,
                                                    size: 13,
                                                    color: subtitleColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  sede,
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 12,
                                                    color: subtitleColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        color: GingaColors.brandGreen,
                                        size: 26,
                                      ),
                                      onPressed: () => context.push('/editar-perfil'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── TabBar (Pill/Chips Style) ───────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: _kTarjetaOscura.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: TabBar(
                                dividerColor: Colors.transparent,
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicator: BoxDecoration(
                                  color: GingaColors.brandGreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                labelColor: Colors.white,
                                unselectedLabelColor: _kTextoSecundarioOscuro,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                labelStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                                unselectedLabelStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                tabs: const [
                                  Tab(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Progreso'),
                                    ),
                                  ),
                                  Tab(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Logros'),
                                    ),
                                  ),
                                  Tab(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Membresía'),
                                    ),
                                  ),
                                  Tab(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Ajustes'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── TabBarView ──────────────────────
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Pestaña 1: Progreso
                                SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      Center(
                                        child: _ProgressCircle(
                                          inicial: inicial,
                                          porcentaje: porcentaje,
                                          porcentajeInt: porcentajeInt,
                                          fotoUrl: fotoUrl,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Center(
                                        child: Column(
                                          children: [
                                            Text('Progreso de Graduación',
                                                style: GoogleFonts.montserrat(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: textColor)),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: GingaColors.brandGreen.withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(GingaRadius.full),
                                              ),
                                              child: Text('Grado: $corda',
                                                  style: GoogleFonts.montserrat(
                                                      fontSize: 13,
                                                      color: GingaColors.brandGreen,
                                                      fontWeight: FontWeight.w600)),
                                            ),
                                            const SizedBox(height: 12),
                                            _XpBar(
                                              total: totalAsistencias,
                                              objetivo: objetivo,
                                              porcentaje: porcentaje,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      _SectionHeader(
                                          title: 'Asistencia del Mes', actionLabel: ''),
                                      const SizedBox(height: 12),
                                      _AsistenciaMensual(asistenciasFechas: asistenciasFechas),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),

                                // Pestaña 2: Logros
                                SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      _SectionHeader(title: 'Tus Logros', actionLabel: ''),
                                      const SizedBox(height: 16),
                                      _LogrosRow(totalAsistencias: totalAsistencias),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),

                                // Pestaña 3: Membresía
                                SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      if (uid != null) ...[
                                        _SectionHeader(
                                            title: 'Mi Membresía y Pagos', actionLabel: ''),
                                        const SizedBox(height: 12),
                                        _MembresiaYPagosSection(
                                          uid: uid,
                                          userStatus: userStatus,
                                          membresiaInicio: membresiaInicio,
                                          membresiaFin: membresiaFin,
                                          pagosStream: _pagosStream,
                                          compensacionesStream: _compensacionesStream,
                                        ),
                                      ],
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),

                                // Pestaña 4: Ajustes
                                SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      _SectionHeader(
                                          title: 'Configuración de App', actionLabel: ''),
                                      const SizedBox(height: 12),
                                      _NotificationToggleCard(
                                        uid: uid,
                                        notificationsEnabled: notificationsEnabled,
                                      ),
                                      const SizedBox(height: 32),
                                      Center(
                                        child: Text(
                                          'Versión 1.0.131 (v131)',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: subtitleColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ],
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
    );
  }
}

class _NotificationToggleCard extends StatelessWidget {
  final String? uid;
  final bool notificationsEnabled;
  const _NotificationToggleCard({
    required this.uid,
    required this.notificationsEnabled,
  });

  @override
  Widget build(BuildContext context) {
    if (uid == null) return const SizedBox();

    const cardBg = _kTarjetaOscura;
    const borderColor = _kBordeOscuro;
    const textColor = Colors.white;
    const subtitleColor = _kTextoSecundarioOscuro;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GingaColors.brandGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: GingaColors.brandGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notificaciones Push',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  'Recibir alertas de clases, pagos y novedades',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: notificationsEnabled,
            activeColor: GingaColors.brandGreen,
            activeTrackColor: GingaColors.brandGreen.withOpacity(0.3),
            onChanged: (val) async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'notifications_enabled': val});
              } catch (e) {
                debugPrint('Error actualizando notificaciones: $e');
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CÍRCULO DE PROGRESO
// ─────────────────────────────────────────

class _ProgressCircle extends StatelessWidget {
  final String inicial;
  final double porcentaje;
  final int porcentajeInt;
  final String? fotoUrl;

  const _ProgressCircle({
    required this.inicial,
    required this.porcentaje,
    required this.porcentajeInt,
    required this.fotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    const progressCircleBg = _kTarjetaOscura;
    const avatarBg = _kTarjetaOscura;
    const textColor = Colors.white;

    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _CirclePainter(progress: porcentaje, backgroundColor: progressCircleBg),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: avatarBg,
                backgroundImage: fotoUrl != null && fotoUrl!.isNotEmpty
                    ? NetworkImage(fotoUrl!)
                    : null,
                child: fotoUrl != null && fotoUrl!.isNotEmpty
                    ? null
                    : Text(inicial,
                        style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.brandGreen)),
              ),
              const SizedBox(height: 4),
              Text('$porcentajeInt%',
                  style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  const _CirclePainter({required this.progress, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = GingaColors.brandGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CirclePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.backgroundColor != backgroundColor;
}

class _XpBar extends StatelessWidget {
  final int total;
  final int objetivo;
  final double porcentaje;

  const _XpBar({
    required this.total,
    required this.objetivo,
    required this.porcentaje,
  });

  @override
  Widget build(BuildContext context) {
    const subtitleColor = _kTextoSecundarioOscuro;
    const barBg = _kTarjetaOscura;

    return SizedBox(
      width: 260,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$total / $objetivo clases',
                  style: GoogleFonts.montserrat(
                      fontSize: 12, color: subtitleColor)),
              Text('para el siguiente corda',
                  style: GoogleFonts.montserrat(
                      fontSize: 11, color: subtitleColor)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(GingaRadius.full),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 8,
              backgroundColor: barBg,
              valueColor: const AlwaysStoppedAnimation(GingaColors.brandGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogrosRow extends StatelessWidget {
  final int totalAsistencias;

  const _LogrosRow({required this.totalAsistencias});

  @override
  Widget build(BuildContext context) {
    final logros = [
      _LogroData(
        icon: Icons.check_circle_outline,
        label: 'Primer Paso',
        desc: totalAsistencias >= 1 ? '1 clase' : 'Toma 1 clase',
        color: GingaColors.brandGreen,
        unlocked: totalAsistencias >= 1,
      ),
      _LogroData(
        icon: Icons.local_fire_department,
        label: 'Constancia',
        desc: totalAsistencias >= 5
            ? '5 clases'
            : '$totalAsistencias de 5',
        color: GingaColors.accentAmber,
        unlocked: totalAsistencias >= 5,
      ),
      _LogroData(
        icon: Icons.emoji_events_outlined,
        label: 'Camino Medio',
        desc: totalAsistencias >= 12
            ? '12 clases'
            : '$totalAsistencias de 12',
        color: Colors.blueAccent,
        unlocked: totalAsistencias >= 12,
      ),
      _LogroData(
        icon: Icons.music_note_outlined,
        label: 'Ritmo y Cadencia',
        desc: totalAsistencias >= 25
            ? '25 clases'
            : '$totalAsistencias de 25',
        color: Colors.purpleAccent,
        unlocked: totalAsistencias >= 25,
      ),
      _LogroData(
        icon: Icons.shield_outlined,
        label: 'Guerrero Ginga',
        desc: totalAsistencias >= 50
            ? '50 clases'
            : '$totalAsistencias de 50',
        color: Colors.redAccent,
        unlocked: totalAsistencias >= 50,
      ),
      _LogroData(
        icon: Icons.workspace_premium_outlined,
        label: 'Mestre Arena',
        desc: totalAsistencias >= 100
            ? '100 clases'
            : '$totalAsistencias de 100',
        color: const Color(0xFFFFD700),
        unlocked: totalAsistencias >= 100,
      ),
    ];
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    double childAspectRatio = 0.82;

    if (screenWidth > 950) {
      crossAxisCount = 6;
      childAspectRatio = 0.95;
    } else if (screenWidth > 600) {
      crossAxisCount = 4;
      childAspectRatio = 0.9;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: logros.map((l) => _LogroBadge(logro: l)).toList(),
    );
  }
}

class _LogroBadge extends StatelessWidget {
  final _LogroData logro;
  const _LogroBadge({required this.logro});

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;
    const subtitleColor = _kTextoSecundarioOscuro;

    final Color badgeColor =
        logro.unlocked ? logro.color : Colors.grey.shade600;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(
              color: logro.unlocked
                  ? badgeColor.withOpacity(0.3)
                  : Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Icon(
            logro.unlocked ? logro.icon : Icons.lock_outline,
            color: badgeColor,
            size: 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(logro.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: logro.unlocked
                    ? textColor
                    : subtitleColor,
                height: 1.2)),
        const SizedBox(height: 2),
        Text(logro.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
                fontSize: 9, color: subtitleColor, height: 1.2)),
      ],
    );
  }
}





class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  const _SectionHeader({required this.title, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor)),
        if (actionLabel.isNotEmpty)
          Text(actionLabel,
              style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: GingaColors.brandGreen,
                  fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LogroData {
  final IconData icon;
  final String label;
  final String desc;
  final Color color;
  final bool unlocked;
  _LogroData({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
    required this.unlocked,
  });
}

class _AsistenciaMensual extends StatefulWidget {
  final Set<String> asistenciasFechas;
  const _AsistenciaMensual({required this.asistenciasFechas});

  @override
  State<_AsistenciaMensual> createState() => _AsistenciaMensualState();
}

class _AsistenciaMensualState extends State<_AsistenciaMensual> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    const cardBg = _kTarjetaOscura;
    const borderColor = _kBordeOscuro;
    const textColor = Colors.white;
    const subtitleColor = _kTextoSecundarioOscuro;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mes',
        },
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: textColor,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, color: GingaColors.brandGreen),
          rightChevronIcon: const Icon(Icons.chevron_right, color: GingaColors.brandGreen),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: subtitleColor),
          weekendStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: GingaColors.brandGreen),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: GoogleFonts.montserrat(fontSize: 13, color: textColor),
          weekendTextStyle: GoogleFonts.montserrat(fontSize: 13, color: textColor),
          outsideDaysVisible: false,
        ),
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final fechaStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final bool asistio = widget.asistenciasFechas.contains(fechaStr);
            if (asistio) {
              return Container(
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: GingaColors.brandGreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              );
            }
            return null;
          },
          todayBuilder: (context, day, focusedDay) {
            final fechaStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final bool asistio = widget.asistenciasFechas.contains(fechaStr);
            return Container(
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: asistio ? GingaColors.brandGreen : Colors.transparent,
                border: Border.all(color: GingaColors.brandGreen, width: 2),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: asistio ? Colors.white : GingaColors.brandGreen,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SECCIÓN DE MEMBRESÍA Y HISTORIAL DE PAGOS (ALUMNO)
// ─────────────────────────────────────────

class _MembresiaYPagosSection extends StatelessWidget {
  final String uid;
  final String userStatus;
  final Timestamp? membresiaInicio;
  final Timestamp? membresiaFin;
  final Stream<QuerySnapshot>? pagosStream;
  final Stream<QuerySnapshot>? compensacionesStream;

  const _MembresiaYPagosSection({
    required this.uid,
    required this.userStatus,
    required this.membresiaInicio,
    required this.membresiaFin,
    required this.pagosStream,
    required this.compensacionesStream,
  });

  String _formatFecha(DateTime? date) {
    if (date == null) return '-';
    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 
      'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${meses[date.month - 1]}, ${date.year}';
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const String message = 
        '🥋 *¡Hola Instructor! Deseo coordinar la renovación de mi membresía en Capoeira Ginga.*\n\n'
        '¿Me podría confirmar los datos o el monto de la cuota mensual para realizar el pago por Yape/Plin? ¡Muchas gracias! 👋';
    const String telefonoGinga = '51954642457';
    final String url = 'https://wa.me/$telefonoGinga?text=${Uri.encodeComponent(message)}';
    
    try {
      final Uri uri = Uri.parse(url);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('WhatsApp lanzado con éxito');
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp. Por favor, comunícate con tu instructor directamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int diasRestantes = 0;
    bool expirado = false;

    const cardBg = _kTarjetaOscura;
    const textColor = Colors.white;
    const subtitleColor = _kTextoSecundarioOscuro;

    if (membresiaFin != null) {
      final finDate = membresiaFin!.toDate();
      final ahora = DateTime.now();
      // Calcular la diferencia a la medianoche para evitar desajustes de horas
      final finDia = DateTime(finDate.year, finDate.month, finDate.day);
      final ahoraDia = DateTime(ahora.year, ahora.month, ahora.day);
      final diferencia = finDia.difference(ahoraDia).inDays;
      if (diferencia >= 0) {
        diasRestantes = diferencia;
      } else {
        expirado = true;
      }
    }

    final String statusLimpio = userStatus.toLowerCase();
    final bool esActivo = statusLimpio == 'activo' && !expirado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Tarjeta Premium de Estado de Membresía
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: esActivo
                ? const LinearGradient(
                    colors: [Color(0xFF1B5E20), GingaColors.brandGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : (statusLimpio == 'prueba' || statusLimpio == 'nuevo'
                    ? const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (esActivo 
                    ? GingaColors.brandGreen 
                    : (statusLimpio == 'prueba' || statusLimpio == 'nuevo' 
                        ? Colors.blue 
                        : Colors.red)).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    esActivo
                        ? 'Acceso Regular Activo 🥋'
                        : (statusLimpio == 'prueba' || statusLimpio == 'nuevo'
                            ? 'Periodo de Prueba ⚡'
                            : 'Membresía Vencida ⚠️'),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      esActivo
                          ? 'ACTIVO'
                          : (statusLimpio == 'prueba' || statusLimpio == 'nuevo'
                              ? 'LIBRE'
                              : 'VENCIDO'),
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (esActivo && membresiaFin != null) ...[
                Text(
                  'Vence el: ${_formatFecha(membresiaFin!.toDate())}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  diasRestantes == 0
                      ? '¡Tu membresía vence hoy!'
                      : '¡Te quedan $diasRestantes días activos de entrenamiento!',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ] else if (statusLimpio == 'prueba' || statusLimpio == 'nuevo') ...[
                Text(
                  '¡Bienvenido a Capoeira Ginga!',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Disfruta de tus clases de cortesía y coordina tu membresía regular con tu profesor.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _launchWhatsApp(context),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Text(
                      'Coordinar Membresía Regular',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  membresiaFin != null
                      ? 'Tu membresía expiró el: ${_formatFecha(membresiaFin!.toDate())}'
                      : 'Aún no tienes una membresía regular activa.',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coordinar renovación y pago de cuota para restablecer tu acceso.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _launchWhatsApp(context),
                    icon: const Icon(Icons.chat, size: 16),
                    label: Text(
                      'Coordinar Renovación por WhatsApp',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 2. Historial de Pagos Recientes
        Text(
          'Historial de Pagos Recientes',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: pagosStream ?? const Stream.empty(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Error al obtener historial de pagos: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: GingaColors.brandGreen),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBordeOscuro),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: subtitleColor),
                    const SizedBox(height: 8),
                    Text(
                      'Aún no hay transacciones validadas en tu historial.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Ordenar en memoria por fecha_pago de forma descendente para evitar requerir un índice compuesto en Firestore
            final pagos = snapshot.data!.docs.toList();
            pagos.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final Timestamp? aFecha = aData['fecha_pago'] as Timestamp?;
              final Timestamp? bFecha = bData['fecha_pago'] as Timestamp?;
              if (aFecha == null && bFecha == null) return 0;
              if (aFecha == null) return 1;
              if (bFecha == null) return -1;
              return bFecha.compareTo(aFecha); // Orden descendente
            });
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pagos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pago = pagos[index].data() as Map<String, dynamic>;
                final monto = pago['monto'] ?? 0.0;
                final metodo = pago['metodo_pago'] ?? 'Yape';
                final meses = pago['meses_pagados'] ?? 1;
                final Timestamp? fechaPago = pago['fecha_pago'] as Timestamp?;
                final fechaStr = _formatFecha(fechaPago?.toDate());

                // Icono y color según el método de pago
                IconData metodoIcon = Icons.payment;
                Color metodoColor = Colors.grey;
                switch (metodo.toString().toLowerCase()) {
                  case 'yape':
                    metodoIcon = Icons.phone_android;
                    metodoColor = const Color(0xFF7A1FA2);
                    break;
                  case 'plin':
                    metodoIcon = Icons.qr_code_2;
                    metodoColor = const Color(0xFF00B0FF);
                    break;
                  case 'efectivo':
                    metodoIcon = Icons.payments;
                    metodoColor = const Color(0xFF388E3C);
                    break;
                  case 'transferencia':
                    metodoIcon = Icons.account_balance;
                    metodoColor = const Color(0xFF1976D2);
                    break;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBordeOscuro),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: metodoColor.withOpacity(0.1),
                        child: Icon(metodoIcon, color: metodoColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'S/ ${monto.toStringAsFixed(2)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$meses ${meses == 1 ? "mes" : "meses"} de acceso • $metodo',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: subtitleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fechaStr,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 10, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'Validado',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),

        // 3. Historial de Compensaciones de Membresía
        StreamBuilder<QuerySnapshot>(
          stream: compensacionesStream ?? const Stream.empty(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Error al obtener compensaciones: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink(); // Ocultar si no hay registros
            }

            final compensaciones = snapshot.data!.docs.toList();
            compensaciones.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final Timestamp? aFecha = aData['fecha_compensacion'] as Timestamp?;
              final Timestamp? bFecha = bData['fecha_compensacion'] as Timestamp?;
              if (aFecha == null && bFecha == null) return 0;
              if (aFecha == null) return 1;
              if (bFecha == null) return -1;
              return bFecha.compareTo(aFecha); // Descendente
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compensaciones y Extensiones',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Días o sesiones reincorporadas a tu membresía sin cobros contables.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: compensaciones.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final comp = compensaciones[index].data() as Map<String, dynamic>;
                    final motivo = comp['motivo'] ?? 'Compensación';
                    final dias = comp['dias_compensados'] ?? comp['dias_añadidos'] ?? 0;
                    final detalle = comp['detalle'] ?? '';
                    final Timestamp? fechaReg = comp['fecha_compensacion'] as Timestamp?;
                    final regStr = _formatFecha(fechaReg?.toDate());

                    // Visualización según motivo
                    IconData icon = Icons.card_giftcard;
                    Color color = Colors.green;
                    String labelMotivo = motivo;
                    String qtyLabel = '+$dias ${dias == 1 ? "día" : "días"}';

                    final motivoLower = motivo.toString().toLowerCase();
                    if (motivoLower.contains('feriado')) {
                      icon = Icons.calendar_today_outlined;
                      color = const Color(0xFFFFB300); // Amber
                      labelMotivo = 'Feriado / Festivo 📅';
                    } else if (motivoLower.contains('inasistencia')) {
                      icon = Icons.thermostat;
                      color = const Color(0xFF1E88E5); // Blue
                      labelMotivo = 'Inasistencia Justificada 🤒';
                    } else if (motivoLower.contains('congelar')) {
                      icon = Icons.ac_unit_outlined;
                      color = const Color(0xFF00ACC1); // Cyan
                      labelMotivo = 'Membresía Congelada ❄️';
                    } else if (motivoLower.contains('suspension') || motivoLower.contains('suspensión')) {
                      icon = Icons.report_problem_outlined;
                      color = const Color(0xFFE53935); // Red/Orange
                      labelMotivo = 'Clase Suspendida ⚠️';
                    } else if (motivoLower.contains('otro')) {
                      icon = Icons.card_giftcard;
                      color = Colors.green;
                      labelMotivo = 'Compensación Especial 📝';
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBordeOscuro),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: color.withOpacity(0.1),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  labelMotivo,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                if (detalle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    detalle,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                qtyLabel,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                regStr,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
