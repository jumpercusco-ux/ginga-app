import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/ginga_theme.dart';

class ClaseDetalleScreen extends StatefulWidget {
  final String claseId;

  const ClaseDetalleScreen({super.key, required this.claseId});

  @override
  State<ClaseDetalleScreen> createState() => _ClaseDetalleScreenState();
}

class _ClaseDetalleScreenState extends State<ClaseDetalleScreen> {
  bool _isLoading = false;

  Future<Map<String, dynamic>?> _buscarEventoDestacado(String nombreClase, String badgeClase, String instructorClase) async {
    try {
      // 1. Intentar buscar por ID exacto de la clase para máxima robustez (Estrategia Same-ID)
      final exactDoc = await FirebaseFirestore.instance.collection('eventos').doc(widget.claseId).get();
      if (exactDoc.exists) {
        return exactDoc.data();
      }

      // 2. Fallback a la búsqueda semántica de texto para retrocompatibilidad con eventos antiguos/sembrados
      final query = await FirebaseFirestore.instance.collection('eventos').get();
      for (var doc in query.docs) {
        final data = doc.data();
        final String titulo = (data['titulo'] ?? '').toString().toLowerCase().trim();
        final String organizador = (data['organizador'] ?? '').toString().toLowerCase().trim();
        
        final lowerNombre = nombreClase.toLowerCase().trim();
        final lowerBadge = badgeClase.toLowerCase().trim();
        final lowerInst = instructorClase.toLowerCase().trim();

        // Si coincide por título o por el badge o instructor
        if (titulo.contains(lowerNombre) || lowerNombre.contains(titulo) ||
            titulo.contains(lowerBadge) || lowerBadge.contains(titulo) ||
            titulo.contains(lowerInst) || lowerInst.contains(organizador)) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('Error al buscar evento destacado: $e');
    }
    return null;
  }

  String _interpretarDiasDeSemana(String diasRaw) {
    if (diasRaw.isEmpty) return '';
    final Map<String, String> mapaDias = {
      'L': 'Lunes',
      'M': 'Martes',
      'X': 'Miércoles',
      'J': 'Jueves',
      'V': 'Viernes',
      'S': 'Sábado',
      'D': 'Domingo',
    };
    return diasRaw.split(',').map((p) {
      final trimmed = p.trim();
      return mapaDias[trimmed] ?? trimmed;
    }).join(', ');
  }

  Future<String> _getInstructorName(String instructorId) async {
    if (instructorId.isEmpty) return 'Instructor Ginga';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(instructorId)
          .get();
      return doc.data()?['nombre'] ?? 'Instructor Ginga';
    } catch (_) {
      return 'Instructor Ginga';
    }
  }

