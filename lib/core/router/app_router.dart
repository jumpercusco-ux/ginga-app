import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ginga_app/features/onboarding/onboarding_screen.dart';
import 'package:ginga_app/features/auth/role_selection_screen.dart';
import 'package:ginga_app/features/auth/profile_creation_screen.dart';
import 'package:ginga_app/features/auth/login_screen.dart';
import 'package:ginga_app/features/home/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loc = state.matchedLocation;

    final publicRoutes = ['/login', '/onboarding', '/role-selection', '/profile-creation'];
    final isPublic = publicRoutes.contains(loc);

    if (user != null && loc == '/login') return '/home';
    if (user == null && !isPublic) return '/login';
    return null;
  },
  routes: [
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
  ],
);