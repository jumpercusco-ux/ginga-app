import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _screenFade;

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Text animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Fade out
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _screenFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // 1 — Logo aparece
    await _logoController.forward();

    // 2 — Texto aparece
    await Future.delayed(const Duration(milliseconds: 200));
    await _textController.forward();

    // 3 — Espera
    await Future.delayed(const Duration(milliseconds: 800));

    // 4 — Fade out y navega
    await _fadeController.forward();

    if (!mounted) return;
    await _navigate();
  }

  Future<void> _navigate() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.go('/onboarding');
      return;
    }

    // Usuario logueado → leer rol
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final rol = doc.data()?['rol'] ?? 'alumno';
        if (rol == 'profesor') {
          context.go('/instructor-clase');
        } else {
          context.go('/home');
        }
      } else {
        context.go('/profile-creation');
      }
    } catch (_) {
      if (mounted) context.go('/home');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenFade,
      builder: (context, child) {
        return Opacity(
          opacity: _screenFade.value,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo animado ─────────────────────
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/images/logo_ginga.png',
                  width: 160,
                  height: 160,
                ),
              ),

              const SizedBox(height: 24),

              // ── Texto animado ────────────────────
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value,
                    child: SlideTransition(
                      position: _textSlide,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      'GINGA APP',
                      style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Comunidad & Entrenamiento',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: GingaColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // ── Loading indicator ────────────────
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value,
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      GingaColors.brandGreen.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}