import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class CulturaScreen extends StatefulWidget {
  const CulturaScreen({super.key});

  @override
  State<CulturaScreen> createState() => _CulturaScreenState();
}

class _CulturaScreenState extends State<CulturaScreen> {
  final List<HistoriaArticulo> _articulos = [
    HistoriaArticulo(
      titulo: 'Orígenes',
      subtitulo: 'El nacimiento de un arte prohibido',
      icono: Icons.shield_outlined,
      color: GingaColors.brandGreen,
      tag: 'HISTORIA',
      contenido: 'La capoeira nació en el siglo XVI como un mecanismo de supervivencia y liberación de los esclavos africanos traídos al Brasil. Para camuflar su letal entrenamiento de combate de los capataces de las plantaciones, los capoeiristas le añadieron danza, música e instrumentos como el berimbau.\n\nDurante casi cuatro siglos fue prohibida y perseguida en Brasil, castigada con trabajos forzados en las calles, hasta que en 1937 fue legalizada y declarada patrimonio cultural nacional gracias al incansable trabajo del Mestre Bimba, quien la introdujo en los círculos deportivos e intelectuales.',
    ),
    HistoriaArticulo(
      titulo: 'Estilos',
      subtitulo: 'Dos filosofías de juego, una misma raíz',
      icono: Icons.compare_arrows_rounded,
      color: GingaColors.accentAmber,
      tag: 'FILOSOFÍA',
      contenido: 'Existen dos estilos tradicionales principales en la Capoeira:\n\n• Capoeira Angola: Preservada por Mestre Pastinha, es el estilo tradicional, táctico, más cercano al suelo y cargado de astucia (mandinga). El juego es teatral, ritualizado y lento, pero altamente impredecible.\n\n• Capoeira Regional: Creada por Mestre Bimba, es un estilo moderno, rápido y acrobático. Bimba incorporó técnicas de lucha y sistematizó la enseñanza con una metodología rigurosa para dotar a la capoeira de un carácter más deportivo y defensivo.',
    ),
    HistoriaArticulo(
      titulo: 'Fundamentos',
      subtitulo: 'Reglas, respeto y el ritual del juego',
      icono: Icons.hub_outlined,
      color: Colors.purple,
      tag: 'ETIQUETA',
      contenido: 'La Roda es el círculo sagrado donde ocurre la capoeira. Está gobernada por los instrumentos colocados en la cabecera (gunga, médio, viola, atabaque y pandero). Ningún jugador entra a la roda sin pedir permiso o "comprar el juego" en el pie del berimbau gunga.\n\nEl respeto mutuo, la picardía y la sincronización con el canto del solista son fundamentales. Nunca des la espalda a tu oponente, mantén siempre el contacto visual y mantente en movimiento constante con la ginga tradicional.',
    ),
    HistoriaArticulo(
      titulo: 'Familia',
      subtitulo: 'Historia del grupo y mestres de FIU',
      icono: Icons.groups_outlined,
      color: Colors.orange.shade800,
      tag: 'GRUPO',
      imagenPath: 'assets/images/fiu_banner.png',
      logoPath: 'assets/images/fiu_logo.jpg',
      contenido: 'Família Irmãos Unidos, conocido como FIU, es un grupo internacional de capoeira fundado en São Paulo, Brasil, por Mestre Natal (Natalino Dias da Cruz) alrededor de 1980. Nacido dentro del contexto de crecimiento y expansión de la capoeira contemporánea en Brasil, FIU surgió con la propuesta de fortalecer no solo el aspect físico de la capoeira, sino también sus valores culturales, musicales y humanos.\n\nMestre Natal dedicó su vida a enseñar la capoeira como una herramienta de disciplina, unión y transformación social, formando generaciones de alumnos dentro y fuera de Brasil. Con el tiempo, el grupo comenzó a expandirse internacionalmente, llevando la tradición de la capoeira brasileña a distintos países de América y Europa.\n\nTras la muerte de Mestre Natal en 2002, el legado del grupo continuó bajo la dirección de sus hijos: Mestre Sidney, Contra-Mestra Natália y Contra-Mestre Arthur FIU, quienes asumieron la misión de preservar la esencia enseñada por su padre mientras impulsaban el crecimiento internacional de la organización.\n\nActualmente, FIU mantiene academias, eventos y encuentros culturales en diversos países, promoviendo la capoeira como una expresión de resistencia cultural afrobrasileña que integra lucha, música, danza, tradición y comunidad. El grupo destaca por su énfasis en la formación humana, el respeto dentro de la roda y la preservación de las raíces culturales de la capoeira.',
    ),
  ];

  void _mostrarDetalleHistoria(BuildContext context, HistoriaArticulo articulo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.88,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(GingaRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Scaffold(
              backgroundColor: cardBg,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (articulo.imagenPath != null)
                    Image.asset(
                      articulo.imagenPath!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    color: articulo.color.withOpacity(0.08),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        articulo.logoPath != null
                            ? Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  border: Border.all(color: borderColor),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  child: Image.asset(articulo.logoPath!, fit: BoxFit.cover),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: articulo.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                ),
                                child: Icon(articulo.icono, color: articulo.color, size: 28),
                              ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: articulo.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  articulo.tag,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: articulo.color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                articulo.titulo,
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: GingaColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            articulo.subtitulo,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            articulo.contenido,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: GingaColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Entendido',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Barra Superior Personalizada (App Bar) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new, size: 18, color: GingaColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Cultura Capoeira',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historia y Mestres',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Descubre los orígenes, fundamentos y filosofía de la capoeira',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: GingaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _articulos.length,
                itemBuilder: (context, index) {
                  final articulo = _articulos[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.015),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _mostrarDetalleHistoria(context, articulo),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              articulo.logoPath != null
                                  ? Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(GingaRadius.md),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(GingaRadius.md),
                                        child: Image.asset(articulo.logoPath!, fit: BoxFit.cover),
                                      ),
                                    )
                                  : Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: articulo.color.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(GingaRadius.md),
                                      ),
                                      child: Icon(articulo.icono, color: articulo.color, size: 26),
                                    ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            articulo.titulo,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: GingaColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: articulo.color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            articulo.tag,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              color: articulo.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      articulo.subtitulo,
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: GingaColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GingaColors.textSecondary,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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

class HistoriaArticulo {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final String tag;
  final String contenido;
  final String? imagenPath;
  final String? logoPath;

  HistoriaArticulo({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.tag,
    required this.contenido,
    this.imagenPath,
    this.logoPath,
  });
}
