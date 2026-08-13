import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
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
///
/// Colores fijos (no los tokens adaptativos de GingaColors): esta landing
/// pública debe verse siempre igual, sin importar si el visitante tiene su
/// sistema en modo oscuro — usar _kFondoClaro/textSecondary aquí
/// hacía que secciones enteras se pusieran casi negras en modo oscuro.
const Color _kFondoClaro = Color(0xFFE8F5E9);
const Color _kTextoSecundario = Color(0xFF5F6368);

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
                _Disciplinas(onWhatsApp: () => _abrirWhatsApp(context)),
                _HorariosYPrecios(onWhatsApp: () => _abrirWhatsApp(context)),
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
          Positioned(
            right: GingaSpacing.lg,
            bottom: GingaSpacing.lg,
            child: _WhatsAppFab(onTap: () => _abrirWhatsApp(context)),
          ),
        ],
      ),
    );
  }
}

/// Botón flotante de WhatsApp — fijo durante todo el scroll, mismo destino
/// que "Reserva tu clase de prueba gratis".
class _WhatsAppFab extends StatefulWidget {
  final VoidCallback onTap;
  const _WhatsAppFab({required this.onTap});

  @override
  State<_WhatsAppFab> createState() => _WhatsAppFabState();
}

class _WhatsAppFabState extends State<_WhatsAppFab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: _hover ? 1.06 : 1.0,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: GingaColors.brandGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.chat_bubble, color: Colors.white, size: 26),
          ),
        ),
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

/// Botón píldora estándar de todo el sitio público (landing/login/registro):
/// alto FIJO de 40 (no un mínimo — así dos botones en la misma fila nunca
/// se ven de alturas distintas, sin importar el largo del texto), padding
/// horizontal de 20, y el texto nunca se envuelve a una segunda línea. Este
/// es el único lugar donde se define ese estándar — reutilízalo en vez de
/// armar un ElevatedButton suelto para no volver a desalinear alturas.
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
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.full)),
          elevation: 0,
        ),
        icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Altura fija de _TopBar — usada como umbral de scroll para saber cuándo
/// pasar de flotante/transparente a sólido.
const double kTopBarHeight = 130;

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
    final isWide = MediaQuery.of(context).size.width > 760;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: kTopBarHeight,
      color: solid ? Colors.black : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: GingaSpacing.lg, vertical: GingaSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset('assets/images/logofull.png', height: isWide ? 115 : 56),
          _PillButton(
            label: 'Reservar Clase',
            onTap: onWhatsApp,
            background: Colors.white,
            foreground: Colors.black,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  final double height;
  final VoidCallback onWhatsApp;
  const _Hero({required this.height, required this.onWhatsApp});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  late final VideoPlayerController _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/videos/hero_bg.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 760;
    return Container(
      width: double.infinity,
      height: widget.height,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Mientras carga el video se ve el fondo negro del Container de
          // arriba — a propósito, sin poster de foto vieja de por medio.
          if (_videoReady)
            ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            ),
          Container(
            color: Colors.black.withValues(alpha: 0.6),
            padding: EdgeInsets.fromLTRB(
              GingaSpacing.lg,
              isWide ? 72 : 130,
              GingaSpacing.lg,
              isWide ? 72 : 32,
            ),
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
                        fontSize: isWide ? 48 : 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: GingaSpacing.md),
                    Text(
                      'Cusco, Perú. Un espacio de movimiento y comunidad donde entrenas el cuerpo y despiertas algo más.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(fontSize: isWide ? 17 : 14.5, color: Colors.white.withValues(alpha: 0.9), height: 1.5),
                    ),
                    SizedBox(height: isWide ? 48 : 28),
                    Wrap(
                      spacing: GingaSpacing.sm,
                      runSpacing: GingaSpacing.sm,
                      alignment: WrapAlignment.center,
                      children: [
                        _PillButton(
                          label: 'Reserva tu clase de prueba gratis',
                          onTap: widget.onWhatsApp,
                        ),
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
        ],
      ),
    );
  }
}

class _SobreGinga extends StatefulWidget {
  @override
  State<_SobreGinga> createState() => _SobreGingaState();
}

