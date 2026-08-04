import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/eventos_service.dart';
import '../../core/widgets/ginga_cached_image.dart';

class EventoDetalleScreen extends StatefulWidget {
  final String eventId;
  const EventoDetalleScreen({super.key, required this.eventId});

  @override
  State<EventoDetalleScreen> createState() => _EventoDetalleScreenState();
}

class _EventoDetalleScreenState extends State<EventoDetalleScreen> {
  double? _lat;
  double? _lng;
  String _userNombre = 'Alumno';
  String _userStatus = 'nuevo';
  bool _isLoadingExtra = true;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _loadEventLocationAndUser();
  }

  Future<void> _loadEventLocationAndUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      // 1. Cargar coordenadas desde /clases (ID coincidente)
      final claseDoc = await FirebaseFirestore.instance.collection('clases').doc(widget.eventId).get();
      if (claseDoc.exists) {
        final cData = claseDoc.data() ?? {};
        if (mounted) {
          setState(() {
            _lat = cData['lat'] != null ? (cData['lat'] as num).toDouble() : null;
            _lng = cData['lng'] != null ? (cData['lng'] as num).toDouble() : null;
          });
        }
      }

      // 2. Cargar nombre y status del usuario actual
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && mounted) {
          final uData = userDoc.data() ?? {};
          setState(() {
            _userNombre = uData['nombre'] ?? 'Alumno';
            _userStatus = uData['status'] ?? 'nuevo';
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando ubicación y usuario en detalle: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingExtra = false);
      }
    }
  }

  Future<void> _inscribirUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isRegistering = true);
    try {
      await EventosService.instance.registrarAsistencia(widget.eventId, _userNombre);
      if (mounted) {
        _mostrarModalExito();
      }
    } catch (e) {
      debugPrint('Error al inscribir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inscribirse: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  Future<void> _cancelarRegistro() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isRegistering = true);
    try {
      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventId)
          .collection('registros')
          .doc(uid)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro cancelado con éxito.')),
        );
      }
    } catch (e) {
      debugPrint('Error al cancelar registro: $e');
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  void _mostrarDialogoAccesoDenegado() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Inscripción Exclusiva 🔒',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: GingaColors.textPrimary),
        ),
        content: Text(
          'Para inscribirte a este evento o roda especial de la academia, debes ser un alumno registrado con membresía activa o en periodo de prueba.\n\nSi eres un usuario nuevo, solicita tu clase de prueba gratuita en la pantalla de inicio para comenzar.',
          style: GoogleFonts.montserrat(fontSize: 14, color: GingaColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: GoogleFonts.montserrat(color: GingaColors.brandGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarModalExito() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(sheetContext).padding.bottom > 0
              ? MediaQuery.of(sheetContext).padding.bottom + 16
              : 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: GingaColors.brandGreen, size: 48),
            const SizedBox(height: 12),
            Text('¡Inscripción exitosa! 🎉',
                style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Se registró tu asistencia confirmada para este evento.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 14, color: GingaColors.textSecondary)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      color: isDark ? Colors.white12 : Colors.black12,
      thickness: 1,
    );
  }

  Widget _buildTimeline(List<dynamic> cronograma) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(cronograma.length, (index) {
        final act = cronograma[index];
        final String dia = act['dia'] ?? '';
        final String hora = act['hora'] ?? '';
        final String actividad = act['actividad'] ?? '';
        final bool isLast = index == cronograma.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GingaColors.brandGreen.withOpacity(0.3),
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: GingaColors.brandGreen.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            size: 12,
                            color: GingaColors.brandGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$dia, $hora',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: GingaColors.brandGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        actividad,
                        style: GoogleFonts.montserrat(
                          fontSize: 13.5,
                          color: GingaColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInfoCardsGrid(String dateLabel, String timeLabel, String lugar) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white10 : GingaColors.borderLight;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildInfoCard(
          icon: Icons.calendar_today_outlined,
          title: 'Fecha',
          value: dateLabel,
          cardBg: cardBg,
          borderColor: borderColor,
        ),
        if (timeLabel.isNotEmpty)
          _buildInfoCard(
            icon: Icons.access_time_outlined,
            title: 'Hora de inicio',
            value: timeLabel,
            cardBg: cardBg,
            borderColor: borderColor,
          ),
        _buildInfoCard(
          icon: Icons.location_on_outlined,
          title: 'Lugar del evento',
          value: lugar,
          cardBg: cardBg,
          borderColor: borderColor,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GingaColors.brandGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(GingaRadius.sm),
            ),
            child: Icon(icon, size: 18, color: GingaColors.brandGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: GingaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(String lugar) async {
    if (_lat == null || _lng == null) return;
    final Uri googleUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$_lat,$_lng");
    final Uri appleUrl = Uri.parse("https://maps.apple.com/?q=${Uri.encodeComponent(lugar)}&ll=$_lat,$_lng");
    try {
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleUrl)) {
        await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Could not launch maps: $e");
    }
  }

  Widget _buildRegistrationWidget(bool isReg) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: _isRegistering
          ? const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
          : (isReg
              ? Row(
                  children: [
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GingaColors.brandGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: GingaColors.brandGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: GingaColors.brandGreen, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '¡Inscrito al Evento! 🎟️',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.brandGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _mostrarConfirmacionCancelacion(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          side: BorderSide(color: Colors.red.withOpacity(0.15)),
                        ),
                      ),
                    )
                  ],
                )
              : ElevatedButton(
                  onPressed: () {
                    if (_userStatus != 'activo' && _userStatus != 'prueba') {
                      _mostrarDialogoAccesoDenegado();
                    } else {
                      _inscribirUsuario();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GingaColors.brandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _userStatus == 'activo' || _userStatus == 'prueba'
                            ? 'Inscribirse Ahora'
                            : 'Inscripción Exclusiva 🔒',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_userStatus == 'activo' || _userStatus == 'prueba') ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ],
                  ),
                )),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 720;

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: isLargeScreen
          ? AppBar(
              backgroundColor: GingaColors.backgroundLight,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: GingaColors.textPrimary),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Detalle de Evento',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: GingaColors.textPrimary,
                ),
              ),
            )
          : null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('eventos').doc(widget.eventId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoadingExtra) {
            return const Center(
              child: CircularProgressIndicator(color: GingaColors.brandGreen),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(elevation: 0, backgroundColor: Colors.white, leading: const BackButton()),
              body: Center(
                child: Text(
                  'El evento no existe o fue retirado.',
                  style: GoogleFonts.montserrat(fontSize: 15, color: GingaColors.textSecondary),
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final titulo = data['titulo'] ?? 'Taller Especial';
          final organizador = data['organizador'] ?? 'Mestre Invitado';
          final fechaTexto = data['fecha_texto'] ?? 'Fecha por confirmar';
          final lugar = data['lugar'] ?? 'Por definir';
          final descripcion = data['descripcion'] ?? '';
          final imagenUrl = data['imagen_url'] ?? '';
          final List<dynamic> cronograma = data['cronograma'] ?? [];

          final String dateLabel;
          final String timeLabel;
          final parts = fechaTexto.split(',');
          if (parts.length >= 2) {
            dateLabel = parts[0].trim();
            timeLabel = parts[1].trim();
          } else {
            dateLabel = fechaTexto;
            timeLabel = '';
          }

          final isRoda = titulo.toLowerCase().contains('roda');
          final tagLabel = isRoda ? 'RODA ESPECIAL 🔥' : 'WORKSHOP ESPECIAL 🌟';
          final tagColor = isRoda ? GingaColors.brandGreen : GingaColors.accentAmber;
          final tagTextColor = isRoda ? Colors.white : const Color(0xFF412402);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SizedBox(
                width: double.infinity,
                child: isLargeScreen
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // COLUMNA IZQUIERDA
                            Expanded(
                              flex: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _HeroImage(
                                    imagenUrl: imagenUrl,
                                    eventId: widget.eventId,
                                    showBackButton: false,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Organizador / Invitado',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: GingaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _MestreCard(organizador: organizador),
                                  if (_lat != null && _lng != null) ...[
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Cómo llegar',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: GingaColors.textPrimary,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _openMaps(lugar),
                                          child: Text(
                                            'Abrir en Maps',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 13,
                                              color: GingaColors.brandGreen,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _MapPlaceholder(lat: _lat!, lng: _lng!, label: lugar),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            // COLUMNA DERECHA
                            Expanded(
                              flex: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: tagColor,
                                      borderRadius: BorderRadius.circular(GingaRadius.sm),
                                    ),
                                    child: Text(
                                      tagLabel,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: tagTextColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    titulo,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: GingaColors.textPrimary,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInfoCardsGrid(dateLabel, timeLabel, lugar),
                                  const SizedBox(height: 20),
                                  _buildDivider(),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Sobre el evento',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: GingaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    descripcion.isNotEmpty
                                        ? descripcion
                                        : 'Acompáñanos en esta actividad especial para la Familia FIU. Ven a entrenar, compartir la música y jugar en la roda. ¡Todos los niveles son bienvenidos!',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13.5,
                                      color: GingaColors.textSecondary,
                                      height: 1.6,
                                    ),
                                  ),
                                  if (cronograma.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    _buildDivider(),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Cronograma de Actividades',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: GingaColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTimeline(cronograma),
                                  ],
                                  const SizedBox(height: 20),
                                  _buildDivider(),
                                  const SizedBox(height: 20),
                                  StreamBuilder<bool>(
                                    stream: EventosService.instance.estaRegistrado(widget.eventId),
                                    builder: (context, regSnapshot) {
                                      final isReg = regSnapshot.data ?? false;
                                      return _buildRegistrationWidget(isReg);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HeroImage(imagenUrl: imagenUrl, eventId: widget.eventId, showBackButton: true),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: tagColor,
                                          borderRadius: BorderRadius.circular(GingaRadius.sm),
                                        ),
                                        child: Text(
                                          tagLabel,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: tagTextColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        titulo,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: GingaColors.textPrimary,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildInfoCardsGrid(dateLabel, timeLabel, lugar),
                                      const SizedBox(height: 20),
                                      _buildDivider(),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Sobre el evento',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: GingaColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        descripcion.isNotEmpty
                                            ? descripcion
                                            : 'Acompáñanos en esta actividad especial para la Familia FIU. Ven a entrenar, compartir la música y jugar en la roda. ¡Todos los niveles son bienvenidos!',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          color: GingaColors.textSecondary,
                                          height: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildDivider(),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Organizador / Invitado',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: GingaColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _MestreCard(organizador: organizador),
                                      if (cronograma.isNotEmpty) ...[
                                        const SizedBox(height: 20),
                                        _buildDivider(),
                                        const SizedBox(height: 20),
                                        Text(
                                          'Cronograma de Actividades',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: GingaColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTimeline(cronograma),
                                      ],
                                      if (_lat != null && _lng != null) ...[
                                        const SizedBox(height: 20),
                                        _buildDivider(),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Cómo llegar',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: GingaColors.textPrimary,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _openMaps(lugar),
                                              child: Text(
                                                'Abrir en Maps',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 13,
                                                  color: GingaColors.brandGreen,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _MapPlaceholder(lat: _lat!, lng: _lng!, label: lugar),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                MediaQuery.of(context).padding.bottom > 0
                                    ? MediaQuery.of(context).padding.bottom + 8
                                    : 24,
                              ),
                              decoration: BoxDecoration(
                                color: GingaColors.backgroundLight,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, -4),
                                  ),
                                ],
                              ),
                              child: StreamBuilder<bool>(
                                stream: EventosService.instance.estaRegistrado(widget.eventId),
                                builder: (context, regSnapshot) {
                                  final isReg = regSnapshot.data ?? false;
                                  return _buildRegistrationWidget(isReg);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _mostrarConfirmacionCancelacion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancelar Inscripción', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          '¿Estás seguro de que deseas cancelar tu inscripción a este evento especial?',
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Mantener', style: GoogleFonts.montserrat(color: GingaColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelarRegistro();
            },
            child: Text('Sí, Cancelar', style: GoogleFonts.montserrat(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String imagenUrl;
  final String eventId;
  final bool showBackButton;
  const _HeroImage({
    required this.imagenUrl,
    required this.eventId,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Hero(
          tag: 'event-image-$eventId',
          child: ClipRRect(
            borderRadius: showBackButton ? BorderRadius.zero : BorderRadius.circular(GingaRadius.lg),
            child: Container(
              height: 220,
              width: double.infinity,
              color: GingaColors.backgroundDark,
              child: GingaCachedImage(
                imageUrl: imagenUrl,
                fit: BoxFit.cover,
                category: 'evento',
                errorWidget: const Center(
                  child: Icon(
                    Icons.sports_martial_arts,
                    color: GingaColors.brandGreen,
                    size: 70,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showBackButton)
          Positioned(
            top: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top + 8 : 16,
            left: 16,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}


// ─────────────────────────────────────────
//  MESTRE CARD
// ─────────────────────────────────────────

class _MestreCard extends StatelessWidget {
  final String organizador;
  const _MestreCard({required this.organizador});

  @override
  Widget build(BuildContext context) {
    // Generar iniciales
    String iniciales = 'M';
    final parts = organizador.split(' ');
    if (parts.length >= 2) {
      iniciales = parts[0].substring(0, 1) + parts[1].substring(0, 1);
    } else if (organizador.isNotEmpty) {
      iniciales = organizador.substring(0, 1);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GingaColors.cardLight,
        borderRadius: BorderRadius.circular(GingaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: GingaColors.brandGreen,
            child: Text(
              iniciales.toUpperCase(),
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizador,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Instructor o Mestre encargado de guiar y coordinar las actividades de este evento especial. Comprometido con la difusión y excelencia de la Capoeira.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: GingaColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  MAP PLACEHOLDER
// ─────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  final double lat;
  final double lng;
  final String label;

  const _MapPlaceholder({required this.lat, required this.lng, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GingaRadius.md),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          border: Border.all(color: GingaColors.borderLight),
        ),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15.0,
                onTap: (tapPosition, point) async {
                  final Uri googleUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                  final Uri appleUrl = Uri.parse("https://maps.apple.com/?q=${Uri.encodeComponent(label)}&ll=$lat,$lng");
                  try {
                    if (await canLaunchUrl(googleUrl)) {
                      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
                    } else if (await canLaunchUrl(appleUrl)) {
                      await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
                    }
                  } catch (e) {
                    debugPrint("Could not launch maps on tap: $e");
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.jumperstudio.ginga_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: GingaColors.brandGreen,
                        size: 35,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation, color: GingaColors.brandGreen, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Toca para navegar',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}