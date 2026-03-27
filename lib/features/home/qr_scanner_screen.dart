// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../../core/theme/ginga_theme.dart';

// class QrScannerScreen extends StatefulWidget {
//   const QrScannerScreen({super.key});

//   @override
//   State<QrScannerScreen> createState() => _QrScannerScreenState();
// }

// class _QrScannerScreenState extends State<QrScannerScreen> {
//   bool _scanned = false;
//   bool _isLoading = false;
//   String? _mensaje;
//   bool _exito = false;
//   final MobileScannerController _controller = MobileScannerController();

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   Future<void> _procesarQR(String sesionId) async {
//     if (_scanned || _isLoading) return;

//     setState(() {
//       _scanned = true;
//       _isLoading = true;
//     });

//     _controller.stop();

//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) return;

//     try {
//       // Verifica que la sesión existe y está activa
//       final sesionDoc = await FirebaseFirestore.instance
//           .collection('sesiones')
//           .doc(sesionId)
//           .get();

//       if (!sesionDoc.exists || sesionDoc['activa'] != true) {
//         setState(() {
//           _mensaje = 'QR inválido o sesión cerrada.';
//           _exito = false;
//           _isLoading = false;
//         });
//         return;
//       }

//       // Verifica si ya registró asistencia
//       final asistenciaExiste = await FirebaseFirestore.instance
//           .collection('asistencias')
//           .where('sesion_id', isEqualTo: sesionId)
//           .where('user_id', isEqualTo: uid)
//           .get();

//       if (asistenciaExiste.docs.isNotEmpty) {
//         setState(() {
//           _mensaje = '¡Ya registraste tu asistencia hoy!';
//           _exito = true;
//           _isLoading = false;
//         });
//         return;
//       }

//       // Registra la asistencia
//       await FirebaseFirestore.instance.collection('asistencias').add({
//         'sesion_id': sesionId,
//         'user_id': uid,
//         'clase_id': sesionDoc['clase_id'],
//         'nivel': sesionDoc['nivel'],
//         'hora': sesionDoc['hora'],
//         'fecha': sesionDoc['fecha'],
//         'created_at': FieldValue.serverTimestamp(),
//       });

//       setState(() {
//         _mensaje = '¡Asistencia registrada! 🎉';
//         _exito = true;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _mensaje = 'Error al registrar. Intenta de nuevo.';
//         _exito = false;
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text('Check-in QR',
//             style: GoogleFonts.montserrat(
//                 fontWeight: FontWeight.w700, color: Colors.white)),
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: Stack(
//         children: [
//           // Cámara
//           if (!_scanned)
//             MobileScanner(
//               controller: _controller,
//               onDetect: (capture) {
//                 final barcodes = capture.barcodes;
//                 if (barcodes.isNotEmpty) {
//                   final value = barcodes.first.rawValue;
//                   if (value != null) _procesarQR(value);
//                 }
//               },
//             ),

//           // Overlay con marco
//           if (!_scanned)
//             Center(
//               child: Container(
//                 width: 250,
//                 height: 250,
//                 decoration: BoxDecoration(
//                   border: Border.all(
//                       color: GingaColors.brandGreen, width: 3),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.all(12),
//                       child: Text(
//                         'Apunta al QR del instructor',
//                         textAlign: TextAlign.center,
//                         style: GoogleFonts.nunito(
//                             color: Colors.white, fontSize: 13),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//           // Loading
//           if (_isLoading)
//             Container(
//               color: Colors.black54,
//               child: const Center(
//                 child: CircularProgressIndicator(
//                     color: GingaColors.brandGreen),
//               ),
//             ),

//           // Resultado
//           if (_scanned && !_isLoading && _mensaje != null)
//             Container(
//               color: Colors.black87,
//               child: Center(
//                 child: Padding(
//                   padding: const EdgeInsets.all(32),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(
//                         _exito
//                             ? Icons.check_circle
//                             : Icons.error_outline,
//                         color: _exito
//                             ? GingaColors.brandGreen
//                             : Colors.red,
//                         size: 80,
//                       ),
//                       const SizedBox(height: 24),
//                       Text(
//                         _mensaje!,
//                         textAlign: TextAlign.center,
//                         style: GoogleFonts.montserrat(
//                           fontSize: 22,
//                           fontWeight: FontWeight.w800,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 40),
//                       SizedBox(
//                         width: double.infinity,
//                         height: 52,
//                         child: ElevatedButton(
//                           onPressed: () => Navigator.pop(context),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: GingaColors.brandGreen,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(
//                                   GingaRadius.full),
//                             ),
//                           ),
//                           child: Text('Volver al Home',
//                               style: GoogleFonts.montserrat(
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.white)),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Check-in QR',
            style: GoogleFonts.montserrat(color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner,
                color: GingaColors.brandGreen, size: 80),
            const SizedBox(height: 16),
            Text('Scanner disponible en dispositivo físico',
                style: GoogleFonts.montserrat(
                    color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}