// Escala de grises por luminancia — el mismo efecto "blanco y negro" en
// cualquier foto, sin depender de que el color original ya combine con la
// paleta del sitio.
const List<double> _kGrayscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

class _SobreGingaState extends State<_SobreGinga> with SingleTickerProviderStateMixin {
  late final AnimationController _kenBurnsController;
  late final Animation<double> _kenBurnsScale;

  @override
  void initState() {
    super.initState();
    _kenBurnsController = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat(reverse: true);
    _kenBurnsScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _kenBurnsController.dispose();
    super.dispose();
  }

  Widget _video() {
    return ClipRect(
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kGrayscaleMatrix),
        child: AnimatedBuilder(
          animation: _kenBurnsScale,
          builder: (context, child) => Transform.scale(scale: _kenBurnsScale.value, child: child),
          child: Image.asset('assets/images/roda_artistica.jpg', fit: BoxFit.cover),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 760;
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Todo empieza con la ginga',
            style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.black, height: 1.2)),
        const SizedBox(height: GingaSpacing.md),
        Text(
          'Ginga significa balanceo: el paso base de la capoeira, nunca quieto, siempre listo para moverse. Así nació esta comunidad, y por eso es más grande que una sola disciplina — hoy es capoeira, mañana serán más formas de movimiento, todas con la misma idea: romper tus límites, ganar confianza y encontrar a tu gente.',
          style: GoogleFonts.montserrat(fontSize: 15, color: _kTextoSecundario, height: 1.6),
        ),
      ],
    );

    if (!isWide) {
      // Full-bleed también en mobile — mismo tratamiento que en escritorio,
      // el video toca los bordes y la parte superior sin ningún padding.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 4 / 3, child: _video()),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(GingaSpacing.lg),
            child: texto,
          ),
        ],
      );
    }

    // En escritorio: el video es full-bleed, ocupa la mitad izquierda de
    // punta a punta (sin padding ni bordes) y todo el alto de la sección.
    return SizedBox(
      height: 560,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _video()),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: GingaSpacing.xxl, vertical: GingaSpacing.xl),
              alignment: Alignment.center,
              child: texto,
            ),
          ),
        ],
      ),
    );
  }
}

class _Disciplinas extends StatelessWidget {
  final VoidCallback onWhatsApp;
  const _Disciplinas({required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 760;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          Text('Nuestras disciplinas',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: GingaSpacing.xl),
          isWide
              ? SizedBox(
                  height: 460,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _DisciplinaCard(
                          numero: '01',
                          imagen: 'assets/images/capoeira_playa.jpg',
                          badge: 'Disponible ahora',
                          badgeColor: GingaColors.brandGreen,
                          titulo: 'Capoeira',
                          descripcion: 'La disciplina que le da nombre a todo esto. Niños y adultos, todos los niveles — martes y jueves, con tu primera clase 100% gratis.',
                          onTap: onWhatsApp,
                        ),
                      ),
                      const SizedBox(width: GingaSpacing.xs),
                      Expanded(
                        child: _DisciplinaCard(
                          numero: '02',
                          imagen: 'assets/images/acrobacias.jpg',
                          badge: 'Próximamente',
                          badgeColor: Colors.black,
                          titulo: 'Acrobacias',
                          descripcion: 'La siguiente forma de movimiento que se suma a Ginga. Estamos afinando los últimos detalles — síguenos para enterarte primero.',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Muy pronto más detalles sobre este programa 👀')),
                          ),
                        ),
                      ),
                      const SizedBox(width: GingaSpacing.xs),
                      const SizedBox(width: 220, child: _DisciplinaGhostCard()),
                    ],
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 260,
                      child: _DisciplinaCard(
                        numero: '01',
                        imagen: 'assets/images/capoeira_playa.jpg',
                        badge: 'Disponible ahora',
                        badgeColor: GingaColors.brandGreen,
                        titulo: 'Capoeira',
                        descripcion: 'La disciplina que le da nombre a todo esto. Niños y adultos, todos los niveles — martes y jueves, con tu primera clase 100% gratis.',
                        onTap: onWhatsApp,
                      ),
                    ),
                    const SizedBox(height: GingaSpacing.lg),
                    SizedBox(
                      height: 260,
                      child: _DisciplinaCard(
                        numero: '02',
                        imagen: 'assets/images/acrobacias.jpg',
                        badge: 'Próximamente',
                        badgeColor: Colors.black,
                        titulo: 'Acrobacias',
                        descripcion: 'La siguiente forma de movimiento que se suma a Ginga. Estamos afinando los últimos detalles — síguenos para enterarte primero.',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Muy pronto más detalles sobre este programa 👀')),
                        ),
                      ),
                    ),
                    const SizedBox(height: GingaSpacing.lg),
                    const SizedBox(height: 120, child: _DisciplinaGhostCard()),
                  ],
                ),
        ],
      ),
    );
  }
}

