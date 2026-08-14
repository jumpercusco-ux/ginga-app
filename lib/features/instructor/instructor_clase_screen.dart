import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/eventos_service.dart';
import '../../core/services/tutoriales_service.dart';
import '../perfil/progreso_screen.dart';
import 'qr_generator_screen.dart';
import 'instructor_alumnos_screen.dart';
import 'instructor_pagos_screen.dart';
import '../biblioteca/cancionero_screen.dart';

// Paleta oscura fija — mismo tratamiento que login_screen/landing_screen:
// esta vista debe verse igual sin importar el modo de sistema del profesor.
const Color _kFondoOscuro = Colors.black;
const Color _kTarjetaOscura = Color(0xFF161616);
const Color _kBordeOscuro = Color(0x33FFFFFF);
const Color _kTextoSecundarioOscuro = Colors.white70;

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

Future<void> _deleteClase(BuildContext context, String claseId, String tipo) async {
  try {
    // 1. Eliminar de 'clases'
    await FirebaseFirestore.instance.collection('clases').doc(claseId).delete();

    // 2. Si no es regular, eliminar también de 'eventos'
    if (tipo != 'regular') {
      await FirebaseFirestore.instance.collection('eventos').doc(claseId).delete();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión eliminada con éxito 🗑️'),
          backgroundColor: GingaColors.brandGreen,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void _confirmDeleteClase(BuildContext context, String claseId, String name, String tipo) {
  showDialog(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        backgroundColor: _kTarjetaOscura,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          side: const BorderSide(color: _kBordeOscuro),
        ),
        title: Text(
          '¿Eliminar sesión? ⚠️',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "$name"? Se borrarán todos los registros asociados de forma permanente.',
          style: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _kTextoSecundarioOscuro),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteClase(context, claseId, tipo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.md)),
            ),
            child: Text(
              'Eliminar',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    },
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid == null
          ? const Stream.empty()
          : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final rol = data['rol'] ?? 'alumno';
          if (rol != 'profesor' && rol != 'administrador') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/home');
              }
            });
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: GingaColors.brandGreen),
              ),
            );
          }
        }

        return Scaffold(
          backgroundColor: _kFondoOscuro,
          body: IndexedStack(
            index: _selectedTab,
            children: const [
          _InstructorDashboard(),
          InstructorAlumnosScreen(),
          InstructorPagosScreen(),
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
        },
      );
  }
}

class _InstructorDashboard extends StatelessWidget {
  const _InstructorDashboard();

