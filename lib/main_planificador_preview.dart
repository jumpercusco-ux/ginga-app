import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/curriculum_repository.dart';
import 'core/theme/ginga_theme.dart';
import 'core/theme/theme_manager.dart';
import 'features/biblioteca/curriculo_biblioteca_screen.dart';
import 'features/biblioteca/widgets/biblioteca_user_context.dart';
import 'features/instructor/instructor_pizarra_screen.dart';
import 'features/instructor/planificador/models/class_plan_models.dart';
import 'features/instructor/planificador/services/planner_data_source.dart';
import 'features/instructor/planificador/services/planner_v2_engine_client.dart';

/// Entrypoint local aislado para PED-04B1 (Planificador Pedagógico GINGA V2).
///
/// NO inicializa Firebase, NO llama a OpenAI y NO escribe en producción.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.instance.init();
  runApp(const PlanificadorPreviewApp());
}

enum PlannerPreviewScenario {
  hubPlans('Hub · Mis Planes'),
  hubResources('Hub · Pizarra'),
  hubHistory('Hub · Historial'),
  infantilMj18('Infantil M/J 18:00'),
  adultosMj19('Adultos M/J 19:00'),
  quickCreate('Creación Rápida'),
  advancedCreate('Creación Avanzada'),
  editorV2('Editor · Clase V2'),
  copilotInfantil8of8('Copiloto · Infantil 8/8'),
  editorManual('Editor · Desde cero'),
  liveClass('En Vivo · Clase V2');

  final String label;
  const PlannerPreviewScenario(this.label);
}

enum _PreviewViewport {
  desktop('Escritorio', null),
  tablet('Tablet (834)', 834.0),
  mobile('Móvil (390)', 390.0);

  final String label;
  final double? width;
  const _PreviewViewport(this.label, this.width);
}

class PlanificadorPreviewApp extends StatefulWidget {
  final InMemoryPlannerDataSource? initialDataSource;
  final InMemoryCurriculumDataSource? initialCurriculumDataSource;
  final PlannerPreviewScenario initialScenario;
  final bool showPreviewToolbar;

  const PlanificadorPreviewApp({
    super.key,
    this.initialDataSource,
    this.initialCurriculumDataSource,
    this.initialScenario = PlannerPreviewScenario.hubPlans,
    this.showPreviewToolbar = true,
  });

  @override
  State<PlanificadorPreviewApp> createState() => _PlanificadorPreviewAppState();
}

class _PlanificadorPreviewAppState extends State<PlanificadorPreviewApp> {
  late InMemoryPlannerDataSource _plannerDataSource;
  CurriculumRepository? _curriculumRepository;
  String? _loadError;
  late PlannerPreviewScenario _scenario;
  _PreviewViewport _viewport = _PreviewViewport.desktop;
  int _resetNonce = 0;
  PlannerV2EngineStatus? _engineStatus;

  @override
  void initState() {
    super.initState();
    _plannerDataSource = widget.initialDataSource ??
        InMemoryPlannerDataSource.copilotDemoFixtures();
    _scenario = widget.initialScenario;
    if (widget.initialCurriculumDataSource != null) {
      _curriculumRepository =
          CurriculumRepository(dataSource: widget.initialCurriculumDataSource);
    } else {
      _loadLocalCurriculum();
    }
    _fetchEngineStatus();
  }

  Future<void> _fetchEngineStatus() async {
    final token = Uri.base.queryParameters['token'];
    final status =
        await HttpLocalPlannerV2Client(previewToken: token).fetchHealthStatus();
    if (!mounted || status == null) return;
    setState(() => _engineStatus = status);
  }