class _DisciplinaCard extends StatefulWidget {
  final String imagen;
  final String badge;
  final Color badgeColor;
  final String titulo;
  final String descripcion;
  final String numero;
  final VoidCallback onTap;
  const _DisciplinaCard({
    required this.imagen,
    required this.badge,
    required this.badgeColor,
    required this.titulo,
    required this.descripcion,
    required this.numero,
    required this.onTap,
  });

  @override
  State<_DisciplinaCard> createState() => _DisciplinaCardState();
}

class _DisciplinaCardState extends State<_DisciplinaCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 250),
                scale: _hover ? 1.08 : 1.0,
                child: Image.asset(
                  widget.imagen,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: GingaColors.brandGreen.withValues(alpha: 0.15),
                    child: const Icon(Icons.sports_martial_arts, color: GingaColors.brandGreen, size: 40),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: _hover ? 0.78 : 0.62),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.65],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: widget.badgeColor, borderRadius: BorderRadius.circular(GingaRadius.full)),
                  child: Text(widget.badge, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Text(widget.numero,
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: GingaColors.brandGreen)),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.titulo, style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(widget.descripcion, style: GoogleFonts.montserrat(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.9), height: 1.5)),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _hover
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Ver más',
                                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
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

/// Tarjeta "fantasma" — sin foto, borde punteado — que deja la lista de
/// disciplinas abierta a propósito, sin inventar fechas ni nombres.
class _DisciplinaGhostCard extends StatelessWidget {
  const _DisciplinaGhostCard();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: Colors.white.withValues(alpha: 0.25)),
      child: Container(
        color: const Color(0xFF161616),
        padding: const EdgeInsets.all(GingaSpacing.lg),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.4), size: 22),
            const SizedBox(height: GingaSpacing.sm),
            Text('Más disciplinas\nen camino',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.5), height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

