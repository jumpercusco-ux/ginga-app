import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/ginga_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isLoading = false;
  String? _mensaje;
  bool _exito = false;
  bool _scanned = false;

  Future<void> _escanear() async {
    // En simulador no hay cámara — mostrar mensaje
    if (defaultTargetPlatform == TargetPlatform.iOS && !kReleaseMode) {
      setState(() {
        _mensaje = 'Cámara no disponible en simulador.\nUsa un iPhone físico.';
        _exito = false;
        _scanned = true;
      });
      return;
    }

    try {
      // ignore: depend_on_referenced_packages
      final dynamic scanner =
          await _scanQr();

      if (scanner == null || scanner == '-1') {
        if (mounted) Navigator.pop(context);
        return;
      }

      await _procesarQR(scanner);
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensaje = 'Error al escanear. Usa un dispositivo físico.';
          _exito = false;
          _scanned = true;
        });
      }
    }
  }

  Future<String?> _scanQr() async {
    try {
      // ignore: avoid_dynamic_calls
      final flutter_barcode_scanner =
          // ignore: unnecessary_import
          await Future.value(null);
      return flutter_barcode_scanner as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _procesarQR(String sesionId) async {
    setState(() {
      _isLoading = true;
      _scanned = true;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final sesionDoc = await FirebaseFirestore.instance
          .collection('sesiones')
          .doc(sesionId)
          .get();

      if (!sesionDoc.exists || sesionDoc['activa'] != true) {
        setState(() {
          _mensaje = 'QR inválido o sesión cerrada.';
          _exito = false;
          _isLoading = false;
        });
        return;
      }

      final asistenciaExiste = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('sesion_id', isEqualTo: sesionId)
          .where('user_id', isEqualTo: uid)
          .get();

      if (asistenciaExiste.docs.isNotEmpty) {
        setState(() {
          _mensaje = '¡Ya registraste tu asistencia hoy!';
          _exito = true;
          _isLoading = false;
        });
        return;
      }

      await FirebaseFirestore.instance.collection('asistencias').add({
        'sesion_id': sesionId,
        'user_id': uid,
        'clase_id': sesionDoc['clase_id'],
        'nivel': sesionDoc['nivel'],
        'hora': sesionDoc['hora'],
        'fecha': sesionDoc['fecha'],
        'created_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _mensaje = '¡Asistencia registrada! 🎉';
        _exito = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _mensaje = 'Error al registrar. Intenta de nuevo.';
        _exito = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Check-in QR',
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: GingaColors.brandGreen))
          : _scanned
              ? Container(
                  color: Colors.black87,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _exito
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color:
                                _exito ? GingaColors.brandGreen : Colors.red,
                            size: 80,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _mensaje ?? '',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GingaColors.brandGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      GingaRadius.full),
                                ),
                              ),
                              child: Text('Volver al Home',
                                  style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner,
                          color: GingaColors.brandGreen, size: 80),
                      const SizedBox(height: 24),
                      Text('Check-in de clase',
                          style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(
                        'Escanea el QR del instructor\npara registrar tu asistencia',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            fontSize: 14, color: Colors.white60),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _escanear,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(GingaRadius.full),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt,
                            color: Colors.white),
                        label: Text('Escanear QR',
                            style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
    );
  }
}