  Widget _buildEmptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: _kBordeOscuro),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.montserrat(
            color: _kTextoSecundarioOscuro,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar eventos y tutoriales mockup si la colección está vacía (solo permitido para rol profesor)
    EventosService.instance.inicializarEventosMockupSiVacia();
    EventosService.instance.inicializarEntreno30Mayo();
    TutorialesService.instance.inicializarTutorialesMockupSiVacia();

    final uid = FirebaseAuth.instance.currentUser?.uid;

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
                            color: Colors.white)),
                    Text('Gestión de clases',
                        style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: _kTextoSecundarioOscuro)),
                  ],
                ),
                Row(
                  children: [
                    if (uid != null && uid.isNotEmpty) ...[
                      _NotificationsBell(uid: uid),
                      const SizedBox(width: 8),
                    ],
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
              ],
            ),

            const SizedBox(height: 24),

            // ── Acceso rápido: Leads de WhatsApp ──────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('whatsapp_leads')
                  .where('status', isEqualTo: 'nuevo')
                  .snapshots(),
              builder: (context, leadsSnapshot) {
                final nuevos = leadsSnapshot.data?.docs.length ?? 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  onTap: () => context.push('/instructor-leads'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: _kTarjetaOscura,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      border: Border.all(color: _kBordeOscuro),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: GingaColors.brandGreen.withOpacity(0.15),
                          child: const Icon(Icons.chat_bubble_outline, color: GingaColors.brandGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Leads de WhatsApp',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                              Text('Conversaciones capturadas desde anuncios',
                                  style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro)),
                            ],
                          ),
                        ),
                        if (nuevos > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: GingaColors.accentAmber,
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                            ),
                            child: Text('$nuevos nuevo${nuevos == 1 ? '' : 's'}',
                                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
                          )
                        else
                          Icon(Icons.chevron_right, color: _kTextoSecundarioOscuro),
                      ],
                    ),
                  ),
                );
              },
            ),

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

                final now = DateTime.now();
                final allDocs = snapshot.hasData ? snapshot.data!.docs : [];
                
                final clasesRegulares = <QueryDocumentSnapshot>[];
                final eventosYRodas = <QueryDocumentSnapshot>[];

                for (var doc in allDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String tipo = data['tipo'] ?? 'regular';

                  bool isActive = true;
                  if (tipo != 'regular') {
                    final Timestamp? fechaFinTs = data['fecha_fin'] as Timestamp?;
                    if (fechaFinTs != null) {
                      isActive = fechaFinTs.toDate().isAfter(now);
                    }
                  }

                  if (isActive) {
                    if (tipo == 'regular') {
                      clasesRegulares.add(doc);
                    } else {
                      eventosYRodas.add(doc);
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clases Regulares de Hoy 🥋',
                        style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    if (clasesRegulares.isEmpty)
                      _buildEmptySection('No hay clases regulares registradas hoy')
                    else
                      ...clasesRegulares.map((doc) {
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
                            publicarInmediatamente: data['publicar_inmediatamente'] ?? true,
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    Text('Eventos y Rodas de Hoy 🌟',
                        style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    if (eventosYRodas.isEmpty)
                      _buildEmptySection('No hay eventos o rodas activos hoy')
                    else
                      ...eventosYRodas.map((doc) {
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
                            publicarInmediatamente: data['publicar_inmediatamente'] ?? true,
                          ),
                        );
                      }),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            Text('Gestión de Tienda 📦',
                style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kTarjetaOscura,
                borderRadius: BorderRadius.circular(GingaRadius.lg),
                border: Border.all(color: _kBordeOscuro),
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
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Administra precios, stock o agrega nuevos productos para que los alumnos los reserven.',
                            style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: _kTextoSecundarioOscuro,
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
                    color: Colors.white)),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kTarjetaOscura,
                borderRadius: BorderRadius.circular(GingaRadius.lg),
                border: Border.all(color: _kBordeOscuro),
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
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Crea, edita o elimina los tutoriales on-demand que los alumnos practican desde la biblioteca.',
                            style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: _kTextoSecundarioOscuro,
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
                color: _kTarjetaOscura,
                borderRadius: BorderRadius.circular(GingaRadius.lg),
                border: Border.all(color: _kBordeOscuro),
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
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Sincroniza las letras de cantigas de capoeira en tiempo real para activar el modo Karaoke de tus alumnos.',
                            style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: _kTextoSecundarioOscuro,
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
                    color: Colors.white)),

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

                final allDocs = snapshot.hasData ? snapshot.data!.docs : [];
                final clasesRegularesHistorial = <QueryDocumentSnapshot>[];
                final eventosYRodasHistorial = <QueryDocumentSnapshot>[];

                for (var doc in allDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String tipo = data['tipo'] ?? 'regular';
                  if (tipo == 'regular') {
                    clasesRegularesHistorial.add(doc);
                  } else {
                    eventosYRodasHistorial.add(doc);
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Historial de Clases Regulares 🥋',
                        style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kTextoSecundarioOscuro)),
                    const SizedBox(height: 8),
                    if (clasesRegularesHistorial.isEmpty)
                      _buildEmptySection('No hay clases regulares registradas aún')
                    else
                      ...clasesRegularesHistorial.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _ClaseHistorialGroupCard(
                          claseId: doc.id,
                          nivel: data['nivel'] ?? 'Clase',
                          hora: data['hora'] ?? '',
                          badge: data['badge'] ?? '',
                          dias: data['dias'] ?? '',
                          tipo: data['tipo'] ?? 'regular',
                          fechaFin: data['fecha_fin'] as Timestamp?,
                        );
                      }),
                    const SizedBox(height: 20),
                    Text('Historial de Eventos y Rodas 🌟',
                        style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kTextoSecundarioOscuro)),
                    const SizedBox(height: 8),
                    if (eventosYRodasHistorial.isEmpty)
                      _buildEmptySection('No hay eventos o rodas registrados aún')
                    else
                      ...eventosYRodasHistorial.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _ClaseHistorialGroupCard(
                          claseId: doc.id,
                          nivel: data['nivel'] ?? 'Clase',
                          hora: data['hora'] ?? '',
                          badge: data['badge'] ?? '',
                          dias: data['dias'] ?? '',
                          tipo: data['tipo'] ?? 'regular',
                          fechaFin: data['fecha_fin'] as Timestamp?,
                        );
                      }),
                  ],
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
      backgroundColor: _kTarjetaOscura,
      selectedItemColor: GingaColors.brandGreen,
      unselectedItemColor: _kTextoSecundarioOscuro,
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
          icon: Icon(Icons.monetization_on_outlined),
          activeIcon: Icon(Icons.monetization_on),
          label: 'Finanzas',
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

