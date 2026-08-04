import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/ginga_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isLoading = false;
  String? _mensaje;
  bool _exito = false;
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _procesarQR(String sesionId) async {
    if (_isLoading) return;

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
          _mensaje = 'Código QR inválido o la sesión ya fue cerrada.';
          _exito = false;
          _isLoading = false;
        });
        return;
      }

      // Obtener el estado del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final String userStatus = userDoc.exists ? (userDoc.data()?['status'] ?? 'nuevo') : 'nuevo';

      String? reservaDocId;

      if (userStatus != 'activo') {
        // Validar si el alumno tiene una reservación activa para esta clase
        final String claseId = sesionDoc['clase_id'] ?? '';
        final reservaSnapshot = await FirebaseFirestore.instance
            .collection('reservas')
            .where('user_id', isEqualTo: uid)
            .where('clase_id', isEqualTo: claseId)
            .where('status', isEqualTo: 'confirmado')
            .get();

        if (reservaSnapshot.docs.isEmpty) {
          setState(() {
            _mensaje = 'No tienes una reservación activa para esta clase. Reserva tu lugar primero.';
            _exito = false;
            _isLoading = false;
          });
          return;
        }
        reservaDocId = reservaSnapshot.docs.first.id;
      }

      final asistenciaExiste = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('sesion_id', isEqualTo: sesionId)
          .where('user_id', isEqualTo: uid)
          .get();

      if (asistenciaExiste.docs.isNotEmpty) {
        setState(() {
          _mensaje = '¡Ya registraste tu asistencia en esta sesión hoy!';
          _exito = true;
          _isLoading = false;
        });
        return;
      }

      final String userName = userDoc.exists ? (userDoc.data()?['nombre'] ?? 'Sin nombre') : 'Sin nombre';
      final String userEmail = userDoc.exists ? (userDoc.data()?['email'] ?? '') : '';

      await FirebaseFirestore.instance.collection('asistencias').add({
        'sesion_id': sesionId,
        'user_id': uid,
        'user_name': userName,
        'user_email': userEmail,
        'clase_id': sesionDoc['clase_id'],
        'nivel': sesionDoc['nivel'],
        'hora': sesionDoc['hora'],
        'fecha': sesionDoc['fecha'],
        'created_at': FieldValue.serverTimestamp(),
      });

      // Si tenía una reserva activa (era alumno de prueba/nuevo), marcar la reserva como asistida
      if (reservaDocId != null) {
        await FirebaseFirestore.instance
            .collection('reservas')
            .doc(reservaDocId)
            .update({'status': 'asistido'});
      }

      // Generar notificación en el buzón del usuario para activar el push real vía Cloud Function
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notificaciones')
            .add({
          'titulo': '¡Check-in exitoso! 🎉',
          'mensaje': 'Registraste tu asistencia a la clase de ${sesionDoc['nivel']} hoy a las ${sesionDoc['hora']}.',
          'fecha': FieldValue.serverTimestamp(),
          'leido': false,
          'tipo': 'asistencia',
        });
      } catch (notiError) {
        debugPrint('Error al guardar notificación en subcolección: $notiError');
      }

      setState(() {
        _mensaje = '¡Asistencia registrada con éxito! 🎉';
        _exito = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al registrar asistencia: $e');
      setState(() {
        _mensaje = 'Error al registrar asistencia. Intenta de nuevo.';
        _exito = false;
        _isLoading = false;
      });
    }
  }

  void _reiniciarEscaneo() {
    _controller.start();
    setState(() {
      _scanned = false;
      _mensaje = null;
      _isLoading = false;
    });
  }

  Widget _buildViewfinderOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Pintor de la máscara oscura con recorte en el centro
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: ScannerOverlayPainter(),
            ),
            // Indicaciones y botones de control
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Escanear QR',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  // Botón de Linterna (Flash)
                  IconButton(
                    icon: const Icon(Icons.flashlight_on, color: Colors.white),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                ],
              ),
            ),
            // Instrucción de uso debajo del recuadro
            Positioned(
              bottom: 120,
              left: 30,
              right: 30,
              child: Column(
                children: [
                  Text(
                    'Apunta al código QR del instructor',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mantén el código dentro del recuadro verde para escanear',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GingaColors.brandGreen),
            )
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
                            _exito ? Icons.check_circle : Icons.error_outline,
                            color: _exito ? GingaColors.brandGreen : Colors.red,
                            size: 80,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _mensaje ?? '',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.4),
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
                                  borderRadius: BorderRadius.circular(GingaRadius.full),
                                ),
                              ),
                              child: Text(
                                'Volver al Home',
                                style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                          if (!_exito) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _reiniciarEscaneo,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white70, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(GingaRadius.full),
                                  ),
                                ),
                                child: Text(
                                  'Volver a intentar',
                                  style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ),

                          ],
                        ],
                      ),
                    ),
                  ),
                )
              : SafeArea(
                  top: false,
                  bottom: false,
                  child: Stack(
                    children: [
                      // Componente de cámara viva de Mobile Scanner
                      MobileScanner(
                        controller: _controller,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            final String? code = barcode.rawValue;
                            if (code != null) {
                              _controller.stop();
                              _procesarQR(code);
                              break;
                            }
                          }
                        },
                      ),
                      // Máscara recortada y elementos interactivos por encima
                      _buildViewfinderOverlay(),
                    ],
                  ),
                ),
    );
  }
}

// Pintor personalizado para crear la mira de escaneo semitransparente
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    // Tamaño del cuadro del visor
    final cutoutSize = size.width * 0.62;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2.3; // Ligeramente elevado para dar espacio al texto

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
      const Radius.circular(20),
    );

    // Dibuja la máscara con el recorte en forma de RRect en el medio
    final path = Path()
      ..addRect(rect)
      ..addRRect(cutoutRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Pintar los bordes de la mira de escaneo
    final borderPaint = Paint()
      ..color = GingaColors.brandGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(cutoutRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}