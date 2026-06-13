import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';

class NuestrosMestresScreen extends StatelessWidget {
  const NuestrosMestresScreen({super.key});

  void _verFotoAmpliada(BuildContext context, MestreProfile mestre) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar Foto',
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Visor con zoom táctil y doble toque
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: 'avatar_zoom_${mestre.nombre}',
                  child: Image.asset(
                    mestre.fotoPath,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              // Botón de Cerrar Flotante
              Positioned(
                top: 40 + MediaQuery.of(context).padding.top,
                right: 20,
                child: Material(
                  color: Colors.white24,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              // Nombre flotante inferior
              Positioned(
                bottom: 40 + MediaQuery.of(context).padding.bottom,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mestre.nombre,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDetalleMestre(BuildContext context, MestreProfile mestre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de arrastre superior
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GingaColors.borderLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Cabecera: Foto + Nombres
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _verFotoAmpliada(context, mestre),
                    child: Tooltip(
                      message: 'Ver foto completa',
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: GingaColors.borderLight,
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: AssetImage(mestre.fotoPath),
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: mestre.color.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mestre.nombre,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: mestre.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            mestre.cargo.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: mestre.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cita / Lema si lo tiene
              if (mestre.cita.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: mestre.color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    border: Border.all(color: mestre.color.withOpacity(0.15), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, color: mestre.color, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mestre.cita,
                          style: GoogleFonts.nunito(
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            color: GingaColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Biografía Scrollable
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biografía y Trayectoria',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mestre.biografia,
                        style: GoogleFonts.nunito(
                          fontSize: 14.5,
                          color: GingaColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botón Cerrar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GingaColors.brandGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cerrar',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<MestreProfile> directiva = [
      MestreProfile(
        nombre: 'Mestre Sidney',
        cargo: 'Presidente y Líder General',
        inicial: 'S',
        color: Colors.indigo.shade800,
        cita: '"O discípulo não é superior ao mestre; mas todo discípulo perfeito será como o seu mestre."',
        biografia: 'Sidney Santos Dias da Cruz, conocido como Mestre Sidney, es el hijo mayor de Mestre Natal y el líder actual de la Escuela de Capoeira FIU. Discípulo directo de su padre, se formó en la Av. Parapuã, São Paulo. Tras el fallecimiento del fundador en 2002, asumió la presidencia y el liderazgo general para mantener el legado.\n\nEn 2010 redactó y actualizó el Manual Oficial de Entrenamiento de la Escuela FIU, estructurando pedagógicamente la enseñanza de golpes, secuencias y toques de berimbau. Dirige la Unidad Matriz en São Paulo y supervisa la formación y graduación de todos los supervisores del grupo a nivel internacional.',
        fotoPath: 'assets/images/mestre_sidney.png',
      ),
      MestreProfile(
        nombre: 'Mestre Arthur',
        cargo: 'Co-Director de FIU',
        inicial: 'A',
        color: GingaColors.brandGreen,
        cita: '"Preservar la esencia del berimbau es honrar el sonido que nos dejó nuestro maestro."',
        biografia: 'Arthur Santos Dias da Cruz es miembro de la Presidencia de FIU y co-director general de la escuela. Hijo de Mestre Natal, creció inmerso en los entrenamientos tradicionales en Brasilândia. En 2007, asumió la responsabilidad de impartir las clases junto a su hermano Mestre Sidney.\n\nArthur ha sido pieza clave para el crecimiento y expansión de las filiales de la escuela. Bajo su supervisión, FIU ha establecido academias formales y filiales activas en México (Puerto Vallarta, Guadalajara), Colombia (Bogotá, Soacha) y Chile (Mostazal), llevando la capoeira contemporánea a nuevos horizontes.',
        fotoPath: 'assets/images/mestre_arthur.png',
      ),
      MestreProfile(
        nombre: 'Contramestra Natália',
        cargo: 'Co-Directora de FIU',
        inicial: 'N',
        color: Colors.orange.shade800,
        cita: '"La capoeira es una herramienta de unión, respeto y profunda resistencia cultural."',
        biografia: 'Natália Santos Dias da Cruz es miembro fundador de la Presidencia de la Escuela FIU e hija de Mestre Natal. Su labor está dedicada a la preservación del aspecto humano, ético y musical del grupo.\n\nSupervisa la integración de rituales tradicionales y vela por la enseñanza ética dentro de la roda, promoviendo la capoeira no solo como un arte marcial o deporte físico, sino como un camino para la disciplina, el respeto mutuo y la transformación social.',
        fotoPath: 'assets/images/contramestra_natalia.png',
      ),
    ];

    final MestreProfile fundador = MestreProfile(
      nombre: 'Mestre Natal',
      cargo: 'Fundador Histórico (FIU)',
      inicial: 'N',
      color: Colors.amber.shade800,
      cita: '"Não precisa apagar a luz do próximo para que a nossa brilhe. Seja um ser iluminado."',
      biografia: 'Natalino Dias da Cruz, conocido mundialmente como Mestre Natal, nació el 25 de diciembre de 1960 en São Paulo, Brasil. Se inició en la capoeira en Carapicuíba y se formó como Professor el 1 de mayo de 1980 bajo Mestre Grande.\n\nEl 12 de junio de 1980 fundó la "Associação de Capoeira Família Irmãos Unidos - FIU" con el firme propósito de fortalecer los valores humanos, culturales y de resistencia. El 16 de diciembre de 2000 fue consagrado con el 4º Grado de Mestre (Cordoão Branco), su última graduación. Mestre Natal falleció en diciembre de 2002, dejando una escuela consolidada que hoy en día enseña su técnica y filosofía en diversos países de América y Europa.',
      fotoPath: 'assets/images/mestre_natal.png',
    );

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Linaje FIU',
          style: GoogleFonts.montserrat(
            color: GingaColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: GingaColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Introducción
              Text(
                'Nuestros Mestres',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: GingaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'El linaje y liderazgo de la Família Irmãos Unidos do Mestre Natal',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: GingaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // 👑 Homenaje al Fundador
              _buildSubheader('Fundador del Grupo'),
              const SizedBox(height: 10),
              _buildFundadorCard(context, fundador),

              const SizedBox(height: 28),

              // 👥 Presidencia Actual
              _buildSubheader('Presidencia y Líderes Actuales'),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: directiva.length,
                itemBuilder: (context, index) {
                  final mestre = directiva[index];
                  return _buildMestreItem(context, mestre);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubheader(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: GingaColors.brandGreen,
      ),
    );
  }

  Widget _buildFundadorCard(BuildContext context, MestreProfile mestre) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade100.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDetalleMestre(context, mestre),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Foto fundador (ampliable al tocarse)
                GestureDetector(
                  onTap: () => _verFotoAmpliada(context, mestre),
                  child: Tooltip(
                    message: 'Ver foto',
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: GingaColors.borderLight,
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage(mestre.fotoPath),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                        border: Border.all(color: Colors.amber.shade400, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mestre.nombre,
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: GingaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade300, width: 0.5),
                            ),
                            child: Text(
                              'FUNDADOR',
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mestre.cargo,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: GingaColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Toca para ver biografía y legado histórico.',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: GingaColors.brandGreen,
                          fontWeight: FontWeight.w700,
                        ),
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
  }

  Widget _buildMestreItem(BuildContext context, MestreProfile mestre) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDetalleMestre(context, mestre),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Foto Mestre (ampliable al tocarse)
                GestureDetector(
                  onTap: () => _verFotoAmpliada(context, mestre),
                  child: Tooltip(
                    message: 'Ver foto',
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: GingaColors.borderLight,
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage(mestre.fotoPath),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mestre.nombre,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mestre.cargo,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: GingaColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
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
  }
}

class MestreProfile {
  final String nombre;
  final String cargo;
  final String inicial;
  final Color color;
  final String cita;
  final String biografia;
  final String fotoPath;

  MestreProfile({
    required this.nombre,
    required this.cargo,
    required this.inicial,
    required this.color,
    required this.cita,
    required this.biografia,
    required this.fotoPath,
  });
}