class LevelColorPalette {
  final Color badgeBg;
  final Color badgeText;
  final Color accent;
  final IconData icon;
  final String label;

  const LevelColorPalette({
    required this.badgeBg,
    required this.badgeText,
    required this.accent,
    required this.icon,
    required this.label,
  });

  static LevelColorPalette getPalette(String nivel, String badge, bool isEventOrRoda, String tipo) {
    if (isEventOrRoda) {
      return LevelColorPalette(
        badgeBg: const Color(0xFFFFF8E1),
        badgeText: const Color(0xFFE65100),
        accent: GingaColors.accentAmber,
        icon: tipo == 'roda' ? Icons.local_fire_department_rounded : Icons.star_rounded,
        label: tipo == 'roda' ? 'RODA 🔥' : 'EVENTO 🌟',
      );
    }
    
    final textToCheck = '${nivel.toLowerCase()} ${badge.toLowerCase()}';
    if (textToCheck.contains('kids') || textToCheck.contains('niño') || textToCheck.contains('infantil')) {
      return const LevelColorPalette(
        badgeBg: Color(0xFFE0F7FA), // Cyan suave
        badgeText: Color(0xFF006064), // Cyan oscuro
        accent: Color(0xFF00ACC1), // Cyan vibrante
        icon: Icons.child_care_rounded,
        label: 'KIDS 👶',
      );
    } else if (textToCheck.contains('adulto') || textToCheck.contains('iniciante') || textToCheck.contains('avanzado') || textToCheck.contains('básico') || textToCheck.contains('medio') || textToCheck.contains('principiante')) {
      return const LevelColorPalette(
        badgeBg: Color(0xFFE8EAF6), // Indigo suave
        badgeText: Color(0xFF1A237E), // Indigo oscuro
        accent: Color(0xFF3F51B5), // Indigo vibrante
        icon: Icons.fitness_center_rounded,
        label: 'ADULTOS 🏋️',
      );
    } else if (textToCheck.contains('todo') || textToCheck.contains('mixto') || textToCheck.contains('general')) {
      return const LevelColorPalette(
        badgeBg: Color(0xFFF3E5F5), // Púrpura suave
        badgeText: Color(0xFF4A148C), // Púrpura oscuro
        accent: Color(0xFF9C27B0), // Púrpura vibrante
        icon: Icons.groups_rounded,
        label: 'MIXTO 👥',
      );
    } else {
      return const LevelColorPalette(
        badgeBg: Color(0xFFE8F5E9), // Verde suave
        badgeText: Color(0xFF2E7D32), // Verde oscuro
        accent: GingaColors.brandGreen, // Verde vibrante
        icon: Icons.sports_martial_arts_rounded,
        label: 'CLASE 🥋',
      );
    }
  }
}

class _ClaseInstructorCard extends StatelessWidget {
  final String claseId;
  final String hora;
  final String nivel;
  final String badge;
  final String dias;
  final int cuposDisponibles;
  final int cuposMax;
  final String tipo;
  final bool publicarInmediatamente;