  Future<void> _loadLocalCurriculum() async {
    try {
      final ds = await InMemoryCurriculumDataSource.fromFlutterAsset(
        assetPath: 'data/curriculum/fiu_adulto_v1.json',
      );
      if (!mounted) return;
      setState(() {
        _curriculumRepository = CurriculumRepository(dataSource: ds);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager.instance,
      builder: (context, _) {
        final mode = ThemeManager.instance.themeMode;
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);

        return MaterialApp(
          title: 'GINGA Planificador V2 Preview (PED-04C1)',
          debugShowCheckedModeBanner: false,
          theme: gingaLightTheme,
          darkTheme: gingaDarkTheme,
          themeMode: mode,
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  if (widget.showPreviewToolbar) _buildToolbar(isDark),
                  Expanded(
                    child: _buildViewportBody(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(bool isDark) {
    final bg = isDark ? const Color(0xFF141814) : const Color(0xFFEAF3EA);
    final fg = isDark ? Colors.white : const Color(0xFF111812);
    final border = isDark ? const Color(0xFF2D382E) : const Color(0xFFC8DEC8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen,
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                child: Text(
                  _engineStatus?.realProviderEnabled == true
                      ? 'PREVIEW LOCAL · OPENAI REAL (TOPE \$0.10)'
                      : 'PREVIEW AISLADO · SIN FIREBASE NI IA PAGA',
                  style: GoogleFonts.montserrat(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              for (final s in PlannerPreviewScenario.values)
                _PreviewChip(
                  label: s.label,
                  selected: _scenario == s,
                  isDark: isDark,
                  onTap: () => setState(() {
                    _scenario = s;
                    _resetNonce++;
                  }),
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final vp in _PreviewViewport.values)
                _PreviewChip(
                  label: vp.label,
                  selected: _viewport == vp,
                  isDark: isDark,
                  onTap: () => setState(() => _viewport = vp),
                ),
              IconButton(
                onPressed: () {
                  ThemeManager.instance.setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: fg,
                  size: 20,
                ),
                tooltip:
                    isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewportBody(BuildContext context) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error cargando currículo local: $_loadError'),
        ),
      );
    }
    if (_curriculumRepository == null) {
      return const Center(
        child: CircularProgressIndicator(color: GingaColors.brandGreen),
      );
    }

    final initialTab = switch (_scenario) {
      PlannerPreviewScenario.hubResources => PlannerHubTab.resources,
      PlannerPreviewScenario.hubHistory => PlannerHubTab.history,
      _ => PlannerHubTab.plans,
    };
    final initialMode = switch (_scenario) {
      PlannerPreviewScenario.quickCreate => PlannerCreationMode.quick,
      PlannerPreviewScenario.infantilMj18 => PlannerCreationMode.quick,
      PlannerPreviewScenario.adultosMj19 => PlannerCreationMode.quick,
      PlannerPreviewScenario.advancedCreate => PlannerCreationMode.advanced,
      _ => null,
    };
    final initialGroupIdForCreation = switch (_scenario) {
      PlannerPreviewScenario.infantilMj18 => 'clase_kids_mj_1800',
      PlannerPreviewScenario.adultosMj19 => 'clase_adultos_mj_1900',
      _ => null,
    };
    final initialEditingPlanId = _scenario == PlannerPreviewScenario.editorV2
        ? 'v2_plan_adulto_01'
        : _scenario == PlannerPreviewScenario.copilotInfantil8of8
            ? 'v2_plan_infantil_8of8_demo'
            : null;
    final initialLivePlanId =
        _scenario == PlannerPreviewScenario.liveClass ? 'v2_plan_adulto_01' : null;
    final initialCreateManual =
        _scenario == PlannerPreviewScenario.editorManual;

    final previewToken = Uri.base.queryParameters['token'];

    final content = Navigator(
      key: ValueKey('planner_preview_nav_$_resetNonce'),
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (navCtx) => InstructorPizarraScreen(
          dataSource: _plannerDataSource,
          curriculumRepository: _curriculumRepository,
          engineClient: HttpLocalPlannerV2Client(previewToken: previewToken),
          initialTab: initialTab,
          initialCreationMode: initialMode,
          initialGroupIdForCreation: initialGroupIdForCreation,
          initialEditingPlanId: initialEditingPlanId,
          initialLivePlanId: initialLivePlanId,
          initialCreateManual: initialCreateManual,
          onOpenBiblioteca: () {
            Navigator.of(navCtx).push(
              MaterialPageRoute(
                builder: (_) => CurriculoBibliotecaScreen(
                  repository: _curriculumRepository,
                  overrideUserContext: const BibliotecaUserContext(
                    role: 'profesor',
                    cordaName: 'Laranja e Amarelo',
                    displayName: 'Prof. Preview',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (_viewport.width == null) return content;

    return ColoredBox(
      color: const Color(0xFF0E110E),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _viewport.width!),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(_viewport.width!, MediaQuery.of(context).size.height),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _PreviewChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? GingaColors.brandGreen
        : (isDark ? const Color(0xFF222922) : Colors.white);
    final fg = selected
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF111812));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GingaRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(GingaRadius.full),
          border: Border.all(
            color: selected
                ? GingaColors.brandGreen
                : (isDark ? const Color(0xFF39443A) : const Color(0xFFC5D5C5)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}
