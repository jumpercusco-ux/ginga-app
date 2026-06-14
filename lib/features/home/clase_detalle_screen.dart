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

  Future<String> _getInstructorName(String instructorId, {String fallback = ''}) async {
    if (instructorId.isEmpty) {
      return fallback.isNotEmpty ? fallback : 'Instructor Ginga';
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(instructorId)
          .get();
      final name = doc.data()?['nombre'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name;
      }
      return fallback.isNotEmpty ? fallback : 'Instructor Ginga';
    } catch (_) {
      return fallback.isNotEmpty ? fallback : 'Instructor Ginga';
    }
  }

  DateTime _calcularProximaFecha(Map<String, dynamic> claseData) {
    final String diasRaw = claseData['dias'] ?? '';
    final now = DateTime.now();
    if (diasRaw.isEmpty) return now;

    final Map<String, int> mapaDias = {
      'L': DateTime.monday,
      'M': DateTime.tuesday,
      'X': DateTime.wednesday,
      'J': DateTime.thursday,
      'V': DateTime.friday,
      'S': DateTime.saturday,
      'D': DateTime.sunday,
    };

    final targetDays = diasRaw
        .split(',')
        .map((p) => mapaDias[p.trim().toUpperCase()])
        .whereType<int>()
        .toList();

    if (targetDays.isEmpty) return now;

    // Extraer hora de inicio (ej. "19:00")
    final String horaRaw = claseData['hora'] ?? '';
    int targetHour = 19;
    int targetMinute = 0;
    try {
      final cleanHora = horaRaw.split('-')[0].trim();
      final parts = cleanHora.split(':');
      if (parts.length >= 2) {
        targetHour = int.parse(parts[0]);
        targetMinute = int.parse(parts[1]);
      }
    } catch (_) {}

    int menorDiferencia = 8;
    for (int targetDay in targetDays) {
      int diff = targetDay - now.weekday;
      if (diff < 0) {
        diff += 7;
      } else if (diff == 0) {
        final classDateTime = DateTime(now.year, now.month, now.day, targetHour, targetMinute);
        if (now.isAfter(classDateTime)) {
          diff = 7;
        }
      }
      if (diff < menorDiferencia) {
        menorDiferencia = diff;
      }
    }

    return now.add(Duration(days: menorDiferencia));
  }

  String _formatearFechaClase(DateTime fecha) {
    final Map<int, String> meses = {
      1: 'Enero',
      2: 'Febrero',
      3: 'Marzo',
      4: 'Abril',
      5: 'Mayo',
      6: 'Junio',
      7: 'Julio',
      8: 'Agosto',
      9: 'Septiembre',
      10: 'Octubre',
      11: 'Noviembre',
      12: 'Diciembre',
    };
    final Map<int, String> diasSemana = {
      1: 'Lunes',
      2: 'Martes',
      3: 'Miércoles',
      4: 'Jueves',
      5: 'Viernes',
      6: 'Sábado',
      7: 'Domingo',
    };

    final diaNombre = diasSemana[fecha.weekday] ?? '';
    final mesNombre = meses[fecha.month] ?? '';
    
    final now = DateTime.now();
    final isToday = now.year == fecha.year && now.month == fecha.month && now.day == fecha.day;
    final isTomorrow = now.add(const Duration(days: 1)).year == fecha.year &&
                       now.add(const Duration(days: 1)).month == fecha.month &&
                       now.add(const Duration(days: 1)).day == fecha.day;

    final suffix = isToday ? ' (Hoy)' : (isTomorrow ? ' (Mañana)' : '');
    
    return '$diaNombre, ${fecha.day} de $mesNombre$suffix';
  }

  Future<void> _reservarClasePrueba(Map<String, dynamic> claseData, DateTime fechaClase) async {
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
          'fecha_clase': Timestamp.fromDate(fechaClase),
          'created_at': FieldValue.serverTimestamp(),
        });

        // Cambia status del usuario a "prueba"
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        transaction.update(userRef, {'status': 'prueba'});

        // Generar notificación en el buzón del usuario para activar el push real vía Cloud Function
        final notifRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('notificaciones').doc();
        transaction.set(notifRef, {
          'titulo': 'Clase reservada 🗓️',
          'mensaje': 'Reservaste tu clase de prueba gratis para ${claseData['nivel']} el ${_formatearFechaClase(fechaClase)} a las ${claseData['hora']}.',
          'fecha': FieldValue.serverTimestamp(),
          'leido': false,
          'tipo': 'bienvenida',
          'clase_id': widget.claseId,
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
            'mensaje': '$userNombre reservó su clase de prueba gratis de ${claseData['nivel']} para el ${_formatearFechaClase(fechaClase)} a las ${claseData['hora']}.',
            'fecha': FieldValue.serverTimestamp(),
            'leido': false,
            'tipo': 'bienvenida',
            'clase_id': widget.claseId,
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

  void _mostrarConfirmacionClasePrueba(BuildContext context, Map<String, dynamic> claseData) {
    final DateTime fechaProxima = _calcularProximaFecha(claseData);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final String nombre = claseData['nombre'] ?? 'Clase de Capoeira';
        final String nivel = claseData['nivel'] ?? 'Todos los niveles';
        final String dias = claseData['dias'] ?? '';
        final String hora = claseData['hora'] ?? '';
        final String horaFin = claseData['hora_fin'] ?? '';
        final String ubicacion = claseData['ubicacion'] ?? 'Sede Central';
        final String instructorId = claseData['instructor_id'] ?? '';
        final String instructorNombre = claseData['instructor'] ?? '';

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
          ),
          backgroundColor: GingaColors.backgroundLight,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: GingaColors.brandGreen.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sports_martial_arts,
                          color: GingaColors.brandGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Confirmar Clase',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Estás por reservar tu clase de prueba gratuita. Por favor confirma los detalles de la sesión:',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: GingaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? GingaColors.backgroundDark
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.transparent
                            : GingaColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetalleConfirmacionRow(Icons.class_outlined, 'Clase', nombre),
                        const SizedBox(height: 10),
                        _buildDetalleConfirmacionRow(Icons.trending_up, 'Nivel', nivel),
                        const SizedBox(height: 10),
                        _buildDetalleConfirmacionRow(Icons.calendar_today_outlined, 'Días', _interpretarDiasDeSemana(dias)),
                        const SizedBox(height: 10),
                        _buildDetalleConfirmacionRow(Icons.access_time_outlined, 'Horario', '$hora - $horaFin'),
                        const SizedBox(height: 10),
                        _buildDetalleConfirmacionRow(Icons.location_on_outlined, 'Sede', ubicacion),
                        const SizedBox(height: 10),
                        _buildDetalleConfirmacionRow(Icons.event, 'Fecha de Prueba', _formatearFechaClase(fechaProxima)),
                        const SizedBox(height: 10),
                        FutureBuilder<String>(
                          future: _getInstructorName(instructorId, fallback: instructorNombre),
                          builder: (context, snapshot) {
                            final String instructorName = snapshot.data ?? 'Cargando...';
                            return _buildDetalleConfirmacionRow(Icons.person_outline, 'Instructor', instructorName);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(GingaRadius.sm),
                      border: Border.all(color: GingaColors.brandGreen.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.redeem_rounded,
                          color: GingaColors.brandGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Beneficio: 1 Sesión Gratis de Prueba 🥋',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.brandGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                            ),
                            minimumSize: const Size(0, 46),
                          ),
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _reservarClasePrueba(claseData, fechaProxima);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GingaColors.brandGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.full),
                            ),
                            minimumSize: const Size(0, 46),
                            elevation: 0,
                          ),
                          child: Text(
                            'Confirmar',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetalleConfirmacionRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: GingaColors.brandGreen, size: 15),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            '$label: ',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: GingaColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: GingaColors.textPrimary,
            ),
          ),
        ),
      ],
    );
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
          style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textSecondary, height: 1.5),
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
        'clase_id': widget.claseId,
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

  void _mostrarDetalleDialog(BuildContext context, String title, String value, IconData icon) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
          ),
          backgroundColor: GingaColors.backgroundLight,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GingaColors.brandGreen.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: GingaColors.brandGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: GingaColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Entendido',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return GestureDetector(
      onTap: () => _mostrarDetalleDialog(context, title, value, icon),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(GingaRadius.md),
          border: Border.all(color: borderColor),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clases')
          .doc(widget.claseId)
          .snapshots(),
      builder: (builderContext, classSnapshot) {
        if (classSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
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
        final String instructorNombre = clase['instructor'] ?? '';
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
            String userRole = 'alumno';
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              userStatus = userData['status'] ?? 'nuevo';
              userNombre = userData['nombre'] ?? 'Alumno';
              userClaseId = userData['clase_id'] ?? '';
              userRole = userData['rol'] ?? 'alumno';
            }

            return Scaffold(
              backgroundColor: GingaColors.backgroundLight,
              appBar: AppBar(
                backgroundColor: GingaColors.backgroundLight,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: GingaColors.textPrimary),
                  onPressed: () async {
                    if (builderContext.canPop()) {
                      builderContext.pop();
                    } else {
                      try {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          final doc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .get();
                          final role = doc.data()?['rol'] ?? 'alumno';
                          if (role == 'profesor') {
                            if (builderContext.mounted) builderContext.go('/instructor-clase');
                            return;
                          }
                        }
                      } catch (e) {
                        debugPrint("Error al validar rol para navegacion back: $e");
                      }
                      if (builderContext.mounted) builderContext.go('/home');
                    }
                  },
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
              bottomNavigationBar: userRole == 'profesor'
                  ? null
                  : Center(
                      heightFactor: 1.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: (isEvent
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
                                    onPressed: () {
                                      if (userStatus != 'activo' && userStatus != 'prueba') {
                                        _mostrarDialogoAccesoDenegado();
                                      } else {
                                        _registrarAsistenciaEvento(clase, userNombre, uid ?? '');
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
                                    child: Text(
                                      userStatus == 'activo' || userStatus == 'prueba'
                                          ? 'Confirmar Asistencia al Evento ☀️'
                                          : 'Inscripción Exclusiva 🔒',
                                      style: GoogleFonts.montserrat(
                                          fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : userStatus == 'nuevo'
                          ? SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                                child: SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading || cuposDisponibles <= 0
                                        ? null
                                        : () => _mostrarConfirmacionClasePrueba(context, clase),
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
                                  : null))),
              body: FutureBuilder<Map<String, dynamic>?>(
                future: _buscarEventoDestacado(nombre, badge, instructorId),
                builder: (context, eventSnapshot) {
                  final eventData = eventSnapshot.data;
                  final String displayDescription = eventData != null && (eventData['descripcion'] ?? '').toString().isNotEmpty
                      ? eventData['descripcion']
                      : descripcion;
                  final String? organizador = eventData != null ? eventData['organizador'] : null;
                  final List<dynamic> cronograma = eventData != null ? (eventData['cronograma'] ?? []) : [];

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // ── Banner Tarjeta Principal ────────────────────────
                        Hero(
                          tag: 'class-card-${widget.claseId}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
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
                        color: cardBg,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: borderColor),
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
                      future: _getInstructorName(instructorId, fallback: instructorNombre),
                      builder: (builderContext, instSnapshot) {
                        final String instructorName =
                            instSnapshot.data ?? 'Cargando instructor...';
                        final String inicial = instructorName.isNotEmpty
                            ? instructorName[0].toUpperCase()
                            : 'I';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(GingaRadius.lg),
                            border: Border.all(color: borderColor),
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
                        color: cardBg,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: borderColor),
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
                          color: cardBg,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: borderColor),
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
                                                  color: isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF8E1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  dia.toString().toUpperCase(),
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
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
                    if (userRole == 'profesor') ...[
                        const SizedBox(height: 28),
                        _buildAlumnosInscritosSection(widget.claseId),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
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

  Widget _buildAlumnosInscritosSection(String claseId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alumnos Regulares Inscritos 🥋',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: GingaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('clase_id', isEqualTo: claseId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'No hay alumnos regulares inscritos en esta clase.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: GingaColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            final alumnos = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alumnos.length,
              itemBuilder: (context, index) {
                final alumnoData = alumnos[index].data() as Map<String, dynamic>;
                final String nombre = alumnoData['nombre'] ?? 'Sin nombre';
                final String corda = alumnoData['corda'] ?? 'Crua';
                final String status = alumnoData['status'] ?? 'nuevo';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: GingaColors.brandGreen.withOpacity(0.1),
                        child: const Icon(Icons.person, color: GingaColors.brandGreen, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Cuerda: $corda',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: GingaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: GingaColors.brandGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.brandGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Reservas de Clase de Prueba / Eventos 🗓️',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: GingaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservas')
              .where('clase_id', isEqualTo: claseId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'No hay reservas registradas para esta clase.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: GingaColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            final reservas = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reservas.length,
              itemBuilder: (context, index) {
                final reservaData = reservas[index].data() as Map<String, dynamic>;
                final String userId = reservaData['user_id'] ?? '';
                final String status = reservaData['status'] ?? 'confirmado';
                final String tipo = reservaData['tipo'] ?? 'prueba';

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                  builder: (context, userSnapshot) {
                    String nombre = 'Cargando...';
                    String corda = '...';
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final udata = userSnapshot.data!.data() as Map<String, dynamic>;
                      nombre = udata['nombre'] ?? 'Sin nombre';
                      corda = udata['corda'] ?? 'Crua';
                    }

                    final bool isPrueba = tipo == 'prueba';
                    final Color badgeColor = isPrueba ? GingaColors.accentAmber : Colors.blue;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: badgeColor.withOpacity(0.1),
                            child: Icon(
                              isPrueba ? Icons.star_border : Icons.event,
                              color: badgeColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  isPrueba ? 'Clase de Prueba — Grado: $corda' : 'Evento / Roda Especial',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    color: GingaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
