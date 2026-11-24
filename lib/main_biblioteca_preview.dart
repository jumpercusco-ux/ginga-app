import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/models/cuerdas_fiu.dart';
import 'core/models/curriculum_models.dart';
import 'core/services/curriculum_repository.dart';
import 'core/theme/ginga_theme.dart';
import 'core/theme/theme_manager.dart';
import 'features/biblioteca/biblioteca_screen.dart';
import 'features/biblioteca/curriculo_biblioteca_screen.dart';
import 'features/biblioteca/widgets/biblioteca_user_context.dart';

/// Entrypoint local aislado para PED-03B-V (Validación visual y funcional supervisada).
///
/// NO inicializa Firebase ni realiza lecturas o escrituras contra Firestore de producción.
/// Consume exclusivamente el catálogo local `data/curriculum/fiu_adulto_v1.json`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.instance.init();
  runApp(const BibliotecaPreviewApp());
}

enum PreviewScenario {
  hub('Hub Biblioteca'),
  accumulated('Acumulado 1–6'),
  block56('Bloque 5–6'),
  detailVideo('Ficha con Tutorial');

  final String label;
  const PreviewScenario(this.label);
}

enum _PreviewViewport {
  desktop('Escritorio (Auto)', null),
  tablet('Tablet (834px)', 834.0),
  mobile('Móvil (390px)', 390.0);

  final String label;
  final double? width;
  const _PreviewViewport(this.label, this.width);
}

class _PreviewProfile {
  final String id;
  final String label;
  final BibliotecaUserContext context;

  const _PreviewProfile({
    required this.id,
    required this.label,
    required this.context,
  });
}

const List<_PreviewProfile> _kPreviewProfiles = [
  _PreviewProfile(
    id: 'prof_6',
    label: 'Profesor · 6ª Corda (Laranja e Amarelo)',
    context: BibliotecaUserContext(
      role: 'profesor',
      cordaName: 'Laranja e Amarelo',
      displayName: 'Prof. Marcos (6ª Corda)',
    ),
  ),
  _PreviewProfile(
    id: 'alumno_1',
    label: 'Alumno · 1ª Corda (Crua)',
    context: BibliotecaUserContext(
      role: 'alumno',
      cordaName: 'Crua',
      displayName: 'Alumno Sofía (1ª Corda)',
    ),
  ),
  _PreviewProfile(
    id: 'alumno_2',
    label: 'Alumno · 2ª Corda (Crua e Verde)',
    context: BibliotecaUserContext(
      role: 'alumno',
      cordaName: 'Crua e Verde',
      displayName: 'Alumno Mateo (2ª Corda)',
    ),
  ),
  _PreviewProfile(
    id: 'alumno_6',
    label: 'Alumno · 6ª Corda (Laranja e Amarelo)',
    context: BibliotecaUserContext(
      role: 'alumno',
      cordaName: 'Laranja e Amarelo',
      displayName: 'Alumno Lucía (6ª Corda)',
    ),
  ),
  _PreviewProfile(
    id: 'prof_9',
    label: 'Profesor · 9ª Corda (Azul)',
    context: BibliotecaUserContext(
      role: 'profesor',
      cordaName: 'Azul',
      displayName: 'Prof. André (9ª Corda)',
    ),
  ),
];

class BibliotecaPreviewApp extends StatefulWidget {
  final InMemoryCurriculumDataSource? initialDataSource;
  final PreviewScenario initialScenario;
  final int initialProfileIndex;
  final bool showPreviewToolbar;

  const BibliotecaPreviewApp({
    super.key,
    this.initialDataSource,
    this.initialScenario = PreviewScenario.hub,
    this.initialProfileIndex = 0,
    this.showPreviewToolbar = true,
  });

  @override
  State<BibliotecaPreviewApp> createState() => _BibliotecaPreviewAppState();
}

