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
///
/// Estilo visual: negro como color de acción principal (botones), verde de
/// marca como acento — inspirado en la referencia que compartió el cliente,
/// adaptado a los dos colores reales del manual de marca.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  static const String _whatsappNumero = '51925727071';
  static const String _tiktokUrl = 'https://www.tiktok.com/@gingaperu';
  static const String _instagramUrl = 'https://www.instagram.com/gingaperu/';
  static const String _facebookUrl = 'https://www.facebook.com/profile.php?id=61585316410134';

  final ScrollController _scrollController = ScrollController();
  bool _scrolledPastHero = false;
  double _heroHeight = 640;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pastHero = _scrollController.offset > _heroHeight - kTopBarHeight;
    if (pastHero != _scrolledPastHero) {
      setState(() => _scrolledPastHero = pastHero);
    }
  }

  Future<void> _abrirWhatsApp(BuildContext context) async {
    const mensaje = '¡Hola! Quiero más información.';
    await _abrirUrl(context, 'https://wa.me/$_whatsappNumero?text=${Uri.encodeComponent(mensaje)}');
  }

  Future<void> _abrirUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir el enlace';
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo abrir: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    _heroHeight = MediaQuery.of(context).size.height < 520 ? 520 : MediaQuery.of(context).size.height;
    // El listener se re-registra sin duplicar gracias a removeListener primero.
    _scrollController.removeListener(_onScroll);
    _scrollController.addListener(_onScroll);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                _Hero(height: _heroHeight, onWhatsApp: () => _abrirWhatsApp(context)),
                _SobreGinga(),
                _Disciplinas(),
                _HorariosYPrecios(),
                _Comunidad(),
                _Ubicacion(),
                _CtaFinal(onWhatsApp: () => _abrirWhatsApp(context)),
                _Footer(
                  onWhatsApp: () => _abrirWhatsApp(context),
                  onTiktok: () => _abrirUrl(context, _tiktokUrl),
                  onInstagram: () => _abrirUrl(context, _instagramUrl),
                  onFacebook: () => _abrirUrl(context, _facebookUrl),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(solid: _scrolledPastHero, onWhatsApp: () => _abrirWhatsApp(context)),
          ),
        ],
      ),
    );
  }
}

/// Wrapper de sección: ancho máximo consistente y padding generoso, para que
/// la landing se sienta amplia y no apretada.
class _Section extends StatelessWidget {
  final Widget child;
  final Color background;
  const _Section({required this.child, this.background = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: GingaSpacing.lg, vertical: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: child,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final IconData? icon;
  const _PillButton({
    required this.label,
    required this.onTap,
    this.background = Colors.black,
    this.foreground = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.full)),
        elevation: 0,
      ),
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

/// Altura fija de _TopBar — usada como umbral de scroll para saber cuándo
/// pasar de flotante/transparente a sólido.
const double kTopBarHeight = 64;

/// Barra superior flotante: transparente con logo/botón en blanco mientras
/// se ve el hero (foto de fondo oscura), y sólida (blanco, logo a color,
/// botón negro) apenas se pasa del hero. El logo en blanco se logra con un
/// ColorFilter — no requiere un archivo aparte todavía.
class _TopBar extends StatelessWidget {
  final bool solid;
  final VoidCallback onWhatsApp;
  const _TopBar({required this.solid, required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: kTopBarHeight,
      color: solid ? Colors.white : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: GingaSpacing.lg, vertical: GingaSpacing.sm),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: solid
                    ? Image.asset('assets/images/logo_ginga.png', key: const ValueKey('logo-color'), height: 46)
                    : ColorFiltered(
                        key: const ValueKey('logo-white'),
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        child: Image.asset('assets/images/logo_ginga.png', height: 46),
                      ),
              ),
              const Spacer(),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: onWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: solid ? Colors.black : Colors.white,
                    foregroundColor: solid ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.full)),
                    elevation: 0,
                  ),
                  child: Text('Reservar Clase', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final double height;
  final VoidCallback onWhatsApp;
  const _Hero({required this.height, required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        image: DecorationImage(image: AssetImage('assets/images/roda.jpg'), fit: BoxFit.cover),
      ),
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: GingaSpacing.lg, vertical: 72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¿ENTRENAR O DESPERTAR?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: GingaSpacing.md),
                Text(
                  'Capoeira en Cusco. Un espacio donde el movimiento, la música y la agilidad se unen para romper tus propios límites.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(fontSize: 17, color: Colors.white.withValues(alpha: 0.9), height: 1.5),
                ),
                const SizedBox(height: GingaSpacing.xl),
                Wrap(
                  spacing: GingaSpacing.sm,
                  runSpacing: GingaSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    _PillButton(label: 'Reserva tu clase de prueba gratis', onTap: onWhatsApp, icon: Icons.chat_bubble_outline),
                    _PillButton(
                      label: '¿Ya eres alumno? Inicia sesión',
                      onTap: () => context.go('/login'),
                      background: Colors.white,
                      foreground: Colors.black,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SobreGinga extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 760;
    final texto = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Más que patadas y música',
              style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.black, height: 1.2)),
          const SizedBox(height: GingaSpacing.md),
          Text(
            'Hay disciplinas que solo te cansan el cuerpo, y hay otras que te despiertan el alma. Esto es Capoeira en Cusco: un espacio donde el movimiento, la música y la agilidad se unen para romper tus propios límites, ganar confianza y encontrar comunidad.',
            style: GoogleFonts.montserrat(fontSize: 15, color: GingaColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
    final imagen = Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.asset('assets/images/dani.jpg', fit: BoxFit.cover),
        ),
      ),
    );

    return _Section(
      child: isWide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [texto, const SizedBox(width: GingaSpacing.xl), imagen])
          : Column(children: [imagen, const SizedBox(height: GingaSpacing.xl), texto]),
    );
  }
}

