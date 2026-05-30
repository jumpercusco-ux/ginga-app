








import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/notification_service.dart';
import '../eventos/eventos_screen.dart';
import '../perfil/progreso_screen.dart';
import '../biblioteca/biblioteca_screen.dart';
import 'package:go_router/go_router.dart';
import 'qr_scanner_screen.dart';
import '../../core/services/eventos_service.dart';
import '../biblioteca/tutoriales_screen.dart';
import '../biblioteca/musica_screen.dart';
import '../biblioteca/cultura_screen.dart';
import '../biblioteca/practicar_toque_screen.dart';
import '../biblioteca/tutor_detail_screen.dart';
import '../biblioteca/cancionero_screen.dart';

// Constantes de estado
class UserStatus {
  static const nuevo = 'nuevo';
  static const prueba = 'prueba';
  static const activo = 'activo';
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

  // Llaves de referencia para el Walkthrough
  final GlobalKey _profileAvatarKey = GlobalKey();
  final GlobalKey _classReserveKey = GlobalKey();
  final GlobalKey _bibliotecaTabKey = GlobalKey();

  // Estado del Walkthrough
  int _onboardingStep = 0; // 0 = inactivo/completado, 1 = Biblioteca, 2 = Reserva, 3 = Perfil
  bool _localDismissed = false;
  bool? _prevHasSeenWalkthrough;

  // Variables de caché para evitar recrear la suscripción del stream reactivo
  Stream<DocumentSnapshot>? _userStream;
  String? _cachedUid;

