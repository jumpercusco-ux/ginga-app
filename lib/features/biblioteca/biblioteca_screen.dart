import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/cuerdas_fiu.dart';
import '../../core/models/curriculum_models.dart';
import '../../core/services/curriculum_repository.dart';
import '../../core/theme/ginga_theme.dart';
import 'cultura_screen.dart';
import 'curriculo_biblioteca_screen.dart';
import 'glosario_screen.dart';
import 'graduaciones_screen.dart';
import 'musica_screen.dart';
import 'tutoriales_screen.dart';
import 'widgets/biblioteca_user_context.dart';

class BibliotecaScreen extends StatelessWidget {
  final CurriculumRepository? repository;
  final BibliotecaUserContext? overrideUserContext;
  final VoidCallback? onOpenManageTutorials;
  final VoidCallback? onOpenPizarra;
  final VoidCallback? onOpenTutoriales;
  final VoidCallback? onOpenGraduaciones;

  const BibliotecaScreen({
    super.key,
    this.repository,
    this.overrideUserContext,
    this.onOpenManageTutorials,
    this.onOpenPizarra,
    this.onOpenTutoriales,
    this.onOpenGraduaciones,
  });

  void _openCurriculo(
    BuildContext context,
    BibliotecaUserContext userContext, {
    int? cordaIndex,
    bool cumulativeMode = false,
  }) {
    final targetIndex =
        (cordaIndex ?? userContext.adultCordaIndex).clamp(1, 6);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CurriculoBibliotecaScreen(
          repository: repository,
          overrideUserContext: overrideUserContext ?? userContext,
          initialTrack: CurriculumTrack.adulto,
          initialCordaIndex: targetIndex,
          initialCumulativeMode: cumulativeMode,
          onOpenManageTutorials: onOpenManageTutorials,
          onOpenPizarra: onOpenPizarra,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? GingaColors.backgroundDark : const Color(0xFFFFFFFF);
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);
    final textPrimary = isDark ? GingaColors.textWhite : const Color(0xFF111814);
    final textSecondary =
        isDark ? GingaColors.textMuted : const Color(0xFF5F6368);
    final accentGreen =
        isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;

    return BibliotecaUserContextProvider(
      overrideContext: overrideUserContext,
      builder: (context, userContext) {
        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final int gridCols = width >= 1080
                    ? 3
                    : (width >= 680 ? 2 : 1);

                final sections = <Widget>[
                  _SeccionCard(
                    titulo: 'Música',
                    subtitulo: 'Toques de berimbau y cantigas tradicionales',
                    icono: Icons.music_note,
                    tag: 'RITMO',
                    tagColor: accentGreen,
                    color: accentGreen,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MusicaScreen()),
                    ),
                  ),
                  _SeccionCard(
                    titulo: 'Tutoriales',
                    subtitulo:
                        'Micro-lecciones de técnica para practicar en casa',
                    icono: Icons.play_circle_outline,
                    tag: '21 LECCIONES',
                    tagColor: GingaColors.accentAmber,
                    color: GingaColors.accentAmber,
                    onTap: onOpenTutoriales ??
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TutorialesScreen(),
                              ),
                            ),
                  ),
                  _SeccionCard(
                    titulo: 'Cultura',
                    subtitulo:
                        'Historia de la capoeira y enciclopedia de mestres',
                    icono: Icons.menu_book_outlined,
                    tag: 'CULTURA',
                    tagColor: textSecondary,
                    color: textSecondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CulturaScreen()),
                    ),
                  ),
                  _SeccionCard(
                    titulo: 'Glosario de Capoeira',
                    subtitulo:
                        'Diccionario oficial y términos clave del grupo FIU',
                    icono: Icons.translate_rounded,
                    tag: 'GLOSARIO',
                    tagColor: GingaColors.accentAmber,
                    color: GingaColors.accentAmber,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GlosarioScreen()),
                    ),
                  ),
                  _SeccionCard(
                    titulo: 'Sistema de Graduaciones',
                    subtitulo:
                        'Camino oficial de cuerdas de FIU y tu rango actual',
                    icono: Icons.military_tech_rounded,
                    tag: 'CUERDAS',
                    tagColor:
                        isDark ? Colors.lightBlue.shade300 : Colors.blue,
                    color: isDark ? Colors.lightBlue.shade300 : Colors.blue,
                    onTap: onOpenGraduaciones ??
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GraduacionesScreen(),
                              ),
                            ),
                  ),
                  _SeccionCard(
                    titulo: 'Nuestros Mestres',
                    subtitulo:
                        'Conoce a los líderes y fundadores de la Família Irmãos Unidos',
                    icono: Icons.diversity_3_rounded,
                    tag: 'LINAJE',
                    tagColor: isDark
                        ? Colors.deepPurple.shade200
                        : Colors.deepPurple,
                    color: isDark
                        ? Colors.deepPurple.shade200
                        : Colors.deepPurple,
                    onTap: () => context.push('/nuestros-mestres'),
                  ),
                ];

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // ── Header ──────────────────────────────
                          Row(
                            children: [
                              if (Navigator.of(context).canPop())
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 18,
                                      color: textPrimary,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'A Biblioteca',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Currículo oficial FIU, técnica, música y cultura en un solo lugar',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // ── Centro Curricular Oficial FIU (Unificado Alumno + Profesor) ──
                          _CurriculumHubCard(
                            userContext: userContext,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            onExploreCurrentCorda: () => _openCurriculo(
                              context,
                              userContext,
                              cumulativeMode: false,
                            ),
                            onExploreAccumulated: () => _openCurriculo(
                              context,
                              userContext,
                              cumulativeMode: true,
                            ),
                            onSelectCorda: (idx) => _openCurriculo(
                              context,
                              userContext,
                              cordaIndex: idx,
                              cumulativeMode: false,
                            ),
                            onManageTutorials: userContext.isTeacher
                                ? (onOpenManageTutorials ??
                                    () {
                                      if (Firebase.apps.isNotEmpty) {
                                        context.push('/instructor-tutoriales');
                                      }
                                    })
                                : null,
                            onOpenPizarra: userContext.isTeacher
                                ? (onOpenPizarra ??
                                    () {
                                      if (Firebase.apps.isNotEmpty) {
                                        context.push('/instructor-pizarra');
                                      }
                                    })
                                : null,
                          ),

                          const SizedBox(height: 22),

                          Text(
                            'Módulos de estudio y práctica',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (gridCols == 1)
                            Column(
                              children: sections
                                  .map(
                                    (card) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: card,
                                    ),
                                  )
                                  .toList(),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridCols,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                mainAxisExtent: 108,
                              ),
                              itemCount: sections.length,
                              itemBuilder: (_, index) => sections[index],
                            ),

                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _CurriculumHubCard extends StatelessWidget {
  final BibliotecaUserContext userContext;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback onExploreCurrentCorda;
  final VoidCallback onExploreAccumulated;
  final ValueChanged<int> onSelectCorda;
  final VoidCallback? onManageTutorials;
  final VoidCallback? onOpenPizarra;

  const _CurriculumHubCard({
    required this.userContext,
    required this.cardBg,
    required this.borderColor,
    required this.onExploreCurrentCorda,
    required this.onExploreAccumulated,
    required this.onSelectCorda,
    this.onManageTutorials,
    this.onOpenPizarra,
  });

  @override
  Widget build(BuildContext context) {
    final userCorda = userContext.cordaFIU;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentGreen =
        isDark ? const Color(0xFF66BB6A) : GingaColors.brandGreen;
    final textPrimary = isDark ? GingaColors.textWhite : const Color(0xFF111814);
    final textSecondary =
        isDark ? GingaColors.textMuted : const Color(0xFF5F6368);
    final chipBg =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F6F4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(
          color: accentGreen.withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: GingaColors.brandGreen.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentGreen.withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: accentGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currículo Oficial FIU',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${userContext.roleLabel} · Graduación actual: Corda ${userCorda.nombre}',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CordaRibbonBar(corda: userCorda, height: 10),
          if (userContext.isBeyondDigitizedV1) ...[
            const SizedBox(height: 8),
            Text(
              'Tu graduación (${userCorda.nombre}) supera el bloque 1–6 actualmente digitalizado; puedes explorar tu repertorio acumulado de base (Cordas 1 a 6).',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: onExploreCurrentCorda,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GingaColors.brandGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                  textStyle: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.explore_rounded, size: 17),
                label: Text(
                  userContext.isBeyondDigitizedV1
                      ? 'Explorar Currículo FIU'
                      : 'Mi Corda (${userCorda.nombre})',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onExploreAccumulated,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentGreen,
                  side: BorderSide(color: accentGreen, width: 1.4),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                  textStyle: GoogleFonts.montserrat(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.layers_outlined, size: 17),
                label: Text(
                  'Repertorio acumulado (1–${userContext.adultCordaIndex.clamp(1, 6)})',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Acceso rápido por graduación (Adulto 1–6):',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: CuerdasFIU.lista.take(6).map((c) {
              final isMine = c.index == userCorda.index;
              return ActionChip(
                backgroundColor: chipBg,
                side: BorderSide(
                  color: isMine ? accentGreen : borderColor,
                ),
                avatar: SizedBox(
                  width: 16,
                  child: CordaRibbonBar(corda: c, height: 6),
                ),
                label: Text(
                  '${c.index}. ${c.nombre}',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: isMine ? FontWeight.w800 : FontWeight.w600,
                    color: isMine ? accentGreen : textPrimary,
                  ),
                ),
                onPressed: () => onSelectCorda(c.index),
              );
            }).toList(),
          ),
          if (userContext.isTeacher) ...[
            const SizedBox(height: 14),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Gestión docente:',
                  style: GoogleFonts.montserrat(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                if (onManageTutorials != null)
                  TextButton.icon(
                    onPressed: onManageTutorials,
                    style: TextButton.styleFrom(
                      foregroundColor: accentGreen,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      textStyle: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.video_settings_outlined, size: 16),
                    label: const Text('Gestionar Tutoriales'),
                  ),
                if (onOpenPizarra != null)
                  TextButton.icon(
                    onPressed: onOpenPizarra,
                    style: TextButton.styleFrom(
                      foregroundColor: accentGreen,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      textStyle: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 17),
                    label: const Text('Pizarra y Planificador'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SECCIÓN CARD
// ─────────────────────────────────────────

class _SeccionCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final String tag;
  final Color tagColor;
  final Color color;
  final VoidCallback onTap;

  const _SeccionCard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.tag,
    required this.tagColor,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE0E0E0);
    final textPrimary = isDark ? GingaColors.textWhite : const Color(0xFF111814);
    final textSecondary =
        isDark ? GingaColors.textMuted : const Color(0xFF5F6368);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(GingaRadius.md),
              ),
              child: Icon(icono, color: color, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titulo,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: tagColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
