import 'package:ginga_app/features/biblioteca/tutor_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ginga_app/features/onboarding/splash_screen.dart';
import 'package:ginga_app/features/onboarding/onboarding_screen.dart';
import 'package:ginga_app/features/auth/profile_creation_screen.dart';
import 'package:ginga_app/features/auth/login_screen.dart';
import 'package:ginga_app/features/home/home_screen.dart';
import 'package:ginga_app/features/home/clase_detalle_screen.dart';
import 'package:ginga_app/features/instructor/instructor_clase_screen.dart';
import 'package:ginga_app/features/instructor/crear_clase_screen.dart';
import 'package:ginga_app/features/biblioteca/practicar_toque_screen.dart';
import 'package:ginga_app/features/tienda/tienda_screen.dart';
import 'package:ginga_app/features/tienda/producto_detalle_screen.dart';
import 'package:ginga_app/features/tienda/carrito_screen.dart';
import 'package:ginga_app/features/instructor/instructor_tienda_screen.dart';
import 'package:ginga_app/features/instructor/crear_producto_screen.dart';
import 'package:ginga_app/features/instructor/instructor_tutoriales_screen.dart';
import 'package:ginga_app/features/instructor/crear_tutorial_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loc = state.matchedLocation;

    final publicRoutes = ['/login', '/onboarding', '/profile-creation', '/splash'];
    final isPublic = publicRoutes.contains(loc);

    if (user != null && loc == '/login') return '/home';
    if (user == null && !isPublic) return '/login';
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/profile-creation',
      builder: (context, state) => const ProfileCreationScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/clase-detalle',
      builder: (context, state) {
        final claseId = state.uri.queryParameters['claseId'] ?? '';
        return ClaseDetalleScreen(claseId: claseId);
      },
    ),
    GoRoute(
      path: '/instructor-clase',
      builder: (context, state) => const InstructorClaseScreen(),
    ),
    GoRoute(
      path: '/crear-clase',
      builder: (context, state) => const CrearClaseScreen(),
    ),
    
    GoRoute(
      path: '/tutorial-detail',
      builder: (context, state) => const TutorialDetailScreen(),
    ),
    GoRoute(
      path: '/practicar-toque',
      builder: (context, state) => const PracticarToqueScreen(),
    ),
    GoRoute(
      path: '/tienda',
      builder: (context, state) => const TiendaScreen(),
    ),
    GoRoute(
      path: '/producto-detail',
      builder: (context, state) {
        final productoId = state.uri.queryParameters['productoId'] ?? '';
        return ProductoDetalleScreen(productoId: productoId);
      },
    ),
    GoRoute(
      path: '/carrito',
      builder: (context, state) => const CarritoScreen(),
    ),
    GoRoute(
      path: '/instructor-tienda',
      builder: (context, state) => const InstructorTiendaScreen(),
    ),
    GoRoute(
      path: '/crear-producto',
      builder: (context, state) {
        final productoId = state.uri.queryParameters['productoId'] ?? '';
        return CrearProductoScreen(productoId: productoId);
      },
    ),
    GoRoute(
      path: '/instructor-tutoriales',
      builder: (context, state) => const InstructorTutorialesScreen(),
    ),
    GoRoute(
      path: '/crear-tutorial',
      builder: (context, state) {
        final tutorialId = state.uri.queryParameters['tutorialId'] ?? '';
        return CrearTutorialScreen(tutorialId: tutorialId);
      },
    ),
  ],
);