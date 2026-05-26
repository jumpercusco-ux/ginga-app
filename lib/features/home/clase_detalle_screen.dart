import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';

class ClaseDetalleScreen extends StatefulWidget {
  final String claseId;

  const ClaseDetalleScreen({super.key, required this.claseId});

  @override
  State<ClaseDetalleScreen> createState() => _ClaseDetalleScreenState();
}

class _ClaseDetalleScreenState extends State<ClaseDetalleScreen> {
  bool _isLoading = false;

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

        final double ocupacionRatio =
            cuposMax > 0 ? (cuposMax - cuposDisponibles) / cuposMax : 0.0;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (builderContext, userSnapshot) {
            String userStatus = 'nuevo';
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              userStatus = userData['status'] ?? 'nuevo';
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
                      : userStatus == 'activo'
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
                          : null,
              body: SingleChildScrollView(
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
                          value: dias,
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
                        descripcion.isNotEmpty
                            ? descripcion
                            : 'En esta clase de Capoeira aprenderás los fundamentos esenciales de la disciplina: movimientos básicos (ginga, esquivas, patadas), nociones de musicalidad, ritmo y la estructura tradicional de la Roda. Ideal para mejorar tu coordinación, flexibilidad y conectar con una comunidad global vibrante.',
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          color: GingaColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
