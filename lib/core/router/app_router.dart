import 'package:ginga_app/features/biblioteca/tutor_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ginga_app/features/onboarding/splash_screen.dart';
import 'package:ginga_app/features/onboarding/onboarding_screen.dart';
import 'package:ginga_app/features/auth/role_selection_screen.dart';
import 'package:ginga_app/features/auth/profile_creation_screen.dart';
import 'package:ginga_app/features/auth/login_screen.dart';
import 'package:ginga_app/features/home/home_screen.dart';
import 'package:ginga_app/features/instructor/instructor_clase_screen.dart';

// 🟢 NUEVOS IMPORTS
import 'package:ginga_app/features/biblioteca/practicar_toque_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loc = state.matchedLocation;

    final publicRoutes = ['/login', '/onboarding', '/role-selection', '/profile-creation', '/splash'];
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
      path: '/role-selection',
      builder: (context, state) => const RoleSelectionScreen(),
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
      path: '/instructor-clase',
      builder: (context, state) => const InstructorClaseScreen(),
    ),
    
    // 🟢 NUEVAS RUTAS CONECTADAS
    GoRoute(
      path: '/tutorial-detail',
      builder: (context, state) => const TutorialDetailScreen(),
    ),
    GoRoute(
      path: '/practicar-toque',
      builder: (context, state) => const PracticarToqueScreen(),
    ),
    GoRoute(
  path: '/tutorial-detail',
  builder: (context, state) => const TutorialDetailScreen(),
),
  ],
);