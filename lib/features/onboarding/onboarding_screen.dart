import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      imagePath: 'assets/images/onbo1.jpg',
     title: 'Reserva tu clase\nde Capoeira',
    subtitle: 'Ve los horarios disponibles y reserva tu lugar en segundos. Tu primera clase es gratis.',
    ),
    _OnboardingData(
      imagePath: 'assets/images/onbo2.jpg',
        title: 'Sigue tu camino\nde graduación',
    subtitle: 'Registra tu asistencia, acumula experiencia y avanza en tu corda paso a paso.',
    ),
    _OnboardingData(
      imagePath: 'assets/images/onbo3.jpg',
     title: 'Sumérgete en la \nesencia de la capoeira',
    subtitle: 'Practica el berimbau, aprende cantigas y descubre la cultura de la Capoeira.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
context.go('/login');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Fondo con imagen full screen ──
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _OnboardingPage(data: _pages[index]);
            },
          ),

          // ── Overlay degradado inferior ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87, Colors.black],
                ),
              ),
            ),
          ),

          // ── Contenido inferior ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        // Row(
                        //   children: [
                        //     Container(
                        //       width: 32,
                        //       height: 32,
                        //       decoration: BoxDecoration(
                        //         color: GingaColors.brandGreen,
                        //         borderRadius: BorderRadius.circular(8),
                        //       ),
                        //       child: const Icon(Icons.sports_martial_arts,
                        //           color: Colors.white, size: 18),
                        //     ),
                        //     const SizedBox(width: 8),
                        //     // Text(
                        //     //   'Ginga App',
                        //     //   style: GoogleFonts.montserrat(
                        //     //     color: Colors.white,
                        //     //     fontWeight: FontWeight.w700,
                        //     //     fontSize: 15,
                        //     //   ),
                        //     // ),
                        //   ],
                        // ),

                        const SizedBox(height: 24),

                        // Título
                        Text(
                          _pages[_currentPage].title,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtítulo
                        Text(
                          _pages[_currentPage].subtitle,
                          style: GoogleFonts.montserrat(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Dots indicadores
                        Row(
                          children: List.generate(_pages.length, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              width: _currentPage == index ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? GingaColors.brandGreen
                                    : Colors.white30,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 24),

                        // Botón Siguiente / Empezar
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GingaColors.brandGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _currentPage == _pages.length - 1
                                  ? 'Empezar'
                                  : 'Siguiente',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Saltar introducción
                        Center(
                          child: GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Saltar introducción',
                              style: GoogleFonts.montserrat(
                                color: Colors.white54,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white54,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Página individual ───────────────────────────────
class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        data.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: GingaColors.backgroundDark,
          child: const Center(
            child: Icon(Icons.sports_martial_arts,
                size: 80, color: GingaColors.brandGreen),
          ),
        ),
      ),
    );
  }
}

// ─── Modelo de datos ─────────────────────────────────
class _OnboardingData {
  final String imagePath;
  final String title;
  final String subtitle;

  _OnboardingData({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
}