  const _ClaseInstructorCard({
    required this.claseId,
    required this.hora,
    required this.nivel,
    required this.badge,
    required this.dias,
    required this.cuposDisponibles,
    required this.cuposMax,
    required this.tipo,
    required this.publicarInmediatamente,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEventOrRoda = tipo != 'regular';
    final palette = LevelColorPalette.getPalette(nivel, badge, isEventOrRoda, tipo);

    final Color leftBorderColor = tipo == 'roda'
        ? const Color(0xFFE65100) // Naranja intenso
        : (tipo == 'evento'
            ? GingaColors.accentAmber // Amarillo dorado
            : palette.accent); // Color del nivel

    final badgeColor = tipo == 'roda'
        ? const Color(0xFFE65100)
        : (tipo == 'evento'
            ? GingaColors.accentAmber
            : palette.accent);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: leftBorderColor,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
      ),
      child: Container(
        margin: const EdgeInsets.only(left: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEventOrRoda ? const Color(0xFF1C1A12) : _kTarjetaOscura,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(GingaRadius.lg),
            bottomRight: Radius.circular(GingaRadius.lg),
          ),
          border: Border.all(color: _kBordeOscuro),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/clase-detalle?claseId=$claseId'),
              child: Row(
                children: [
                  Container(
                    width: hora.contains('-') || hora.length > 5 ? 82 : 62,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: leftBorderColor,
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
                                    color: Colors.white),
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
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: publicarInmediatamente
                                    ? GingaColors.brandGreen.withValues(alpha: 0.12)
                                    : _kTextoSecundarioOscuro.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                publicarInmediatamente ? 'VISIBLE' : 'BORRADOR',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: publicarInmediatamente
                                      ? GingaColors.brandGreen
                                      : _kTextoSecundarioOscuro,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (dias.isNotEmpty)
                          Text(dias,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: _kTextoSecundarioOscuro)),
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
                          style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: _kTextoSecundarioOscuro)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _navigateToQrGenerator(context, claseId, nivel, hora),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: leftBorderColor,
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
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: Colors.blue, size: 20),
                    onPressed: () => context.push('/clase-detalle?claseId=$claseId'),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: leftBorderColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, color: leftBorderColor, size: 20),
                    onPressed: () => context.push('/crear-clase?claseId=$claseId'),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _confirmDeleteClase(context, claseId, nivel, tipo),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: _kBordeOscuro),
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
                        color: Colors.white)),
                Text('$hora — $dias',
                    style: GoogleFonts.montserrat(
                        fontSize: 12, color: _kTextoSecundarioOscuro)),
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
  final Timestamp? fechaFin;

  const _ClaseHistorialGroupCard({
    required this.claseId,
    required this.nivel,
    required this.hora,
    required this.badge,
    required this.dias,
    required this.tipo,
    required this.fechaFin,
  });

  @override
  State<_ClaseHistorialGroupCard> createState() => _ClaseHistorialGroupCardState();
}

class _ClaseHistorialGroupCardState extends State<_ClaseHistorialGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isArchived = widget.tipo != 'regular' &&
        widget.fechaFin != null &&
        widget.fechaFin!.toDate().isBefore(DateTime.now());

    final badgeColor = isArchived
        ? Colors.grey.shade400
        : (widget.tipo == 'roda'
            ? const Color(0xFFE65100)
            : (widget.tipo == 'evento'
                ? GingaColors.accentAmber
                : GingaColors.brandGreen));

    final leadingColor = isArchived ? Colors.grey.shade400 : badgeColor;
    final badgeText = isArchived ? 'Archivado 📁' : widget.badge;
    final bool isEventOrRoda = widget.tipo != 'regular';

    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: leadingColor,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
      ),
      child: Container(
        margin: const EdgeInsets.only(left: 5),
        decoration: BoxDecoration(
          color: isEventOrRoda ? const Color(0xFF1C1A12) : _kTarjetaOscura,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(GingaRadius.lg),
            bottomRight: Radius.circular(GingaRadius.lg),
          ),
          border: Border.all(color: _kBordeOscuro),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            onExpansionChanged: (val) {
              setState(() => _expanded = val);
            },
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: leadingColor.withValues(alpha: 0.1),
              child: Icon(
                Icons.class_outlined,
                color: leadingColor,
                size: 18,
              ),
            ),
            title: Text(
              widget.nivel,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              '${widget.hora} — ${widget.dias}',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: _kTextoSecundarioOscuro,
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
                    badgeText,
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
                  color: _kTextoSecundarioOscuro,
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action buttons row for history card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.visibility_outlined, color: Colors.blue, size: 16),
                          label: Text(
                            'Ver detalle',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => context.push('/clase-detalle?claseId=${widget.claseId}'),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: Icon(Icons.edit, color: leadingColor, size: 16),
                          label: Text(
                            'Editar sesión',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: leadingColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => context.push('/crear-clase?claseId=${widget.claseId}'),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                          label: Text(
                            'Eliminar',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _confirmDeleteClase(context, widget.claseId, widget.nivel, widget.tipo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
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
                              style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: _kTextoSecundarioOscuro,
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
                              color: _kBordeOscuro,
                              margin: const EdgeInsets.only(bottom: 12),
                            ),
                            Text(
                              'Sesiones registradas:',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kTextoSecundarioOscuro,
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
                  ],
                ),
              ),
            ],
          ),
        ),
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
      backgroundColor: _kTarjetaOscura,
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
                        color: _kBordeOscuro,
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$nivel — $fecha ($hora)',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: _kTextoSecundarioOscuro,
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
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: _kTextoSecundarioOscuro,
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
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: _kBordeOscuro),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(
          activa ? Icons.qr_code_scanner : Icons.calendar_today_outlined,
          color: activa ? GingaColors.brandGreen : _kTextoSecundarioOscuro,
          size: 16,
        ),
        title: Text(
          fecha,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          hora,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            color: _kTextoSecundarioOscuro,
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
                    : _kTextoSecundarioOscuro.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                activa ? 'ACTIVA' : 'CERRADA',
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: activa ? GingaColors.brandGreen : _kTextoSecundarioOscuro,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: _kTextoSecundarioOscuro,
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
        color: _kTarjetaOscura,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: _kBordeOscuro),
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: _kTextoSecundarioOscuro,
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