class _BibliotecaPreviewAppState extends State<BibliotecaPreviewApp> {
  InMemoryCurriculumDataSource? _dataSource;
  CurriculumRepository? _repository;
  String? _loadError;

  late _PreviewProfile _selectedProfile;
  late PreviewScenario _selectedScenario;
  _PreviewViewport _selectedViewport = _PreviewViewport.desktop;
  int _resetCounter = 0;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialProfileIndex.clamp(0, _kPreviewProfiles.length - 1);
    _selectedProfile = _kPreviewProfiles[idx];
    _selectedScenario = widget.initialScenario;
    if (widget.initialDataSource != null) {
      _dataSource = widget.initialDataSource;
      _repository = CurriculumRepository(dataSource: widget.initialDataSource);
    } else {
      _loadLocalCatalog();
    }
  }

  Future<void> _loadLocalCatalog() async {
    try {
      final ds = await InMemoryCurriculumDataSource.fromFlutterAsset(
        assetPath: 'data/curriculum/fiu_adulto_v1.json',
      );
      if (!mounted) return;
      setState(() {
        _dataSource = ds;
        _repository = CurriculumRepository(dataSource: ds);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
      });
    }
  }

  void _selectProfile(_PreviewProfile profile) {
    setState(() {
      _selectedProfile = profile;
      _resetCounter++;
    });
  }

  void _selectScenario(PreviewScenario scenario) {
    setState(() {
      _selectedScenario = scenario;
      _resetCounter++;
    });
  }

  void _showOfflineDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOfflineTutorialesSheet(BuildContext context) async {
    final ds = _dataSource;
    if (ds == null) return;
    final links = await ds.loadTutorialLinks();
    if (!context.mounted) return;
    final userCtx = _selectedProfile.context;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final realCount = links.where((l) => l.hasRealVideo).length;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catálogo de Tutoriales (Modo Local Aislado)',
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${links.length} lecciones preservadas · $realCount con video real · '
                    'Perfil activo: ${userCtx.displayName} (rol: ${userCtx.role})',
                    style: Theme.of(sheetCtx).textTheme.bodySmall,
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: links.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final link = links[index];
                        final locked = userCtx.isTutorialLocked(link.legacyCordaProd);
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            locked
                                ? Icons.lock_outline_rounded
                                : (link.hasRealVideo
                                    ? Icons.play_circle_filled_rounded
                                    : Icons.article_outlined),
                            color: locked
                                ? Colors.grey
                                : (link.hasRealVideo
                                    ? GingaColors.brandGreen
                                    : GingaColors.accentAmber),
                          ),
                          title: Text(
                            link.tituloProd,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${link.categoriaProd} · '
                            '${link.legacyCordaProd.isEmpty ? "Acceso libre" : "Corda: ${link.legacyCordaProd}"} · '
                            '${link.hasRealVideo ? "Video real" : "Sin video aún"}'
                            '${link.movementIds.isNotEmpty ? " · ${link.movementIds.join(", ")}" : ""}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showOfflineGraduacionesSheet(BuildContext context) {
    final userCtx = _selectedProfile.context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sistema de Graduaciones FIU (Modo Local Aislado)',
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu graduación personal: ${userCtx.cordaFIU.index}ª Corda (${userCtx.cordaFIU.nombre}) · '
                    'Rol docente/admin independiente: ${userCtx.role}',
                    style: Theme.of(sheetCtx).textTheme.bodySmall,
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: CuerdasFIU.lista.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final corda = CuerdasFIU.lista[index];
                        final isCurrent = corda.index == userCtx.cordaFIU.index;
                        return ListTile(
                          dense: true,
                          selected: isCurrent,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: corda.colores.first,
                            child: Text(
                              '${corda.index}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: corda.colores.first.computeLuminance() > 0.55
                                    ? Colors.black87
                                    : Colors.white,
                              ),
                            ),
                          ),
                          title: Text(
                            '${corda.index}ª Corda · ${corda.nombre}',
                            style: TextStyle(
                              fontWeight:
                                  isCurrent ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('${corda.rango} · ${corda.simbolismo}'),
                          trailing: isCurrent
                              ? const Chip(
                                  label: Text('Tu corda'),
                                  visualDensity: VisualDensity.compact,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScenarioRoot(BuildContext navContext) {
    final repo = _repository!;
    final userCtx = _selectedProfile.context;

    void openPizarraDialog() => _showOfflineDialog(
          navContext,
          title: 'Pizarra de Ideas (Fuera de alcance PED-03B-V)',
          message:
              'La integración del planificador de clases IA con la Biblioteca Curricular corresponde a PED-04.',
        );

    void openManageTutorialsDialog() => _showOfflineDialog(
          navContext,
          title: 'Mis Tutoriales (Vista previa local)',
          message:
              'Acceso docente visible porque rol = "${userCtx.role}" (independiente de la corda "${userCtx.cordaName}"). '
              'La edición remota de tutoriales está deshabilitada en este preview aislado sin Firestore.',
        );

    switch (_selectedScenario) {
      case PreviewScenario.hub:
        return BibliotecaScreen(
          repository: repo,
          overrideUserContext: userCtx,
          onOpenManageTutorials: openManageTutorialsDialog,
          onOpenPizarra: openPizarraDialog,
          onOpenTutoriales: () => _showOfflineTutorialesSheet(navContext),
          onOpenGraduaciones: () => _showOfflineGraduacionesSheet(navContext),
        );
      case PreviewScenario.accumulated:
        return CurriculoBibliotecaScreen(
          repository: repo,
          overrideUserContext: userCtx,
          initialTrack: CurriculumTrack.adulto,
          initialCordaIndex:
              userCtx.adultCordaIndex > 6 ? 6 : userCtx.adultCordaIndex,
          initialCumulativeMode: true,
          onOpenManageTutorials: openManageTutorialsDialog,
          onOpenPizarra: openPizarraDialog,
        );
      case PreviewScenario.block56:
        return CurriculoBibliotecaScreen(
          repository: repo,
          overrideUserContext: userCtx,
          initialTrack: CurriculumTrack.adulto,
          initialCordaIndex: 6,
          initialCumulativeMode: false,
          onOpenManageTutorials: openManageTutorialsDialog,
          onOpenPizarra: openPizarraDialog,
        );
      case PreviewScenario.detailVideo:
        return CurriculoBibliotecaScreen(
          repository: repo,
          overrideUserContext: userCtx,
          initialTrack: CurriculumTrack.adulto,
          initialCordaIndex: 1,
          initialCumulativeMode: false,
          initialMovementId: 'cocorinha',
          onOpenManageTutorials: openManageTutorialsDialog,
          onOpenPizarra: openPizarraDialog,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager.instance,
      builder: (context, _) {
        final currentThemeMode = ThemeManager.instance.themeMode;
        return MaterialApp(
          title: 'GINGA Biblioteca Preview (Aislado)',
          debugShowCheckedModeBanner: false,
          theme: gingaLightTheme,
          darkTheme: gingaDarkTheme,
          themeMode: currentThemeMode,
          home: Builder(
            builder: (outerContext) {
              final isDark =
                  Theme.of(outerContext).brightness == Brightness.dark;
              return Scaffold(
                body: Column(
                  children: [
                    if (widget.showPreviewToolbar)
                      _PreviewToolbar(
                        selectedProfile: _selectedProfile,
                        selectedScenario: _selectedScenario,
                        selectedViewport: _selectedViewport,
                        isDark: isDark,
                        onSelectProfile: _selectProfile,
                        onSelectScenario: _selectScenario,
                        onSelectViewport: (vp) =>
                            setState(() => _selectedViewport = vp),
                        onToggleTheme: () => ThemeManager.instance.setThemeMode(
                          isDark ? ThemeMode.light : ThemeMode.dark,
                        ),
                      ),
                    Expanded(
                      child: _loadError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Error cargando catálogo local:\n$_loadError',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : _repository == null
                              ? const Center(child: CircularProgressIndicator())
                              : _ViewportFrame(
                                  width: _selectedViewport.width,
                                  child: Navigator(
                                    key: ValueKey(
                                      '${_selectedProfile.id}_${_selectedScenario.name}_$_resetCounter',
                                    ),
                                    onGenerateRoute: (_) =>
                                        MaterialPageRoute<void>(
                                      builder: (navCtx) =>
                                          _buildScenarioRoot(navCtx),
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  final _PreviewProfile selectedProfile;
  final PreviewScenario selectedScenario;
  final _PreviewViewport selectedViewport;
  final bool isDark;
  final ValueChanged<_PreviewProfile> onSelectProfile;
  final ValueChanged<PreviewScenario> onSelectScenario;
  final ValueChanged<_PreviewViewport> onSelectViewport;
  final VoidCallback onToggleTheme;

  const _PreviewToolbar({
    required this.selectedProfile,
    required this.selectedScenario,
    required this.selectedViewport,
    required this.isDark,
    required this.onSelectProfile,
    required this.onSelectScenario,
    required this.onSelectViewport,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF132219),
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F6E43),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'PED-03B-V · PREVIEW LOCAL AISLADO · SIN FIRESTORE',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fuente: data/curriculum/fiu_adulto_v1.json · '
                      'Rol: ${selectedProfile.context.role} · '
                      'Corda personal: ${selectedProfile.context.cordaFIU.index}ª (${selectedProfile.context.cordaFIU.nombre})',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onToggleTheme,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: isDark
                          ? const Color(0xFFFFE082)
                          : const Color(0xFFD9F3E1),
                      size: 16,
                    ),
                    label: Text(
                      isDark ? 'Oscuro' : 'Claro',
                      style: GoogleFonts.montserrat(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Perfil:',
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D3326),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_PreviewProfile>(
                        value: selectedProfile,
                        dropdownColor: const Color(0xFF1C3023),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        isDense: true,
                        items: _kPreviewProfiles
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.label,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (p) {
                          if (p != null) onSelectProfile(p);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Escenario:',
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final scenario in PreviewScenario.values)
                    _ToolbarPill(
                      label: scenario.label,
                      selected: scenario == selectedScenario,
                      selectedBg: const Color(0xFFD9F3E1),
                      selectedFg: const Color(0xFF0E2A19),
                      onTap: () => onSelectScenario(scenario),
                    ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Vista:',
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ToolbarPill(
                        label: _PreviewViewport.desktop.label,
                        selected:
                            _PreviewViewport.desktop == selectedViewport,
                        selectedBg: const Color(0xFFFFE082),
                        selectedFg: Colors.black87,
                        onTap: () =>
                            onSelectViewport(_PreviewViewport.desktop),
                      ),
                    ],
                  ),
                  for (final vp
                      in _PreviewViewport.values.skip(1))
                    _ToolbarPill(
                      label: vp.label,
                      selected: vp == selectedViewport,
                      selectedBg: const Color(0xFFFFE082),
                      selectedFg: Colors.black87,
                      onTap: () => onSelectViewport(vp),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedBg;
  final Color selectedFg;
  final VoidCallback onTap;

  const _ToolbarPill({
    required this.label,
    required this.selected,
    required this.selectedBg,
    required this.selectedFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedBg : const Color(0xFF1D3326),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? selectedBg : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 14, color: selectedFg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? selectedFg : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewportFrame extends StatelessWidget {
  final double? width;
  final Widget child;

  const _ViewportFrame({
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (width == null) return child;

    return Container(
      color: const Color(0xFF1F2421),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final targetW = width!.clamp(320.0, constraints.maxWidth);
          final baseMq = MediaQuery.of(ctx);
          return Container(
            width: targetW,
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: MediaQuery(
              data: baseMq.copyWith(
                size: Size(targetW, constraints.maxHeight),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