  @override
  void initState() {
    super.initState();
    // Resguardo: inicializar/refrescar notificaciones y token FCM al cargar el Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.init();
      NotificationService.instance.updateTokenInFirestore();
    });
  }

  void _nextStep() {
    setState(() {
      if (_onboardingStep < 3) {
        _onboardingStep++;
      } else {
        _dismissWalkthrough();
      }
    });
  }

  void _dismissWalkthrough() async {
    setState(() {
      _onboardingStep = 0;
      _localDismissed = true;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'hasSeenWalkthrough': true});
        debugPrint('GINGA_DEBUG: Bandera hasSeenWalkthrough guardada en Firestore para usuario $uid');
      } catch (e) {
        debugPrint('Error guardando walkthrough en Firestore: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != _cachedUid) {
      _cachedUid = uid;
      _userStream = uid == null
          ? null
          : FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream ?? const Stream.empty(),
      builder: (context, snapshot) {
        String status = UserStatus.nuevo;
        bool hasSeenWalkthrough = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          status = data['status'] ?? UserStatus.nuevo;
          hasSeenWalkthrough = data['hasSeenWalkthrough'] ?? false;

          // Si en Firestore se reinicia el tour (pasa de true a false), reactivamos localmente la bandera de descarte
          if (_prevHasSeenWalkthrough == true && !hasSeenWalkthrough) {
            _localDismissed = false;
          }
          _prevHasSeenWalkthrough = hasSeenWalkthrough;

          // Gatillar walkthrough si califica (nuevo, no lo ha visto, no descartado y está en pestaña Home)
          if (status == UserStatus.nuevo && !hasSeenWalkthrough && _onboardingStep == 0 && !_localDismissed && _selectedTab == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _onboardingStep = 1;
                });
              }
            });
          }

          // Chequeo de expiración de membresía a nivel de shell
          if (status == UserStatus.activo && data['membresia_fin'] != null) {
            final Timestamp finTimestamp = data['membresia_fin'];
            if (DateTime.now().isAfter(finTimestamp.toDate())) {
              status = UserStatus.inactivo;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'status': UserStatus.inactivo});
              });
            }
          }
        }

        // Obtener la llave activa para el walkthrough
        GlobalKey? activeKey;
        String title = '';
        String description = '';
        bool showHeartbeat = false;

        if (_onboardingStep == 1) {
          activeKey = _bibliotecaTabKey;
          title = 'Mira los Tutoriales 📺';
          description = 'Presiona aquí para acceder a la Biblioteca, donde podrás aprender tutoriales interactivos de capoeira, repasar letras de canciones en el karaoke y practicar toques.';
        } else if (_onboardingStep == 2) {
          activeKey = _classReserveKey;
          title = 'Reserva tus Entrenamientos 🥋';
          description = '¡Tu primera clase es totalmente GRATIS! Presiona sobre el banner de reserva o la clase de tu sede para agendar tu entrenamiento.';
          showHeartbeat = true;
        } else if (_onboardingStep == 3) {
          activeKey = _profileAvatarKey;
          title = 'Tu Control Personal y Pagos 👤';
          description = 'Presiona sobre tu avatar de perfil para consultar tu registro de asistencias por QR, tu rango de graduación tradicional (corda) y controlar el vencimiento de tus cuotas.';
        }

        return Stack(
          children: [
            Scaffold(
              backgroundColor: GingaColors.backgroundLight,
              body: IndexedStack(
                index: _selectedTab,
                children: [
                  _HomeDashboard(
                    profileAvatarKey: _profileAvatarKey,
                    classReserveKey: _classReserveKey,
                  ),
                  // EventosScreen(), // Ocultado temporalmente
                  const BibliotecaScreen(),
                  // ProgresoScreen(), // Ocultado de la barra inferior (se accede por el avatar)
                ],
              ),
              extendBody: true,
              floatingActionButton: Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      GingaColors.brandGreen,
                      Color(0xFF2E7D32),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: GingaColors.brandGreen.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: () => _handleQrScannerTap(context, status),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
              bottomNavigationBar: _GingaBottomNav(
                currentIndex: _selectedTab,
                onTap: (i) => setState(() => _selectedTab = i),
                bibliotecaTabKey: _bibliotecaTabKey,
              ),
            ),
            if (_onboardingStep > 0 && activeKey != null)
              WalkthroughOverlay(
                targetKey: activeKey,
                title: title,
                description: description,
                onNext: _nextStep,
                isLastStep: _onboardingStep == 3,
                showHeartbeat: showHeartbeat,
                onDismiss: _dismissWalkthrough,
              ),
          ],
        );
      },
    );
  }

  void _handleQrScannerTap(BuildContext context, String status) {
    if (status == UserStatus.activo || status == UserStatus.prueba) {
      _navigateToQrScanner(context);
    } else if (status == UserStatus.nuevo) {
      _showNuevoBottomSheet(context);
    } else if (status == UserStatus.inactivo) {
      _showInactivoBottomSheet(context);
    }
  }

  void _showNuevoBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildModernBottomSheet(
        context: ctx,
        title: '¡Reserva tu Clase de Prueba! 🥋',
        message:
            'Bienvenido a Ginga. Para poder registrar tus asistencias mediante QR, primero debes agendar tu clase de prueba gratuita y experimentar la energía de la capoeira.',
        buttonLabel: 'Ver Clases Disponibles',
        icon: Icons.celebration_rounded,
        iconColor: GingaColors.brandGreen,
        onAction: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El módulo de reservas de clases estará disponible próximamente. ¡Mantente atento!',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: GingaColors.brandGreen,
            ),
          );
        },
      ),
    );
  }

  void _showInactivoBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildModernBottomSheet(
        context: ctx,
        title: 'Membresía Expirada ⚠️',
        message:
            'Tu acceso a las clases ha expirado. Por favor, renueva tu membresía o adquiere un pase de clases en nuestra tienda oficial para continuar escaneando y asistiendo.',
        buttonLabel: 'Ir a la Tienda Ginga',
        icon: Icons.lock_clock_rounded,
        iconColor: GingaColors.accentAmber,
        onAction: () {
          Navigator.pop(ctx);
          context.push('/tienda');
        },
      ),
    );
  }

  Widget _buildModernBottomSheet({
    required BuildContext context,
    required String title,
    required String message,
    required String buttonLabel,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onAction,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: GingaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: GingaColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: GingaColors.brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              elevation: 0,
            ),
            child: Text(
              buttonLabel,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
            child: Text(
              'Quizás más tarde',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: GingaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────
//  DASHBOARD PRINCIPAL
// ─────────────────────────────────────────

class _HomeDashboard extends StatelessWidget {
  final GlobalKey profileAvatarKey;
  final GlobalKey classReserveKey;

  const _HomeDashboard({
    required this.profileAvatarKey,
    required this.classReserveKey,
  });

  @override
  Widget build(BuildContext context) {
    // Inicializar eventos mockup si la colección de Firestore está vacía
    EventosService.instance.inicializarEventosMockupSiVacia();
    // Sembrar entreno del Sábado 30 de Mayo si no existe
    EventosService.instance.inicializarEntreno30Mayo();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: GingaColors.brandGreen),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        String status = data['status'] ?? UserStatus.nuevo;
        final nombre = data['nombre'] ?? 'Alumno';
        final corda = data['corda'] ?? 'Crua';
        final claseId = data['clase_id'] ?? '';
        final sede = data['sede'] ?? '';
        debugPrint('GINGA_DEBUG: Usuario "$nombre" tiene Sede "$sede" | Status: "$status" | UID: "$uid"');
        final Timestamp? membresiaFin = data['membresia_fin'];

        // Chequeo de expiración de membresía
        if (status == UserStatus.activo && data['membresia_fin'] != null) {
          final Timestamp finTimestamp = data['membresia_fin'];
          if (DateTime.now().isAfter(finTimestamp.toDate())) {
            status = UserStatus.inactivo; // Para la UI inmediata
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({'status': UserStatus.inactivo});
            });
          }
        }

        // Auto-curación de sede incorrecta (si la sede es un nombre de clase o está vacía/inválida y tiene clase asignada)
        if (uid != null &&
            claseId.isNotEmpty &&
            (sede == 'Kids' ||
             sede == 'Adultos' ||
             sede == 'Todos los niveles' ||
             sede == '')) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final claseDoc = await FirebaseFirestore.instance
                  .collection('clases')
                  .doc(claseId)
                  .get();
              if (claseDoc.exists) {
                final claseData = claseDoc.data() ?? {};
                final claseSede = claseData['sede']; // ej: "Cusco", "Lima"
                if (claseSede != null &&
                    claseSede.toString().isNotEmpty &&
                    claseSede.toString() != sede) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'sede': claseSede.toString()});
                  debugPrint('GINGA_DEBUG: Auto-corregida la sede del usuario a "${claseSede.toString()}" basada en su clase.');
                }
              }
            } catch (e) {
              debugPrint('Error en auto-curación de sede: $e');
            }
          });
        }

        final bool isVirtual = (sede == 'Virtual / A Distancia');

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header siempre visible
                _Header(
                  nombre: nombre,
                  corda: corda,
                  uid: uid ?? '',
                  avatarKey: profileAvatarKey,
                ),
                const SizedBox(height: 20),

                // Banner según estado
                _StatusBanner(
                  status: status,
                  sede: sede,
                  membresiaFin: membresiaFin,
                  nombre: nombre,
                  reserveKey: isVirtual ? null : classReserveKey,
                ),
                const SizedBox(height: 20),

                // Contenido según estado
                _ContentByStatus(
                  status: status,
                  claseId: claseId,
                  uid: uid ?? '',
                  sede: sede,
                  reserveKey: isVirtual ? classReserveKey : null,
                ),
                const SizedBox(height: 20),

                // Promo de la Tienda
                const _StorePromoBanner(),
                const SizedBox(height: 20),

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
  final String sede;
  final Timestamp? membresiaFin;
  final String nombre;
  final Key? reserveKey;

  const _StatusBanner({
    required this.status,
    required this.sede,
    this.membresiaFin,
    required this.nombre,
    this.reserveKey,
  });

  @override
  Widget build(BuildContext context) {
    Widget bannerWidget;

    if (status == UserStatus.nuevo && sede == 'U. Continental') {
      bannerWidget = _Banner(
        color: GingaColors.accentAmber,
        icono: Icons.school_outlined,
        titulo: 'Registro en revisión 🎓',
        subtitulo:
            'Hola $nombre, tu cuenta de la U. Continental está pendiente de aprobación por el instructor Luis Enrique.',
        accion: 'Pendiente',
        onTap: () {},
      );
    } else if (status == UserStatus.activo && membresiaFin != null) {
      final ahora = DateTime.now();
      final fin = DateTime(membresiaFin!.toDate().year,
          membresiaFin!.toDate().month, membresiaFin!.toDate().day);
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      final diasRestantes = fin.difference(hoy).inDays;

      if (diasRestantes >= 0 && diasRestantes <= 5) {
        final String fechaFormateada =
            '${fin.day.toString().padLeft(2, '0')}/${fin.month.toString().padLeft(2, '0')}';
        final String mensajeDias = diasRestantes == 0
            ? 'vence HOY ⚠️'
            : diasRestantes == 1
                ? 'vence MAÑANA ⚠️'
                : 'vence en $diasRestantes días ⚠️';

        bannerWidget = _Banner(
          color: const Color(0xFFFF9800), // Ámbar / Naranja de advertencia
          icono: Icons.lock_clock,
          titulo: 'Alerta de membresía',
          subtitulo:
              'Tu membresía $mensajeDias ($fechaFormateada). Evita la suspensión de tu acceso coordinando tu pago con el profesor.',
          accion: 'Ver pago',
          onTap: () {},
        );
      } else {
        bannerWidget = _buildBannerFromStatus(context);
      }
    } else {
      bannerWidget = _buildBannerFromStatus(context);
    }

    return Container(
      key: reserveKey,
      child: bannerWidget,
    );
  }

  Widget _buildBannerFromStatus(BuildContext context) {
    switch (status) {
      case UserStatus.nuevo:
        if (sede == 'Virtual / A Distancia') {
          return _Banner(
            color: GingaColors.brandGreen,
            icono: Icons.sports_kabaddi_outlined,
            titulo: '¡Aprende Capoeira en Casa! 🏠🥋',
            subtitulo:
                '¡Bienvenido a tu entrenamiento! Explora tutoriales paso a paso de técnicas, movimientos, toques e historia.',
            accion: 'Ver tutoriales',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TutorialesScreen(),
                ),
              );
            },
          );
        }
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
        return _WorkshopBanner(userNombre: nombre);
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
                        fontSize: 12, color: Colors.white70, height: 1.4)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
  final String sede;
  final Key? reserveKey;

  const _ContentByStatus({
    required this.status,
    required this.claseId,
    required this.uid,
    required this.sede,
    this.reserveKey,
  });

  @override
  Widget build(BuildContext context) {
    if (sede == 'Virtual / A Distancia') {
      return _VirtualDashboard(uid: uid, reserveKey: reserveKey);
    }

    Widget content;

    switch (status) {
      // NUEVO — ve todas las clases para elegir la de prueba
      case UserStatus.nuevo:
        if (sede == 'U. Continental') {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: 'Tu clase asignada', actionLabel: ''),
              const SizedBox(height: 12),
              _ClasePendiente(claseId: claseId),
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: 'Clases disponibles', actionLabel: ''),
              const SizedBox(height: 12),
              _ClasesNuevo(uid: uid, sede: sede, soloRegulares: true),
            ],
          );
        }
        break;

      // PRUEBA — ve su reserva pendiente
      case UserStatus.prueba:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Tu reserva', actionLabel: ''),
            const SizedBox(height: 12),
            _ReservaPendiente(uid: uid),
          ],
        );
        break;

      // ACTIVO — ve su clase
      case UserStatus.activo:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Tu clase', actionLabel: ''),
            const SizedBox(height: 12),
            _ClaseActivo(claseId: claseId),
          ],
        );
        break;

      // INACTIVO — ve su clase bloqueada
      case UserStatus.inactivo:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Tu clase', actionLabel: ''),
            const SizedBox(height: 12),
            _ClaseInactivo(claseId: claseId),
          ],
        );
        break;

      default:
        content = const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        _EventosSede(uid: uid, sede: sede),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  VIRTUAL LEARNER DASHBOARD (DOCK & RODA)