  Future<void> _reservarClasePrueba(Map<String, dynamic> claseData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final String userNombre = userDoc.exists ? (userDoc.data()?['nombre'] ?? 'Alumno') : 'Alumno';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final claseRef =
            FirebaseFirestore.instance.collection('clases').doc(widget.claseId);
        final claseDoc = await transaction.get(claseRef);
        final data = claseDoc.data() ?? {};
        final int cupos = (data['cupos_disponibles'] as num?)?.toInt() ?? 0;

        if (cupos <= 0) throw Exception('Sin cupos');

        transaction.update(claseRef, {'cupos_disponibles': cupos - 1});

        final reservaRef =
            FirebaseFirestore.instance.collection('reservas').doc();
        transaction.set(reservaRef, {
          'user_id': uid,
          'clase_id': widget.claseId,
          'nivel': claseData['nivel'] ?? '',
          'hora': claseData['hora'] ?? '',
          'dias': claseData['dias'] ?? '',
          'status': 'confirmado',
          'tipo': 'prueba',
          'created_at': FieldValue.serverTimestamp(),
        });

        // Cambia status del usuario a "prueba"
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        transaction.update(userRef, {'status': 'prueba'});

        // Generar notificación en el buzón del usuario para activar el push real vía Cloud Function
        final notifRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('notificaciones').doc();
        transaction.set(notifRef, {
          'titulo': 'Clase reservada 🗓️',
          'mensaje': 'Reservaste tu clase de prueba gratis para ${claseData['nivel']} los días ${claseData['dias']} a las ${claseData['hora']}.',
          'fecha': FieldValue.serverTimestamp(),
          'leido': false,
          'tipo': 'bienvenida',
        });

        // Generar notificación en el buzón del instructor
        final String instructorId = claseData['instructor_id'] ?? 'JGqDCSsPDBae4VLmtke9hKIYufh1';
        if (instructorId.isNotEmpty) {
          final instNotifRef = FirebaseFirestore.instance
              .collection('users')
              .doc(instructorId)
              .collection('notificaciones')
              .doc();
          transaction.set(instNotifRef, {
            'titulo': 'Nueva reserva de prueba 🥋',
            'mensaje': '$userNombre reservó su clase de prueba gratis de ${claseData['nivel']} para ${claseData['dias']} a las ${claseData['hora']}.',
            'fecha': FieldValue.serverTimestamp(),
            'leido': false,
            'tipo': 'bienvenida',
          });
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('¡Clase de prueba reservada! 🎉',
            style: GoogleFonts.nunito(color: Colors.white)),
        backgroundColor: GingaColors.brandGreen,
      ));
      context.go('/home');
    } catch (e) {
      debugPrint('Error en _reservarClasePrueba: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al reservar. Intenta de nuevo.',
            style: GoogleFonts.nunito(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registrarAsistenciaEvento(
      Map<String, dynamic> claseData, String userNombre, String uid) async {
    setState(() => _isLoading = true);
    try {
      // 1. Agregar a la colección /reservas
      await FirebaseFirestore.instance.collection('reservas').add({
        'user_id': uid,
        'clase_id': widget.claseId,
        'nivel': claseData['nivel'] ?? '',
        'hora': claseData['hora'] ?? '',
        'dias': claseData['dias'] ?? '',
        'status': 'confirmado',
        'tipo': 'evento',
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. Registrar también en la colección /eventos si corresponde para mantener la retrocompatibilidad
      try {
        final eventosQuery = await FirebaseFirestore.instance
            .collection('eventos')
            .where('titulo', isEqualTo: claseData['nombre'])
            .limit(1)
            .get();
        if (eventosQuery.docs.isNotEmpty) {
          final eventId = eventosQuery.docs.first.id;
          await FirebaseFirestore.instance
              .collection('eventos')
              .doc(eventId)
              .collection('registros')
              .doc(uid)
              .set({
            'user_id': uid,
            'nombre': userNombre,
            'fecha_registro': Timestamp.now(),
            'confirmado': true,
          });
        }
      } catch (e) {
        debugPrint('Error en registro secundario de eventos: $e');
      }

      // 3. Notificación in-app
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notificaciones')
          .add({
        'titulo': 'Cupo reservado para evento 🗓️',
        'mensaje': 'Confirmaste tu asistencia para "${claseData['nombre']}" el ${claseData['dias']} a las ${claseData['hora']}. ¡Nos vemos en la Roda!',
        'fecha': FieldValue.serverTimestamp(),
        'leido': false,
        'tipo': 'evento',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Asistencia al evento confirmada! 🎉',
                style: GoogleFonts.nunito(color: Colors.white)),
            backgroundColor: GingaColors.brandGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al registrar asistencia al evento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar asistencia. Intenta de nuevo.',
                style: GoogleFonts.nunito(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: GingaColors.brandGreen, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: GingaColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: GingaColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .doc(widget.claseId)
          .snapshots(),
      builder: (builderContext, classSnapshot) {
        if (classSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: GingaColors.backgroundLight,
            body: Center(
              child: CircularProgressIndicator(color: GingaColors.brandGreen),
            ),
          );
        }

        if (!classSnapshot.hasData || !classSnapshot.data!.exists) {
          return Scaffold(
            backgroundColor: GingaColors.backgroundLight,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => builderContext.pop(),
              ),
            ),
            body: Center(
              child: Text(
                'La clase no se encuentra disponible',
                style: GoogleFonts.nunito(
                    fontSize: 16, color: GingaColors.textSecondary),
              ),
            ),
          );
        }

        final clase = classSnapshot.data!.data() as Map<String, dynamic>;
        final String nombre = clase['nombre'] ?? 'Clase de Capoeira';
        final String nivel = clase['nivel'] ?? 'Todos los niveles';
        final String dias = clase['dias'] ?? '';
        final String hora = clase['hora'] ?? '';
        final String horaFin = clase['hora_fin'] ?? '';
        final int cuposMax = clase['cupos_max'] ?? 10;
        final int cuposDisponibles = clase['cupos_disponibles'] ?? 0;
        final String modalidad = clase['modalidad'] ?? 'Presencial';
        final String ubicacion = clase['ubicacion'] ?? 'Sede Central';
        final String descripcion = clase['descripcion'] ?? '';
        final String instructorId = clase['instructor_id'] ?? '';
        final String tipo = clase['tipo'] ?? 'regular';
        final String badge = clase['badge'] ?? '';
        final bool isEvent = tipo == 'especial' ||
            tipo == 'roda' ||
            badge.toLowerCase().contains('especial') ||
            badge.toLowerCase().contains('roda') ||
            badge.toLowerCase().contains('evento') ||
            nombre.toLowerCase().contains('especial') ||
            nombre.toLowerCase().contains('roda') ||
            nombre.toLowerCase().contains('evento');

        final double? lat = clase['lat'] != null ? (clase['lat'] as num).toDouble() : null;
        final double? lng = clase['lng'] != null ? (clase['lng'] as num).toDouble() : null;

        final double ocupacionRatio =
            cuposMax > 0 ? (cuposMax - cuposDisponibles) / cuposMax : 0.0;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (builderContext, userSnapshot) {
            String userStatus = 'nuevo';
            String userNombre = 'Alumno';
            String userClaseId = '';
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              userStatus = userData['status'] ?? 'nuevo';
              userNombre = userData['nombre'] ?? 'Alumno';
              userClaseId = userData['clase_id'] ?? '';
            }

            return Scaffold(
              backgroundColor: GingaColors.backgroundLight,
              appBar: AppBar(
                backgroundColor: GingaColors.backgroundLight,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: GingaColors.textPrimary),
                  onPressed: () => builderContext.pop(),
                ),
                title: Text(
                  'Detalle de la Clase',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: GingaColors.textPrimary,
                  ),
                ),
              ),
              bottomNavigationBar: userStatus == 'nuevo'
                  ? SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading || cuposDisponibles <= 0
                                ? null
                                : () => _reservarClasePrueba(clase),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GingaColors.brandGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(GingaRadius.full),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    cuposDisponibles <= 0
                                        ? 'Sin cupos disponibles'
                                        : 'Reservar mi Clase de Prueba Gratis',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    )
                  : userStatus == 'prueba'
                      ? SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color:
                                    GingaColors.accentAmber.withOpacity(0.12),
                                borderRadius:
                                    BorderRadius.circular(GingaRadius.md),
                                border: Border.all(
                                    color: GingaColors.accentAmber
                                        .withOpacity(0.4)),
                              ),
                              child: Center(
                                child: Text(
                                  'Ya tienes una clase de prueba en curso',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.accentAmber,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : isEvent
                          ? StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('reservas')
                                  .where('user_id', isEqualTo: uid)
                                  .where('clase_id', isEqualTo: widget.claseId)
                                  .snapshots(),
                              builder: (context, resSnapshot) {
                                final isRegistered = resSnapshot.hasData &&
                                    resSnapshot.data!.docs.isNotEmpty;

                                if (isRegistered) {
                                  return SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                                      child: Container(
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: GingaColors.brandGreen.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(GingaRadius.md),
                                          border: Border.all(color: GingaColors.brandGreen.withOpacity(0.4)),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.check_circle_rounded, color: GingaColors.brandGreen, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                '¡Tu cupo está reservado! ✅',
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
                                    ),
                                  );
                                }

                                return SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                                    child: SizedBox(
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed: () => _registrarAsistenciaEvento(clase, userNombre, uid ?? ''),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: GingaColors.brandGreen,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(GingaRadius.md),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'Confirmar Asistencia al Evento ☀️',
                                          style: GoogleFonts.montserrat(
                                              fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : userStatus == 'activo'
                              ? widget.claseId == userClaseId
                                  ? SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                                        child: Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color: GingaColors.brandGreen.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(GingaRadius.md),
                                            border: Border.all(
                                                color: GingaColors.brandGreen
                                                    .withOpacity(0.4)),
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.check_circle_rounded,
                                                    color: GingaColors.brandGreen, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Eres miembro activo en esta clase',
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
                                      ),
                                    )
                                  : SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                                        child: Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color: GingaColors.brandGreen.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(GingaRadius.md),
                                            border: Border.all(
                                                color: GingaColors.brandGreen
                                                    .withOpacity(0.3)),
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.info_outline,
                                                    color: GingaColors.brandGreen, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Eres miembro activo en otra clase',
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
                                      ),
                                    )
                              : null,
              body: FutureBuilder<Map<String, dynamic>?>(
                future: _buscarEventoDestacado(nombre, badge, instructorId),
                builder: (context, eventSnapshot) {
                  final eventData = eventSnapshot.data;
                  final String displayDescription = eventData != null && (eventData['descripcion'] ?? '').toString().isNotEmpty
                      ? eventData['descripcion']
                      : descripcion;
                  final String? organizador = eventData != null ? eventData['organizador'] : null;
                  final List<dynamic> cronograma = eventData != null ? (eventData['cronograma'] ?? []) : [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // ── Banner Tarjeta Principal ────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: tipo == 'roda'
                              ? [
                                  GingaColors.accentAmber.withOpacity(0.8),
                                  GingaColors.accentAmber
                                ]
                              : [
                                  GingaColors.brandGreen,
                                  GingaColors.brandGreen.withOpacity(0.8)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (organizador != null && organizador.isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ORGANIZADO POR: ${organizador.toUpperCase()} 🌟',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(GingaRadius.sm),
                            ),
                            child: Text(
                              nivel.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            nombre,
                            style: GoogleFonts.montserrat(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sesión Oficial de Capoeira',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Medidor de Cupos Disponibles ───────────────────
                    Text(
                      'Estado de Inscripción',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$cuposDisponibles de $cuposMax cupos',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: cuposDisponibles == 0
                                      ? Colors.red
                                      : GingaColors.brandGreen,
                                ),
                              ),
                              Text(
                                cuposDisponibles == 0
                                    ? 'Clase Llena'
                                    : 'Disponibles',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: GingaColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(GingaRadius.full),
                            child: LinearProgressIndicator(
                              value: 1.0 - ocupacionRatio,
                              minHeight: 8,
                              backgroundColor: GingaColors.borderLight,
                              valueColor: AlwaysStoppedAnimation(
                                cuposDisponibles == 0
                                    ? Colors.red
                                    : GingaColors.brandGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Ficha del Instructor ───────────────────────────
                    Text(
                      'Instructor a Cargo',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: _getInstructorName(instructorId),
                      builder: (builderContext, instSnapshot) {
                        final String instructorName =
                            instSnapshot.data ?? 'Cargando instructor...';
                        final String inicial = instructorName.isNotEmpty
                            ? instructorName[0].toUpperCase()
                            : 'I';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(GingaRadius.lg),
                            border: Border.all(color: GingaColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    GingaColors.brandGreen.withOpacity(0.12),
                                child: Text(
                                  inicial,
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: GingaColors.brandGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      instructorName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: GingaColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Profesor Certificado de Ginga',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: GingaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── Datos Clave (Grid de Horarios, etc.) ─────────
                    Text(
                      'Información General',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildInfoCard(
                          icon: Icons.access_time_outlined,
                          title: 'Horario',
                          value: '$hora - $horaFin',
                        ),
                        _buildInfoCard(
                          icon: Icons.calendar_today_outlined,
                          title: 'Días',
                          value: _interpretarDiasDeSemana(dias),
                        ),
                        _buildInfoCard(
                          icon: Icons.meeting_room_outlined,
                          title: 'Modalidad',
                          value: modalidad,
                        ),
                        _buildInfoCard(
                          icon: Icons.location_on_outlined,
                          title: 'Ubicación',
                          value: ubicacion,
                        ),
                      ],
                    ),
                    if (lat != null && lng != null) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ubicación exacta 📍',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final Uri googleUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                              final Uri appleUrl = Uri.parse("https://maps.apple.com/?q=${Uri.encodeComponent(ubicacion)}&ll=$lat,$lng");
                              try {
                                if (await canLaunchUrl(googleUrl)) {
                                  await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
                                } else if (await canLaunchUrl(appleUrl)) {
                                  await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
                                } else {
                                  await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
                                }
                              } catch (e) {
                                debugPrint("Could not launch url: $e");
                              }
                            },
                            child: Text(
                              'Abrir en Maps',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: GingaColors.brandGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(GingaRadius.lg),
                            border: Border.all(color: GingaColors.borderLight),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(lat, lng),
                                    initialZoom: 15.0,
                                    onTap: (tapPosition, point) async {
                                      final Uri googleUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                                      final Uri appleUrl = Uri.parse("https://maps.apple.com/?q=${Uri.encodeComponent(ubicacion)}&ll=$lat,$lng");
                                      try {
                                        if (await canLaunchUrl(googleUrl)) {
                                          await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
                                        } else if (await canLaunchUrl(appleUrl)) {
                                          await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
                                        } else {
                                          await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
                                        }
                                      } catch (e) {
                                        debugPrint("Could not launch maps url on tap: $e");
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
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
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
                                      const Icon(Icons.navigation, color: GingaColors.brandGreen, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Toca para navegar',
                                        style: GoogleFonts.nunito(
                                          fontSize: 11,
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
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── Descripción de la Clase ──────────────────────
                    Text(
                      'Sobre esta clase',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: Text(
                        displayDescription.isNotEmpty
                            ? displayDescription
                            : 'En esta clase de Capoeira aprenderás los fundamentos esenciales de la disciplina: movimientos básicos (ginga, esquivas, patadas), nociones de musicalidad, ritmo y la estructura tradicional de la Roda. Ideal para mejorar tu coordinación, flexibilidad y conectar con una comunidad global vibrante.',
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          color: GingaColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // ── Cronograma del Evento (Timeline Visual Premium) ────
                    if (cronograma.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Cronograma del Evento 📅',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        child: Column(
                          children: List.generate(cronograma.length, (idx) {
                            final item = cronograma[idx];
                            final dia = item['dia'] ?? '';
                            final hora = item['hora'] ?? '';
                            final act = item['actividad'] ?? '';
                            final isLast = idx == cronograma.length - 1;

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: GingaColors.brandGreen,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: GingaColors.brandGreen.withOpacity(0.3),
                                              blurRadius: 4,
                                            )
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${idx + 1}',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            color: GingaColors.brandGreen.withOpacity(0.3),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 20.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF8E1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  dia.toString().toUpperCase(),
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(0xFFE65100),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                hora,
                                                style: GoogleFonts.nunito(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: GingaColors.brandGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            act,
                                            style: GoogleFonts.nunito(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: GingaColors.textPrimary,
                                              height: 1.4,
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
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  },
);
  }
}
