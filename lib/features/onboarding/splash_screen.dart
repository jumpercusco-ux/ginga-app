import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

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
    // En web, la animación de splash solo suma espera antes de que alguien
    // llegado por un anuncio vea la landing — se salta directo. Se espera al
    // primer frame (addPostFrameCallback) porque GoRouter no admite navegar
    // en medio del build inicial del widget.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
      return;
    }

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
      // En web (Google/Instagram/bio-link) mostramos la landing de marketing;
      // en la app móvil se mantiene el carrusel de bienvenida de siempre.
      context.go(kIsWeb ? '/landing' : '/onboarding');
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

  // ... mismos imports ...

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
        backgroundColor: Colors.black,
        // En web no se anima nada (se navega casi de inmediato) — mostrar la
        // columna igual arriesga un frame con el logo a medio animar (opacidad
        // en 0, a mitad de escala). Mejor una pantalla negra lisa, sin nada.
        body: kIsWeb
            ? const SizedBox.shrink()
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centra verticalmente
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
                  'assets/images/logofull.png',
                  width: 180,
                ),
              ),

              const SizedBox(height: 16), // Espacio corto entre logo y eslogan

              // ── Eslogan animado ────────────────────
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
                child: Text(
                  'Comunidad & Entrenamiento',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              
              // Eliminamos el indicador de carga para que el centrado sea perfecto
              // Si lo necesitas, puedes dejar un SizedBox vacío
              const SizedBox(height: 20), 
            ],
          ),
        ),
      ),
    );
  }
}