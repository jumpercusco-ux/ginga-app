import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/ginga_theme.dart';

class QrGeneratorScreen extends StatefulWidget {
  final String claseId;
  final String nivel;
  final String hora;

  const QrGeneratorScreen({
    super.key,
    required this.claseId,
    required this.nivel,
    required this.hora,
  });

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  String? _sesionId;
  bool _isLoading = true;
  int _asistencias = 0;

  @override
  void initState() {
    super.initState();
    _crearSesion();
  }

  Future<void> _crearSesion() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ahora = DateTime.now();
    final fecha =
        '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';

    try {
      // Busca si ya existe una sesión activa para esta clase el día de hoy
      final existencias = await FirebaseFirestore.instance
          .collection('sesiones')
          .where('clase_id', isEqualTo: widget.claseId)
          .where('fecha', isEqualTo: fecha)
          .where('activa', isEqualTo: true)
          .get();

      String sesionId;

      if (existencias.docs.isNotEmpty) {
        // Reutiliza la sesión activa existente
        sesionId = existencias.docs.first.id;
      } else {
        // Crea una nueva sesión si no hay una activa hoy
        final sesionRef = await FirebaseFirestore.instance
            .collection('sesiones')
            .add({
          'clase_id': widget.claseId,
          'instructor_id': uid,
          'nivel': widget.nivel,
          'hora': widget.hora,
          'fecha': fecha,
          'created_at': FieldValue.serverTimestamp(),
          'activa': true,
        });
        sesionId = sesionRef.id;
      }

      if (!mounted) return;

      setState(() {
        _sesionId = sesionId;
        _isLoading = false;
      });

      // Escucha asistencias en tiempo real
      FirebaseFirestore.instance
          .collection('asistencias')
          .where('sesion_id', isEqualTo: sesionId)
          .snapshots()
          .listen((snap) {
        if (mounted) {
          setState(() => _asistencias = snap.docs.length);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al cargar la sesión de hoy',
              style: GoogleFonts.montserrat(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        title: Text('QR de Clase',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        backgroundColor: GingaColors.backgroundLight,
        foregroundColor: GingaColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: GingaColors.brandGreen))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Info de la clase integrada con el contador
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: GingaColors.cardLight,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.nivel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: GingaColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.hora,
                                  style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      color: GingaColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: GingaColors.brandGreen,
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_asistencias',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.1),
                                ),
                                Text(
                                  _asistencias == 1 ? 'alumno' : 'alumnos',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // QR Code más compacto
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: GingaColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: QrImageView(
                        data: _sesionId!,
                        version: QrVersions.auto,
                        size: 180,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: GingaColors.brandGreen,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Muestra este QR a tus alumnos',
                      style: GoogleFonts.montserrat(
                          fontSize: 13, color: GingaColors.textSecondary),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Alumnos registrados en vivo',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'En vivo',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('asistencias')
                            .where('sesion_id', isEqualTo: _sesionId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: GingaColors.brandGreen),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Text(
                                'Esperando escaneos de alumnos...',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  color: GingaColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            );
                          }

                          // Ordenar en memoria por created_at descendiente para evitar la necesidad de crear un índice compuesto
                          final docs = snapshot.data!.docs.toList();
                          docs.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            final aTime = aData['created_at'] as Timestamp?;
                            final bTime = bData['created_at'] as Timestamp?;
                            if (aTime == null && bTime == null) return 0;
                            if (aTime == null) return 1;
                            if (bTime == null) return -1;
                            return bTime.compareTo(aTime); // Más reciente primero
                          });

                          return ListView.builder(
                            itemCount: docs.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              return AttendeeTile(attendance: data);
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botón cerrar sesión
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('sesiones')
                              .doc(_sesionId)
                              .update({'activa': false});
                          if (mounted) Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: GingaColors.brandGreen, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(GingaRadius.full),
                          ),
                        ),
                        child: Text('Cerrar sesión de clase',
                            style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                color: GingaColors.brandGreen)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Widget auxiliar para mostrar los alumnos registrados en vivo o en historial
class AttendeeTile extends StatelessWidget {
  final Map<String, dynamic> attendance;

  const AttendeeTile({super.key, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final String userId = attendance['user_id'] ?? '';
    final String? cachedName = attendance['user_name'];
    final String? cachedEmail = attendance['user_email'];
    final Timestamp? createdAt = attendance['created_at'] as Timestamp?;

    final String timeStr = createdAt != null 
        ? _formatTime(createdAt.toDate()) 
        : (attendance['hora'] ?? '');

    if (cachedName != null && cachedName.isNotEmpty) {
      return _buildTile(cachedName, cachedEmail ?? 'Sin correo', timeStr);
    }

    // Fallback para asistencias antiguas sin denormalización
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildTile('Cargando...', '...', timeStr);
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final name = userData['nombre'] ?? 'Sin nombre';
        final email = userData['email'] ?? 'Sin correo';
        return _buildTile(name, email, timeStr);
      },
    );
  }

  String _formatTime(DateTime dt) {
    // Formatear hora de forma local ej: 5:42 PM
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildTile(String name, String email, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: GingaColors.brandGreen.withOpacity(0.1),
            child: const Icon(Icons.person, color: GingaColors.brandGreen, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: GingaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: GingaColors.brandGreen,
            ),
          ),
        ],
      ),
    );
  }
}