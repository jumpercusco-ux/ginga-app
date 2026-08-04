import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/ginga_theme.dart';

/// Landing pública para visitantes web sin sesión (Google/Instagram/bio-link).
/// La app móvil sigue usando el carrusel de OnboardingScreen — esta pantalla
/// es solo para la entrada web, donde el objetivo es conversión directa a
/// WhatsApp (el mismo canal ya validado con la campaña de ads), no un tour
/// de las funciones de la app.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const String _whatsappNumero = '51925727071';

  Future<void> _abrirWhatsApp(BuildContext context) async {
    const mensaje = '¡Hola! Quiero más información.';
    final uri = Uri.parse('https://wa.me/$_whatsappNumero?text=${Uri.encodeComponent(mensaje)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo abrir WhatsApp: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(onWhatsApp: () => _abrirWhatsApp(context)),
            _Propuesta(),
            _Grupos(),
            _CtaFinal(onWhatsApp: () => _abrirWhatsApp(context)),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final Widget child;
  final Color? background;
  const _Section({required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: EdgeInsets.symmetric(
        horizontal: GingaSpacing.lg,
        vertical: GingaSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: child,
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final VoidCallback onWhatsApp;
  const _Hero({required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/roda.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: Colors.black.withOpacity(0.55),
        padding: const EdgeInsets.symmetric(horizontal: GingaSpacing.lg, vertical: GingaSpacing.xxl * 1.5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Image.asset('assets/images/logo_ginga.png', width: 96, height: 96),
                const SizedBox(height: GingaSpacing.lg),
                Text(
                  '¿ENTRENAR O DESPERTAR?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: GingaSpacing.md),
                Text(
                  'Capoeira en Cusco. Un espacio donde el movimiento, la música y la agilidad se unen para romper tus propios límites.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 16, color: Colors.white.withOpacity(0.9), height: 1.5),
                ),
                const SizedBox(height: GingaSpacing.xl),
                _WhatsAppButton(onTap: onWhatsApp),
                const SizedBox(height: GingaSpacing.md),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text(
                    '¿Ya eres alumno? Inicia sesión',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
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

class _WhatsAppButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WhatsAppButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: GingaColors.brandGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.full)),
          elevation: 0,
        ),
        icon: const Icon(Icons.chat_bubble_outline, size: 20),
        label: Text(
          'Escríbenos por WhatsApp',
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Propuesta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        children: [
          Text(
            'Tu primera clase es gratis',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: GingaColors.textPrimary),
          ),
          const SizedBox(height: GingaSpacing.sm),
          Text(
            'Sin compromiso. Ven, prueba, y decide si esto es para ti.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 15, color: GingaColors.textSecondary),
          ),
          const SizedBox(height: GingaSpacing.xl),
          Wrap(
            spacing: GingaSpacing.lg,
            runSpacing: GingaSpacing.lg,
            alignment: WrapAlignment.center,
            children: [
              _Feature(icon: Icons.location_on_outlined, text: 'Urb. Magisterio, Av. de la Cultura E-4'),
              _Feature(icon: Icons.calendar_month_outlined, text: 'Martes y jueves'),
              _Feature(icon: Icons.groups_outlined, text: 'Grupos para niños y adultos'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          Icon(icon, color: GingaColors.brandGreen, size: 28),
          const SizedBox(height: GingaSpacing.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Grupos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      background: GingaColors.cardLight,
      child: Column(
        children: [
          Text(
            'Un grupo para cada etapa',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w800, color: GingaColors.textPrimary),
          ),
          const SizedBox(height: GingaSpacing.xl),
          Wrap(
            spacing: GingaSpacing.lg,
            runSpacing: GingaSpacing.lg,
            alignment: WrapAlignment.center,
            children: [
              _GrupoCard(
                imagen: 'assets/images/onbo2.jpg',
                titulo: 'Capoeira Infantil',
                subtitulo: '5 a 12 años · Martes y jueves, 6:00 p.m.',
                descripcion: 'Agilidad, confianza y coordinación desde cero.',
              ),
              _GrupoCard(
                imagen: 'assets/images/moves.jpg',
                titulo: 'Jóvenes y Adultos',
                subtitulo: '13 años en adelante · Martes y jueves, 7:00 p.m.',
                descripcion: 'Fuerza, flexibilidad, y libera el estrés de la semana.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrupoCard extends StatelessWidget {
  final String imagen;
  final String titulo;
  final String subtitulo;
  final String descripcion;
  const _GrupoCard({
    required this.imagen,
    required this.titulo,
    required this.subtitulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: GingaColors.backgroundLight,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.asset(
              imagen,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: GingaColors.brandGreen.withOpacity(0.15),
                child: const Icon(Icons.sports_martial_arts, color: GingaColors.brandGreen, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(GingaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w800, color: GingaColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitulo,
                    style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: GingaColors.brandGreen)),
                const SizedBox(height: 6),
                Text(descripcion,
                    style: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaFinal extends StatelessWidget {
  final VoidCallback onWhatsApp;
  const _CtaFinal({required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        children: [
          Text(
            '¿Lista/o para tu primera clase?',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w800, color: GingaColors.textPrimary),
          ),
          const SizedBox(height: GingaSpacing.sm),
          Text(
            'Escríbenos y te ayudamos a encontrar el horario ideal para ti.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textSecondary),
          ),
          const SizedBox(height: GingaSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: _WhatsAppButton(onTap: onWhatsApp),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GingaSpacing.lg),
      child: Column(
        children: [
          Text('GINGA PERÚ • COMUNIDAD & ENTRENAMIENTO',
              style: GoogleFonts.montserrat(
                  fontSize: 10, color: GingaColors.borderLight, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: GingaSpacing.sm),
          GestureDetector(
            onTap: () => context.go('/onboarding'),
            child: Text(
              'Prefiero crear una cuenta',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: GingaColors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
