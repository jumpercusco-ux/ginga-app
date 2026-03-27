import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    setState(() {
      _sesionId = sesionRef.id;
      _isLoading = false;
    });

    FirebaseFirestore.instance
        .collection('asistencias')
        .where('sesion_id', isEqualTo: sesionRef.id)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _asistencias = snap.docs.length);
    });
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
              child: CircularProgressIndicator(color: GingaColors.brandGreen))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Info clase
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: GingaColors.cardLight,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                      ),
                      child: Column(
                        children: [
                          Text(widget.nivel,
                              style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: GingaColors.textPrimary)),
                          Text(widget.hora,
                              style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  color: GingaColors.textSecondary)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // QR Placeholder
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.qr_code,
                              size: 160, color: GingaColors.brandGreen),
                          const SizedBox(height: 8),
                          Text(
                            _sesionId ?? '',
                            style: GoogleFonts.nunito(
                                fontSize: 10,
                                color: GingaColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text('Muestra este QR a tus alumnos',
                        style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: GingaColors.textSecondary)),

                    const SizedBox(height: 32),

                    // Contador asistencias
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: GingaColors.brandGreen,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                      ),
                      child: Column(
                        children: [
                          Text('$_asistencias',
                              style: GoogleFonts.montserrat(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text('alumnos registrados',
                              style: GoogleFonts.nunito(
                                  fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ),

                    const Spacer(),

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