class _HorariosYPrecios extends StatelessWidget {
  final VoidCallback onWhatsApp;
  const _HorariosYPrecios({required this.onWhatsApp});

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
              style: GoogleFonts.montserrat(fontSize: 14, color: _kTextoSecundario)),
          const SizedBox(height: GingaSpacing.xl),
          Wrap(
            spacing: GingaSpacing.lg,
            runSpacing: GingaSpacing.lg,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              _PlanCard(
                icono: Icons.child_care,
                titulo: 'Capoeira Infantil',
                subtitulo: '5 a 12 años',
                detalle: 'Martes y jueves · 6:00 p.m.',
                precio: 'S/140',
                unidad: '/mes',
                destacado: false,
              ),
              _PlanCard(
                icono: Icons.groups,
                titulo: 'Vienen acompañados',
                subtitulo: '2 personas, 1 mes',
                detalle: 'Cualquiera de los dos grupos',
                precio: 'S/260',
                unidad: 'total',
                destacado: true,
              ),
              _PlanCard(
                icono: Icons.person,
                titulo: 'Jóvenes y Adultos',
                subtitulo: '13 años en adelante',
                detalle: 'Martes y jueves · 7:00 p.m.',
                precio: 'S/140',
                unidad: '/mes',
                destacado: false,
              ),
            ],
          ),
          const SizedBox(height: GingaSpacing.xl),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onWhatsApp,
              child: Text.rich(
                TextSpan(
                  text: '¿Prefieres pagar por adelantado? ',
                  style: GoogleFonts.montserrat(fontSize: 13, color: _kTextoSecundario),
                  children: [
                    TextSpan(
                      text: 'Pregúntanos por promociones de 3 y 6 meses.',
                      style: GoogleFonts.montserrat(
                          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black, decoration: TextDecoration.underline),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _kBeneficiosPlan = [
  'Primera clase 100% gratis',
  'Sin matrícula ni letra chica',
  'Grupo pequeño, trato cercano',
];

class _PlanCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String detalle;
  final String precio;
  final String unidad;
  final bool destacado;
  const _PlanCard({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.detalle,
    required this.precio,
    required this.unidad,
    required this.destacado,
  });

  @override
  Widget build(BuildContext context) {
    final bg = destacado ? Colors.black : Colors.white;
    final fg = destacado ? Colors.white : Colors.black;
    final fgSecundario = destacado ? Colors.white70 : _kTextoSecundario;
    final iconBg = destacado ? GingaColors.brandGreen : GingaColors.brandGreen.withValues(alpha: 0.12);
    final iconFg = destacado ? Colors.white : GingaColors.brandGreen;

    return Container(
      width: 300,
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.all(GingaSpacing.xl),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: destacado ? GingaColors.brandGreen : Colors.black, width: destacado ? 1.2 : 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icono, color: iconFg, size: 22),
              ),
              if (destacado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: GingaColors.brandGreen, borderRadius: BorderRadius.circular(GingaRadius.full)),
                  child: Text('Más elegido',
                      style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: GingaSpacing.md),
          Text(titulo, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          Text(subtitulo, style: GoogleFonts.montserrat(fontSize: 12.5, color: fgSecundario)),
          const SizedBox(height: GingaSpacing.md),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: precio, style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w800, color: fg)),
              TextSpan(text: ' $unidad', style: GoogleFonts.montserrat(fontSize: 13, color: fgSecundario)),
            ]),
          ),
          const SizedBox(height: 4),
          Text(detalle, style: GoogleFonts.montserrat(fontSize: 12.5, color: fgSecundario)),
          const SizedBox(height: GingaSpacing.lg),
          Container(height: 1, color: fgSecundario.withValues(alpha: 0.2)),
          const SizedBox(height: GingaSpacing.md),
          ..._kBeneficiosPlan.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: destacado ? GingaColors.brandGreen : GingaColors.brandGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(b, style: GoogleFonts.montserrat(fontSize: 12.5, color: fgSecundario, height: 1.3)),
                    ),
                  ],
                ),
              )),
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
              _Stat(icono: Icons.history, numero: '11+', texto: 'años formando\ncapoeiristas en Cusco'),
              _Stat(icono: Icons.emoji_people, numero: '0', texto: 'experiencia previa\nnecesaria'),
              _Stat(icono: Icons.card_giftcard, numero: '100%', texto: 'gratis tu primera\nclase, sin compromiso'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icono;
  final String numero;
  final String texto;
  const _Stat({required this.icono, required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: GingaColors.brandGreen, size: 24),
        const SizedBox(height: 8),
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
    const lat = -13.526939550436493;
    const lng = -71.94660952512906;

    final sedeCard = Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 320,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(lat, lng),
                initialZoom: 15.5,
                onTap: (tapPosition, point) async {
                  final googleUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                  if (await canLaunchUrl(googleUrl)) {
                    await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.jumperstudio.ginga_app',
                ),
                const MarkerLayer(markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 40,
                    height: 40,
                    child: Icon(Icons.location_on, color: GingaColors.brandGreen, size: 40),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(GingaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('CUSCO', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w800, color: GingaColors.brandGreen, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text('Urb. Magisterio, Av. de la Cultura E-4',
                    style: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text('3er piso, Edificio Divergym — al costado de la Caja Arequipa',
                    style: GoogleFonts.montserrat(fontSize: 13.5, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dónde entrenamos',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: GingaSpacing.xl),
          sedeCard,
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
      background: _kFondoClaro,
      child: Column(
        children: [
          Text('¿Lista/o para tu primera clase?',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: GingaSpacing.sm),
          Text('Escríbenos y te ayudamos a encontrar el horario ideal para ti.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14, color: _kTextoSecundario)),
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
              Image.asset('assets/images/logofull.png', width: 100),
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