class _NotificationsBell extends StatelessWidget {
  final String uid;
  const _NotificationsBell({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notificaciones')
          .where('leido', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, size: 26, color: Colors.white),
              onPressed: () => _mostrarBuzonNotificaciones(context, uid),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

void _mostrarBuzonNotificaciones(BuildContext context, String uid) {
  showModalBottomSheet(
    context: context,
    backgroundColor: _kTarjetaOscura,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.lg)),
    ),
    builder: (BuildContext sheetContext) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          MediaQuery.of(sheetContext).padding.bottom > 0
              ? MediaQuery.of(sheetContext).padding.bottom + 12
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications, color: GingaColors.brandGreen, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Notificaciones',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () async {
                    final unreadDocs = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('notificaciones')
                        .where('leido', isEqualTo: false)
                        .get();
                    
                    final batch = FirebaseFirestore.instance.batch();
                    for (var doc in unreadDocs.docs) {
                      batch.update(doc.reference, {'leido': true});
                    }
                    await batch.commit();
                  },
                  child: Text(
                    'Marcar leídas',
                    style: GoogleFonts.montserrat(
                      color: GingaColors.brandGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('notificaciones')
                    .orderBy('fecha', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 60, color: _kTextoSecundarioOscuro.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No tienes notificaciones aún',
                            style: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  final notifs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['leido'] != true;
                  }).toList();

                  if (notifs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 60, color: _kTextoSecundarioOscuro.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No tienes notificaciones aún',
                            style: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: notifs.length,
                    itemBuilder: (itemContext, index) {
                      final notifDoc = notifs[index];
                      final data = notifDoc.data() as Map<String, dynamic>;
                      final String titulo = data['titulo'] ?? 'Alerta';
                      final String mensaje = data['mensaje'] ?? '';
                      final String tipo = data['tipo'] ?? 'sistema';
                      final bool leido = data['leido'] ?? false;

                      IconData itemIcon = Icons.notifications_none;
                      Color itemColor = GingaColors.brandGreen;

                      if (tipo == 'asistencia') {
                        itemIcon = Icons.check_circle_outline;
                        itemColor = GingaColors.brandGreen;
                      } else if (tipo == 'membresia') {
                        itemIcon = Icons.lock_clock;
                        itemColor = GingaColors.accentAmber;
                      } else if (tipo == 'bienvenida') {
                        itemIcon = Icons.star_border;
                        itemColor = Colors.blue;
                      } else if (tipo == 'tienda') {
                        itemIcon = Icons.shopping_bag_outlined;
                        itemColor = Colors.purple;
                      } else if (tipo == 'evento' || tipo == 'clase' || tipo == 'clase_detalle') {
                        itemIcon = Icons.calendar_today_outlined;
                        itemColor = GingaColors.brandGreen;
                      }

                      return GestureDetector(
                        onTap: () async {
                          // 1. Marcar como leída de forma asíncrona al tocarla si no estaba leída
                          if (!leido) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('notificaciones')
                                  .doc(notifDoc.id)
                                  .update({'leido': true});
                            } catch (e) {
                              debugPrint("Error al marcar notificación como leída: $e");
                            }
                          }
                          // 2. Cerrar el buzón de notificaciones usando el context del bottom sheet
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          // 3. Ejecutar la redirección dinámica idéntica a la de la Push!
                          NotificationService.instance.handleRawNotificationRouting(data);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: leido ? Colors.transparent : itemColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(
                              color: leido ? _kBordeOscuro : itemColor.withOpacity(0.3),
                              width: leido ? 1 : 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: itemColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(itemIcon, color: itemColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          titulo,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (!leido)
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      mensaje,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: _kTextoSecundarioOscuro,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}