// ─────────────────────────────────────────

void _mostrarSelectorSedeFisica(BuildContext context, String uid) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
    ),
    builder: (BuildContext ctx) {
      final List<Map<String, String>> sedesFisicas = [
        {
          'id': 'Cusco',
          'label': 'Sede Cusco ☀️',
          'desc':
              'Clases presenciales en Cusco (incluye Universidad Continental y Magisterio).'
        },
        {
          'id': 'Lima',
          'label': 'Sede Lima 🌊',
          'desc': 'Clases presenciales grupales en la capital.'
        },
        {
          'id': 'Chimbote',
          'label': 'Sede Chimbote ⚓',
          'desc': 'Entrenamientos presenciales en la sede del norte.'
        },
      ];

      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.8,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GingaColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Elige tu Sede Física 🏢',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: GingaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Selecciona la academia donde te gustaría asistir a entrenar de forma presencial:',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: GingaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: sedesFisicas.map((sedeMap) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({'sede': sedeMap['id']});

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    '¡Sede cambiada a ${sedeMap['id']}! Ahora puedes reservar tu clase regular 🥋'),
                                backgroundColor: GingaColors.brandGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Error al cambiar sede: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.storefront_outlined,
                                  color: GingaColors.brandGreen, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sedeMap['label']!,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: GingaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    sedeMap['desc']!,
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: GingaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: GingaColors.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _VirtualDashboard extends StatelessWidget {
  final String uid;
  final Key? reserveKey;
  const _VirtualDashboard({required this.uid, this.reserveKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BANNER DE CONVERSIÓN FÍSICA A SEDE LOCAL ───────────────────────
        Container(
          key: reserveKey,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE8F5E9), // verde menta muy claro
                Color(0xFFC8E6C9), // verde claro
              ],
            ),
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            border: Border.all(color: GingaColors.brandGreen.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_outlined,
                    color: GingaColors.brandGreen, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Entrenas en nuestras sedes? 🏢',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visita nuestras academias presenciales en Cusco, Lima o Chimbote y reserva tu primera clase GRATIS.',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: GingaColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _mostrarSelectorSedeFisica(context, uid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GingaColors.brandGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(
                  'Reservar',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── PRÁCTICA DEL DÍA (RODA & INSTRUMENTO) ───────────────────────
        _SectionTitle(title: 'Práctica del Día 🪘🎵', actionLabel: ''),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toque del Día
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PracticarToqueScreen()),
                  ),
                  child: Container(
                    height: 168,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      border: Border.all(color: GingaColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.music_note_outlined,
                              color: Colors.blue, size: 20),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Toque de Angola',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'El toque tradicional para el juego bajo y táctico.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            color: GingaColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Practicar',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.blue, size: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Canción del Día
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CancioneroScreen()),
                  ),
                  child: Container(
                    height: 168,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      border: Border.all(color: GingaColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GingaColors.brandGreen.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.menu_book_outlined,
                              color: GingaColors.brandGreen, size: 20),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Canta con el Karaoke',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aprende las cantigas de capoeira más populares y practica con sus letras.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            color: GingaColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ver Letras',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.brandGreen,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded,
                                color: GingaColors.brandGreen, size: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── RECOMENDADO PARA TI (TUTORIALES EN VIDEO) ───────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(title: 'Técnicas recomendadas 🥋', actionLabel: ''),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TutorialesScreen()),
              ),
              child: Text(
                'Ver todos',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: GingaColors.brandGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tutoriales')
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child:
                      CircularProgressIndicator(color: GingaColors.brandGreen),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: GingaColors.cardLight,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: GingaColors.borderLight),
                ),
                child: Center(
                  child: Text(
                    'Pronto subiremos nuevas lecciones virtuales 🥋',
                    style: GoogleFonts.nunito(color: GingaColors.textSecondary),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final titulo = data['titulo'] ?? '';
                final nivel = data['nivel'] ?? 'Iniciante';
                final duracion = data['duracion'] ?? '6 min';
                final categoria = data['categoria'] ?? 'Fundamentos';
                final descripcion = data['descripcion'] ?? '';
                final tipMestre = data['tipMestre'] ?? '';
                final tipError = data['tipError'] ?? '';
                final imagenUrl = data['imagen_url'] ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FeaturedLessonCard(
                    titulo: titulo,
                    nivel: nivel,
                    duracion: duracion,
                    categoria: categoria,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TutorialDetailScreen(
                          title: titulo,
                          category: categoria,
                          level: nivel,
                          description: descripcion,
                          tipMestre: tipMestre,
                          tipError: tipError,
                          imageUrl: imagenUrl,
                          videoUrl: data['video_url'] ?? '',
                          duracion: duracion,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FeaturedLessonCard extends StatelessWidget {
  final String titulo;
  final String nivel;
  final String duracion;
  final String categoria;
  final VoidCallback onTap;

  const _FeaturedLessonCard({
    required this.titulo,
    required this.nivel,
    required this.duracion,
    required this.categoria,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icono = categoria == 'Fundamentos'
        ? Icons.school_rounded
        : categoria == 'Floreos'
            ? Icons.accessibility_new
            : Icons.sports_martial_arts;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(color: GingaColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: GingaColors.brandGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(GingaRadius.md),
              ),
              child: Icon(icono, color: GingaColors.brandGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: GingaColors.cardLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          nivel,
                          style: GoogleFonts.montserrat(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.brandGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time_outlined,
                          size: 10, color: GingaColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        duracion,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: GingaColors.textSecondary,
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
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  EVENTOS Y RODAS DE LA SEDE (siempre visibles)
// ─────────────────────────────────────────

class _EventosSede extends StatelessWidget {
  final String uid;
  final String sede;

  const _EventosSede({required this.uid, required this.sede});

  @override
  Widget build(BuildContext context) {
    // Si la sede es 'U. Continental', lo mapeamos a 'Cusco' para ver los eventos regionales de Cusco
    final String querySede = (sede == 'U. Continental') ? 'Cusco' : sede;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .where('sede', isEqualTo: querySede)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;

        // Filtrar client-side para obtener solo tipo == 'especial' o 'roda'
        final eventos = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String tipo = data['tipo'] ?? 'regular';
          return tipo == 'especial' || tipo == 'roda';
        }).toList();

        if (eventos.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _SectionTitle(title: 'Eventos y Rodas Especiales', actionLabel: ''),
            const SizedBox(height: 12),
            Column(
              children: eventos.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                    lugar: data['lugar'] ?? '',
                    ubicacion: data['ubicacion'] ?? '',
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  CLASES PARA NUEVO (todas disponibles)
// ─────────────────────────────────────────

class _ClasesNuevo extends StatelessWidget {
  final String uid;
  final String sede;
  final bool soloRegulares;
  const _ClasesNuevo(
      {required this.uid, required this.sede, this.soloRegulares = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .where('sede', isEqualTo: sede)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: GingaColors.brandGreen, strokeWidth: 2),
          );
        }

        final docs = snapshot.data!.docs;
        final clases = soloRegulares
            ? docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['tipo'] ?? 'regular') == 'regular';
              }).toList()
            : docs;

        if (clases.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GingaRadius.lg),
              border: Border.all(color: GingaColors.borderLight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GingaColors.brandGreen.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color: GingaColors.brandGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pronto programaremos clases presenciales',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Actualmente no hay horarios disponibles para la sede de $sede. ¡Mantente atento o coordina con el instructor!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: GingaColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: clases.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                lugar: data['lugar'] ?? '',
                ubicacion: data['ubicacion'] ?? '',
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

String _interpretarDiasDeSemana(String diasRaw) {
  if (diasRaw.isEmpty) return '';
  final Map<String, String> mapaDias = {
    'L': 'Lunes',
    'M': 'Martes',
    'X': 'Miércoles',
    'J': 'Jueves',
    'V': 'Viernes',
    'S': 'Sábado',
    'D': 'Domingo',
  };
  return diasRaw.split(',').map((p) {
    final trimmed = p.trim();
    return mapaDias[trimmed] ?? trimmed;
  }).join(', ');
}

class _ClaseCardNuevo extends StatelessWidget {
  final String claseId;
  final String hora;
  final String nivel;
  final String badge;
  final String dias;
  final String instructor;
  final int cuposDisponibles;
  final String tipo;
  final String uid;
  final String lugar;
  final String ubicacion;

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
    required this.lugar,
    required this.ubicacion,
  });

  @override
  Widget build(BuildContext context) {
    // Determinar esquema de colores basado en el tipo de clase
    final bool isEvent = tipo == 'especial' || tipo == 'roda';
    final Color accentColor =
        isEvent ? GingaColors.accentAmber : GingaColors.brandGreen;

    // Colores suaves para las insignias
    final Color badgeBgColor = isEvent
        ? const Color(0xFFFFF8E1) // Ámbar muy suave
        : const Color(0xFFE8F5E9); // Verde muy suave

    final Color badgeTextColor = isEvent
        ? const Color(0xFFE65100) // Ámbar/Naranja profundo
        : const Color(0xFF2E7D32); // Verde profundo

    final IconData badgeIcon = tipo == 'roda'
        ? Icons.local_fire_department_rounded
        : tipo == 'especial'
            ? Icons.star_rounded
            : Icons.sports_martial_arts_rounded;

    final String typeLabel = tipo == 'roda'
        ? 'RODA 🔥'
        : tipo == 'especial'
            ? 'EVENTO 🌟'
            : 'CLASE 🥋';

    // Determinar texto de ubicación
    final String locationText = lugar.isNotEmpty
        ? lugar
        : (ubicacion.isNotEmpty ? ubicacion : 'Sede Física');

    return GestureDetector(
      onTap: () => context.push('/clase-detalle?claseId=$claseId'),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isEvent
                ? GingaColors.accentAmber.withOpacity(0.3)
                : GingaColors.borderLight.withOpacity(0.7),
            width: isEvent ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Banda de acento vertical izquierda
                Container(
                  width: 5,
                  color: accentColor,
                ),

                // 2. Información Central
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fila de Insignia de Categoría e Insignia Específica
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeBgColor,
                                borderRadius:
                                    BorderRadius.circular(GingaRadius.sm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badgeIcon,
                                      size: 12, color: badgeTextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    typeLabel,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: badgeTextColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Insignia específica de la clase (ej. U. Continental 🎓)
                            if (badge.isNotEmpty && badge != nivel)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: GingaColors.backgroundLight,
                                  border: Border.all(
                                      color: GingaColors.borderLight),
                                  borderRadius:
                                      BorderRadius.circular(GingaRadius.sm),
                                ),
                                child: Text(
                                  badge,
                                  style: GoogleFonts.nunito(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Título de la clase/nivel
                        Text(
                          nivel,
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),

                        // Fila de Horario y Días
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 14, color: accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$hora${dias.isNotEmpty ? " • ${_interpretarDiasDeSemana(dias)}" : ""}',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: GingaColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Fila de Instructor
                        if (instructor.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 14, color: GingaColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Instructor: $instructor',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: GingaColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Fila de Lugar/Ubicación (📍 Crucial para saber a dónde ir)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locationText,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: GingaColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Panel de Acción Derecho
                Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: isEvent
                        ? GingaColors.accentAmber.withOpacity(0.06)
                        : GingaColors.brandGreen.withOpacity(0.04),
                    border: Border(
                      left: BorderSide(
                          color: GingaColors.borderLight.withOpacity(0.5)),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gratis',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.2,
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
                style: GoogleFonts.nunito(color: GingaColors.textSecondary)),
          );
        }

        final reserva =
            snapshot.data!.docs.first.data() as Map<String, dynamic>;

        final String claseId = reserva['clase_id'] ?? '';

        return GestureDetector(
          onTap: claseId.isNotEmpty
              ? () => context.push('/clase-detalle?claseId=$claseId')
              : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GingaRadius.lg),
              border:
                  Border.all(color: GingaColors.accentAmber.withOpacity(0.4)),
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
                      Text(
                          '${reserva['hora']} — ${_interpretarDiasDeSemana(reserva['dias'] ?? "")}',
                          style: GoogleFonts.nunito(
                              fontSize: 13, color: GingaColors.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: GingaColors.accentAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(GingaRadius.full),
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

  Widget _buildInfoBadge(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GingaColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: GingaColors.brandGreen),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: GingaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

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
            style: GoogleFonts.nunito(color: GingaColors.textSecondary)),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .doc(claseId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: GingaColors.brandGreen,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (!snapshot.data!.exists) {
          return const SizedBox();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        return GestureDetector(
          onTap: () => context.push('/clase-detalle?claseId=$claseId'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GingaRadius.lg),
              border:
                  Border.all(color: GingaColors.brandGreen.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: GingaColors.brandGreen.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila superior: Nivel + Badge de Activo
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        data['nivel'] ?? '',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: GingaColors.brandGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                      child: Text(
                        'ACTIVO',
                        style: GoogleFonts.montserrat(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.brandGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Divisor sutil
                Container(
                  height: 1,
                  color: GingaColors.borderLight,
                ),
                const SizedBox(height: 12),

                // Detalles inferiores adaptables
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoBadge(
                        Icons.access_time_rounded, data['hora'] ?? ''),
                    _buildInfoBadge(Icons.calendar_today_outlined,
                        _interpretarDiasDeSemana(data['dias'] ?? '')),
                    _buildInfoBadge(
                        Icons.person_outline_rounded, data['instructor'] ?? ''),
                  ],
                ),
              ],
            ),
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
                        fontSize: 12, color: GingaColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CLASE PENDIENTE (U. Continental en revisión)
// ─────────────────────────────────────────

class _ClasePendiente extends StatelessWidget {
  final String claseId;
  const _ClasePendiente({required this.claseId});

  @override
  Widget build(BuildContext context) {
    if (claseId.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GingaColors.cardLight,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
        ),
        child: Text('Cargando información de tu clase...',
            style: GoogleFonts.nunito(color: GingaColors.textSecondary)),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .doc(claseId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
                color: GingaColors.brandGreen, strokeWidth: 2),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                ),
                child: Text(
                  data['hora'] ?? '',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['nivel'] ?? '',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textSecondary,
                      ),
                    ),
                    Text(
                      _interpretarDiasDeSemana(data['dias'] ?? ''),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: GingaColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Instructor: ${data['instructor'] ?? ""}',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: GingaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  'PENDIENTE',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.amber.shade700,
                    letterSpacing: 0.5,
                  ),
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
//  HEADER
// ─────────────────────────────────────────

class _Header extends StatelessWidget {
  final String nombre;
  final String corda;
  final String uid;
  final GlobalKey avatarKey;
  
  const _Header({
    required this.nombre,
    required this.corda,
    required this.uid,
    required this.avatarKey,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¡Hola,',
                  style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: GingaColors.textSecondary)),
              Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textPrimary),
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
        const SizedBox(width: 16),
        if (uid.isNotEmpty) ...[
          _NotificationsBell(uid: uid),
          const SizedBox(width: 8),
        ],
        GestureDetector(
          key: avatarKey,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProgresoScreen(),
              ),
            );
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: GingaColors.cardLight,
            child: Text(inicial,
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: GingaColors.brandGreen,
                    fontSize: 16)),
          ),
        ),
      ],
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
              icon: const Icon(Icons.notifications_outlined,
                  size: 26, color: GingaColors.textPrimary),
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
    backgroundColor: GingaColors.backgroundLight,
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
                    const Icon(Icons.notifications,
                        color: GingaColors.brandGreen, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Notificaciones',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
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
                    style: GoogleFonts.nunito(
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
                    return const Center(
                        child: CircularProgressIndicator(
                            color: GingaColors.brandGreen));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 60,
                              color:
                                  GingaColors.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No tienes notificaciones aún',
                            style: GoogleFonts.nunito(
                                color: GingaColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  final notifs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: notifs.length,
                    itemBuilder: (context, index) {
                      final notifDoc = notifs[index];
                      final data = notifDoc.data() as Map<String, dynamic>;
                      final String titulo = data['titulo'] ?? 'Alerta';
                      final String mensaje = data['mensaje'] ?? '';
                      final String tipo = data['tipo'] ?? 'sistema';
                      final bool leido = data['leido'] ?? false;

                      // Marcar como leída de forma asíncrona al mostrarse
                      if (!leido) {
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('notificaciones')
                            .doc(notifDoc.id)
                            .update({'leido': true});
                      }

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
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: leido
                              ? Colors.transparent
                              : itemColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(
                            color: leido
                                ? GingaColors.borderLight
                                : itemColor.withOpacity(0.3),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        titulo,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: GingaColors.textPrimary,
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
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: GingaColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

// ─────────────────────────────────────────
//  WORKSHOP BANNER (para activos)
// ─────────────────────────────────────────

class _WorkshopBanner extends StatelessWidget {
  final String userNombre;

  const _WorkshopBanner({required this.userNombre});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .orderBy('fecha_inicio', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: GingaColors.cardLight,
              borderRadius: BorderRadius.circular(GingaRadius.lg),
            ),
            child:
                const CircularProgressIndicator(color: GingaColors.brandGreen),
          );
        }

        Map<String, dynamic>? eventData;
        String? eventId;
        final now = DateTime.now();

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp? dateEnd = data['fecha_fin'] as Timestamp?;

            // Si el evento no ha culminado aún, es el evento a mostrar
            if (dateEnd != null && dateEnd.toDate().isAfter(now)) {
              eventData = data;
              eventId = doc.id;
              break;
            }
          }
        }

        // ── Estado C: Modo Comunidad (No hay eventos programados) ──────────
        if (eventData == null || eventId == null) {
          return _buildCommunityBanner(context);
        }

        final Timestamp dateStartTs = eventData['fecha_inicio'] as Timestamp;
        final Timestamp dateEndTs = eventData['fecha_fin'] as Timestamp;
        final DateTime dateStart = dateStartTs.toDate();
        final DateTime dateEnd = dateEndTs.toDate();

        // Determinar si hoy está dentro del rango del evento
        final bool isTodayEvent =
            now.isAfter(dateStart.subtract(const Duration(hours: 12))) &&
                now.isBefore(dateEnd.add(const Duration(hours: 12)));

        if (isTodayEvent) {
          // ── Estado B: Evento en Curso ────────────────────────────────────
          return _buildActiveTodayBanner(context, eventId, eventData);
        } else {
          // ── Estado A: Próximo Evento ─────────────────────────────────────
          return _buildUpcomingEventBanner(context, eventId, eventData);
        }
      },
    );
  }

  // ── ESTADO A: Banner de Próximo Taller ─────────────────────────────────────
  Widget _buildUpcomingEventBanner(
      BuildContext context, String eventId, Map<String, dynamic> data) {
    final titulo = data['titulo'] ?? 'Taller Especial';
    final organizador = data['organizador'] ?? 'Mestre Invitado';
    final fechaTexto = data['fecha_texto'] ?? 'Próximamente';
    final imagenUrl = data['imagen_url'] ?? 'assets/images/roda.jpg';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GingaColors.accentAmber,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRÓXIMO TALLER GINGA',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5D3D03),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$titulo\ncon $organizador',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4A2F02),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  fechaTexto,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5D3D03),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _navegarADetalleEventoOModal(context, eventId, data),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2F02),
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                    ),
                    child: Text(
                      'Ver Detalles y Reservar',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(GingaRadius.md),
            child: SizedBox(
              width: 110,
              height: 110,
              child: imagenUrl.startsWith('assets/')
                  ? Image.asset(imagenUrl, fit: BoxFit.cover)
                  : Image.network(imagenUrl, fit: BoxFit.cover,
                      errorBuilder: (c, o, s) {
                      return Image.asset('assets/images/roda.jpg',
                          fit: BoxFit.cover);
                    }),
            ),
          ),
        ],
      ),
    );
  }

  // ── ESTADO B: Banner de ¡Hoy es el Evento! (Glow verde intenso) ──────────────
  Widget _buildActiveTodayBanner(
      BuildContext context, String eventId, Map<String, dynamic> data) {
    final titulo = data['titulo'] ?? 'Taller Especial';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GingaColors.brandGreen,
            Colors.green.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        boxShadow: [
          BoxShadow(
            color: GingaColors.brandGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on,
                        color: GingaColors.accentAmber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '¡EVENTO EN CURSO HOY!',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '¡$titulo ya empezó!',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Revisa los horarios de los talleres y las rodas del día.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _navegarADetalleEventoOModal(context, eventId, data),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: GingaColors.accentAmber,
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                    ),
                    child: Text(
                      'Ver Actividades Hoy ➡️',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4A2F02),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.celebration_rounded,
            color: GingaColors.accentAmber,
            size: 80,
          ),
        ],
      ),
    );
  }

  // ── ESTADO C: Modo Comunidad (Acceso Rápido a Entrenamiento) ─────────────────
  Widget _buildCommunityBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GingaColors.cardLight,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.brandGreen.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENTRENAMIENTO DIARIO',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.brandGreen,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¡Suda la camiseta en casa!',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Repasa tu Ginga y tus patadas en nuestra Biblioteca Digital.',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: GingaColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    // Pasa directamente a los tutoriales de la biblioteca
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TutorialesScreen()),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen,
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                    ),
                    child: Text(
                      'Ver Tutoriales On-Demand',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(GingaRadius.md),
            child: Image.asset(
              'assets/images/moves.jpg',
              width: 105,
              height: 105,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navegarADetalleEventoOModal(
      BuildContext context, String eventId, Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: GingaColors.brandGreen),
      ),
    );

    // Función interna para limpiar emojis y caracteres especiales, dejando solo texto y números limpios
    String cleanString(String text) {
      return text
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s\u00C0-\u00FF]'), '') // Quita emojis, conserva letras y números acentuados
          .replaceAll(RegExp(r'\s+'), ' ') // Normaliza espacios múltiples
          .trim();
    }

    try {
      final String eventTitle = data['titulo'] ?? '';
      final String eventOrganizador = data['organizador'] ?? '';
      
      final String cleanTitle = cleanString(eventTitle);
      final String cleanOrganizador = cleanString(eventOrganizador);

      final clasesSnap = await FirebaseFirestore.instance
          .collection('clases')
          .where('tipo', isEqualTo: 'especial')
          .get();
      
      String? matchedClaseId;
      for (var doc in clasesSnap.docs) {
        final cData = doc.data();
        final String badge = (cData['badge'] ?? '').toString();
        final String instructor = (cData['instructor'] ?? '').toString();
        
        final String cleanBadge = cleanString(badge);
        final String cleanInstructor = cleanString(instructor);
        
        // Coincidencia robusta sin emojis (p. ej. "entreno y roda al aire libre" contiene "entreno y roda")
        if ((cleanTitle.isNotEmpty && cleanBadge.isNotEmpty && (cleanTitle.contains(cleanBadge) || cleanBadge.contains(cleanTitle))) ||
            (cleanTitle.isNotEmpty && cleanInstructor.isNotEmpty && (cleanTitle.contains(cleanInstructor) || cleanInstructor.contains(cleanTitle))) ||
            (cleanInstructor.isNotEmpty && cleanOrganizador.isNotEmpty && (cleanInstructor.contains(cleanOrganizador) || cleanOrganizador.contains(cleanInstructor)))) {
          matchedClaseId = doc.id;
          break;
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // Cierra loader
        if (matchedClaseId != null) {
          context.push('/clase-detalle?claseId=$matchedClaseId');
        } else {
          _mostrarDetallesEvento(context, eventId, data);
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Cierra loader
        _mostrarDetallesEvento(context, eventId, data);
      }
    }
  }

  // ── Bottom Sheet de Detalles e Inscripción Interactiva ────────────────────
  void _mostrarDetallesEvento(
      BuildContext context, String eventId, Map<String, dynamic> data) {
    final titulo = data['titulo'] ?? 'Taller Especial';
    final organizador = data['organizador'] ?? 'Mestre Invitado';
    final fechaTexto = data['fecha_texto'] ?? 'Próximamente';
    final lugar = data['lugar'] ?? 'Academia Ginga';
    final descripcion = data['descripcion'] ?? '';
    final List<dynamic> cronograma = data['cronograma'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).padding.bottom > 0
                ? MediaQuery.of(ctx).padding.bottom + 16
                : 24,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de arrastre
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: GingaColors.borderLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Título
                Text(
                  titulo,
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Organizado por: $organizador',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.brandGreen,
                  ),
                ),
                const SizedBox(height: 16),

                // Fila de Info (Fecha & Lugar)
                _buildInfoCard(
                    Icons.calendar_today_rounded, 'FECHA', fechaTexto),
                const SizedBox(height: 10),
                _buildInfoCard(Icons.location_on_rounded, 'LUGAR', lugar),
                const SizedBox(height: 20),

                // Descripción
                Text(
                  'Acerca del Evento',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descripcion,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: GingaColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Cronograma de actividades
                if (cronograma.isNotEmpty) ...[
                  Text(
                    'Cronograma de Actividades',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...cronograma.map((item) {
                    final dia = item['dia'] ?? '';
                    final hora = item['hora'] ?? '';
                    final act = item['actividad'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: GingaColors.cardLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dia,
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: GingaColors.brandGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  act,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  hora,
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    color: GingaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                ],

                // ── Registro e Inscripción Dinámica ────────────────────────
                StreamBuilder<bool>(
                  stream: EventosService.instance.estaRegistrado(eventId),
                  builder: (context, snapshot) {
                    final registrado = snapshot.data ?? false;

                    if (registrado) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: GingaColors.cardLight,
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(
                              color: GingaColors.brandGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: GingaColors.brandGreen, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¡Tu cupo está reservado! ✅',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: GingaColors.brandGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Te esperamos con toda la energía. ¡No olvides traer tu uniforme oficial!',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: GingaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ElevatedButton(
                      onPressed: () async {
                        try {
                          await EventosService.instance
                              .registrarAsistencia(eventId, userNombre);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '¡Reserva confirmada con éxito, $userNombre! 🎉 Nos vemos en la Roda.'),
                                backgroundColor: GingaColors.brandGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al reservar: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.brandGreen,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'CONFIRMAR MI ASISTENCIA 🙋‍♂️',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: GingaColors.brandGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
                    height: 90, width: double.infinity, fit: BoxFit.cover)
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
  final GlobalKey bibliotecaTabKey;

  const _GingaBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.bibliotecaTabKey,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.3),
      padding: EdgeInsets.zero,
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
          ),
          const SizedBox(width: 64), // Espacio central para el FAB con notch
          Expanded(
            child: _buildNavItem(
              1,
              Icons.menu_book_outlined,
              Icons.menu_book,
              'Biblioteca',
              navKey: bibliotecaTabKey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label, {Key? navKey}) {
    final isSelected = currentIndex == index;
    return InkWell(
      key: navKey,
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color:
                isSelected ? GingaColors.brandGreen : GingaColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? GingaColors.brandGreen
                  : GingaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorePromoBanner extends StatelessWidget {
  const _StorePromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GingaColors.brandGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.brandGreen.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront,
                        color: GingaColors.brandGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ginga Store 🥋',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.brandGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Consigue abadás, camisetas e instrumentos oficiales de la academia. Reserva tu pedido y recógelo en clase.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: GingaColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => context.push('/tienda'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen,
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                    ),
                    child: Text(
                      'Explorar Catálogo',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

class WalkthroughOverlay extends StatefulWidget {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final VoidCallback onNext;
  final bool isLastStep;
  final bool showHeartbeat;
  final VoidCallback onDismiss;

  const WalkthroughOverlay({
    super.key,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.onNext,
    required this.isLastStep,
    required this.onDismiss,
    this.showHeartbeat = false,
  });

  @override
  State<WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<WalkthroughOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startRetryTimer();
  }

  @override
  void didUpdateWidget(WalkthroughOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) {
      _retryTimer?.cancel();
      _startRetryTimer();
    }
  }

  void _startRetryTimer() {
    int retryCount = 0;
    _retryTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      retryCount++;
      final renderBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null || retryCount > 40) {
        timer.cancel();
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Encontrar posición del widget objetivo en la pantalla
        final renderBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          // Render a simple full screen dark overlay while waiting for target to mount
          // Block touches (mandatory interaction)
          return GestureDetector(
            onTap: () {},
            child: Container(
              color: Colors.black.withOpacity(0.78),
              width: double.infinity,
              height: double.infinity,
            ),
          );
        }

        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        return Stack(
          children: [
            // Fondo oscuro atenuado que bloquea toques fortuitos
            GestureDetector(
              onTap: () {}, // No hace nada al tocar fuera (interacción obligatoria)
              child: CustomPaint(
                size: Size.infinite,
                painter: _HighlightPainter(
                  rect: Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
                ),
              ),
            ),

            // Área interactiva del Spotlight (tocar el elemento destacado avanza al siguiente paso)
            Positioned(
              left: position.dx,
              top: position.dy,
              width: size.width,
              height: size.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onNext,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),

            // Borde brillante pulsante (heartbeat effect)
            Positioned(
              left: position.dx - 6,
              top: position.dy - 6,
              width: size.width + 12,
              height: size.height + 12,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final double scale = widget.showHeartbeat
                        ? 1.0 + (_pulseController.value * 0.04)
                        : 1.0;
                    final double opacity = 0.5 + (1.0 - _pulseController.value) * 0.5;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: GingaColors.brandGreen.withOpacity(opacity),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: GingaColors.brandGreen.withOpacity(0.35 * opacity),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Burbuja de información
            _buildTooltipBubble(position, size, constraints),
          ],
        );
      },
    );
  }

  Widget _buildTooltipBubble(Offset position, Size size, BoxConstraints constraints) {
    final bool isTopHalf = position.dy < (constraints.maxHeight / 2);
    
    double? top;
    double? bottom;
    
    if (isTopHalf) {
      top = position.dy + size.height + 16;
    } else {
      bottom = constraints.maxHeight - position.dy + 16;
    }

    final double screenWidth = constraints.maxWidth;
    const double bubbleWidth = 290.0;
    
    final double targetCenterX = position.dx + size.width / 2;
    
    // Centrar la burbuja sobre el centro del target
    double bubbleLeft = targetCenterX - (bubbleWidth / 2);
    // Limitar para que no se salga de los márgenes de seguridad de la pantalla (mínimo 16px)
    bubbleLeft = bubbleLeft.clamp(16.0, screenWidth - bubbleWidth - 16.0);
    
    // Posicionar el triángulo horizontalmente alineado con el centro del target relativo a la burbuja
    double arrowLeft = targetCenterX - bubbleLeft - 9.0; // 9.0 es la mitad del ancho del triángulo (18)
    // Evitar que el triángulo se salga de los bordes redondeados de la burbuja (radio 20)
    arrowLeft = arrowLeft.clamp(20.0, bubbleWidth - 18.0 - 20.0);

    return Positioned(
      top: top,
      bottom: bottom,
      left: bubbleLeft,
      width: bubbleWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTopHalf)
            Padding(
              padding: EdgeInsets.only(left: arrowLeft),
              child: CustomPaint(
                size: const Size(18, 10),
                painter: _TrianglePainter(isUp: true, color: Colors.white),
              ),
            ),
          
          Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.24),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
                border: Border.all(
                  color: GingaColors.brandGreen.withOpacity(0.22),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: GingaColors.brandGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.tips_and_updates,
                          color: GingaColors.brandGreen,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.description,
                    style: GoogleFonts.nunito(
                      fontSize: 12.5,
                      color: GingaColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: widget.onDismiss,
                        style: TextButton.styleFrom(
                          foregroundColor: GingaColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(60, 36),
                        ),
                        child: Text(
                          'Omitir',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: widget.onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(90, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.isLastStep ? '¡Empezar!' : 'Siguiente',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              widget.isLastStep ? Icons.check : Icons.arrow_forward,
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (!isTopHalf)
            Padding(
              padding: EdgeInsets.only(left: arrowLeft, top: 4),
              child: CustomPaint(
                size: const Size(18, 10),
                painter: _TrianglePainter(isUp: false, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final Rect rect;

  _HighlightPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.78);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final holePaint = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(16)),
      holePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HighlightPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}

class _TrianglePainter extends CustomPainter {
  final bool isUp;
  final Color color;

  _TrianglePainter({required this.isUp, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) {
    return oldDelegate.isUp != isUp || oldDelegate.color != color;
  }
}