class _Disciplinas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      background: GingaColors.cardLight,
      child: Column(
        children: [
          Text('Nuestras disciplinas',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: GingaSpacing.xl),
          Wrap(
            spacing: GingaSpacing.lg,
            runSpacing: GingaSpacing.lg,
            alignment: WrapAlignment.center,
            children: [
              _DisciplinaCard(
                imagen: 'assets/images/moves.jpg',
                badge: 'Disponible ahora',
                badgeColor: GingaColors.brandGreen,
                titulo: 'Capoeira',
                descripcion: 'Para niños y adultos, todos los niveles. Martes y jueves, con primera clase de prueba gratis.',
              ),
              _DisciplinaCard(
                imagen: 'assets/images/onbo3.jpg',
                badge: 'Próximamente',
                badgeColor: Colors.black,
                titulo: 'Acrobacias',
                descripcion: 'Estamos preparando un nuevo programa de acrobacias. Muy pronto más detalles.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisciplinaCard extends StatelessWidget {
  final String imagen;
  final String badge;
  final Color badgeColor;
  final String titulo;
  final String descripcion;
  const _DisciplinaCard({
    required this.imagen,
    required this.badge,
    required this.badgeColor,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.asset(
                  imagen,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: GingaColors.brandGreen.withValues(alpha: 0.15),
                    child: const Icon(Icons.sports_martial_arts, color: GingaColors.brandGreen, size: 40),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(GingaRadius.full)),
                  child: Text(badge, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(GingaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: GoogleFonts.montserrat(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.black)),
                const SizedBox(height: 6),
                Text(descripcion, style: GoogleFonts.montserrat(fontSize: 13.5, color: GingaColors.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorariosYPrecios extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        children: [
          Text('Horarios y precios',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: GingaSpacing.sm),
          Text('Sin matrícula, sin letra chica. Primera clase de prueba 100% gratis.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14, color: GingaColors.textSecondary)),
          const SizedBox(height: GingaSpacing.xl),
          Wrap(
            spacing: GingaSpacing.lg,
            runSpacing: GingaSpacing.lg,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              _PlanCard(
                titulo: 'Capoeira Infantil',
                subtitulo: '5 a 12 años',
                detalle: 'Martes y jueves · 6:00 p.m.',
                precio: 'S/140',
                unidad: '/mes',
                destacado: false,
              ),
              _PlanCard(
                titulo: 'Vienen acompañados',
                subtitulo: '2 personas, 1 mes',
                detalle: 'Cualquiera de los dos grupos',
                precio: 'S/260',
                unidad: 'total',
                destacado: true,
              ),
              _PlanCard(
                titulo: 'Jóvenes y Adultos',
                subtitulo: '13 años en adelante',
                detalle: 'Martes y jueves · 7:00 p.m.',
                precio: 'S/140',
                unidad: '/mes',
                destacado: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String detalle;
  final String precio;
  final String unidad;
  final bool destacado;
  const _PlanCard({
    required this.titulo,
    required this.subtitulo,
    required this.detalle,
    required this.precio,
    required this.unidad,
    required this.destacado,
  });

  @override
  Widget build(BuildContext context) {
    final bg = destacado ? Colors.black : GingaColors.cardLight;
    final fg = destacado ? Colors.white : Colors.black;
    final fgSecundario = destacado ? Colors.white70 : GingaColors.textSecondary;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(GingaSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: destacado ? Border.all(color: GingaColors.brandGreen, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (destacado)
            Padding(
              padding: const EdgeInsets.only(bottom: GingaSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: GingaColors.brandGreen, borderRadius: BorderRadius.circular(GingaRadius.full)),
                child: Text('Más elegido',
                    style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          Text(titulo, style: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          Text(subtitulo, style: GoogleFonts.montserrat(fontSize: 12.5, color: fgSecundario)),
          const SizedBox(height: GingaSpacing.md),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: precio, style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, color: fg)),
              TextSpan(text: ' $unidad', style: GoogleFonts.montserrat(fontSize: 13, color: fgSecundario)),
            ]),
          ),
          const SizedBox(height: GingaSpacing.sm),
          Text(detalle, style: GoogleFonts.montserrat(fontSize: 12.5, color: fgSecundario)),
        ],
      ),
    );
  }
}

class _Comunidad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      background: Colors.black,
      child: Column(
        children: [
          Text('Una comunidad que crece cada semana',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: GingaSpacing.xl),
          Wrap(
            spacing: GingaSpacing.xxl,
            runSpacing: GingaSpacing.lg,
            alignment: WrapAlignment.center,
            children: [
              _Stat(numero: '70+', texto: 'personas escribieron\nsolo la última semana'),
              _Stat(numero: '2', texto: 'grupos por edad,\nniños y adultos'),
              _Stat(numero: '1ra', texto: 'clase de prueba\nsiempre gratis'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String numero;
  final String texto;
  const _Stat({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(numero, style: GoogleFonts.montserrat(fontSize: 40, fontWeight: FontWeight.w800, color: GingaColors.brandGreen)),
        const SizedBox(height: 4),
        Text(texto, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white70, height: 1.4)),
      ],
    );
  }
}

class _Ubicacion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, color: GingaColors.brandGreen, size: 32),
          const SizedBox(width: GingaSpacing.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Urb. Magisterio, Av. de la Cultura E-4',
                    style: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black)),
                Text('3er piso, Edificio Divergym — al costado de la Caja Arequipa',
                    style: GoogleFonts.montserrat(fontSize: 13.5, color: GingaColors.textSecondary)),
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
      background: GingaColors.cardLight,
      child: Column(
        children: [
          Text('¿Lista/o para tu primera clase?',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: GingaSpacing.sm),
          Text('Escríbenos y te ayudamos a encontrar el horario ideal para ti.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14, color: GingaColors.textSecondary)),
          const SizedBox(height: GingaSpacing.lg),
          _PillButton(label: 'Escríbenos por WhatsApp', onTap: onWhatsApp, icon: Icons.chat_bubble_outline),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback onWhatsApp;
  final VoidCallback onTiktok;
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  const _Footer({
    required this.onWhatsApp,
    required this.onTiktok,
    required this.onInstagram,
    required this.onFacebook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: GingaSpacing.lg, vertical: GingaSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              Image.asset('assets/images/logo_ginga.png', width: 44, height: 44),
              const SizedBox(height: GingaSpacing.md),
              Wrap(
                spacing: GingaSpacing.lg,
                alignment: WrapAlignment.center,
                children: [
                  _FooterLink(label: 'Instagram', onTap: onInstagram),
                  _FooterLink(label: 'TikTok', onTap: onTiktok),
                  _FooterLink(label: 'Facebook', onTap: onFacebook),
                  _FooterLink(label: 'WhatsApp', onTap: onWhatsApp),
                ],
              ),
              const SizedBox(height: GingaSpacing.lg),
              GestureDetector(
                onTap: () => context.go('/onboarding'),
                child: Text('Prefiero crear una cuenta',
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white54, decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: GingaSpacing.md),
              Text('GINGA PERÚ • COMUNIDAD & ENTRENAMIENTO',
                  style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white38, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}
