import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/ginga_theme.dart';

class InstructorPagosScreen extends StatefulWidget {
  const InstructorPagosScreen({super.key});

  @override
  State<InstructorPagosScreen> createState() => _InstructorPagosScreenState();
}

class _InstructorPagosScreenState extends State<InstructorPagosScreen> {
  // Función para enviar recordatorio de cobro por WhatsApp de forma nativa y robusta
  Future<void> _enviarRecordatorioWhatsApp(
      BuildContext context, String nombre, String telefono, String fechaFin, double plan) async {
    // Si no tiene teléfono configurado, mostramos una alerta
    if (telefono.isEmpty || telefono == 'Sin teléfono') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El alumno no tiene un número de teléfono registrado.',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Limpiar el teléfono para wa.me (debe incluir código de país, por defecto 51 para Perú si no tiene)
    String formattedPhone = telefono.replaceAll(RegExp(r'\D'), '');
    if (!formattedPhone.startsWith('51') && formattedPhone.length == 9) {
      formattedPhone = '51$formattedPhone';
    }

    final String message = 
        '🥋 *¡Hola $nombre! Te saluda el Prof. de Capoeira Ginga.*\n\n'
        'Te recordamos amigablemente que tu membresía académica de entrenamiento vence/venció el *$fechaFin*.\n\n'
        '💰 *Cuota de renovación:* S/ ${plan.toStringAsFixed(2)}\n'
        '📱 *Métodos sugeridos:* Yape / Plin al número de la academia o efectivo en clase.\n\n'
        'Cualquier duda me avisas para coordinar. ¡Muchísimas gracias y nos vemos en la Roda! ¡Axé! 🔥';

    final String url = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';

    try {
      final Uri uri = Uri.parse(url);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('WhatsApp lanzado correctamente');
      } else {
        throw 'No se pudo abrir la aplicación de WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo abrir WhatsApp automáticamente. Copia el mensaje o verifica la instalación.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Abre el modal rápido de registro de pago directo para un alumno moroso
  void _mostrarModalCobroRapido(BuildContext context, String uid, String nombre, Map<String, dynamic> alumnoData) {
    int mesesSeleccionados = 1;
    String metodoPagoSeleccionado = 'Yape';
    final List<String> metodosPago = ['Yape', 'Plin', 'Efectivo', 'Transferencia'];
    double montoCobrado = 120.0;
    
    DateTime fechaInicioMembresia = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom +
                      (MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom + 12
                          : 20),
                  left: 20,
                  right: 20,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Registrar Pago y Activar',
                        style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Alumno: $nombre',
                        style: GoogleFonts.nunito(
                            fontSize: 14, color: GingaColors.textSecondary)),
                    Divider(height: 24, color: GingaColors.borderLight),

                    Text('Meses a contratar:',
                        style: GoogleFonts.montserrat(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [1, 2, 3, 6, 12].map((mes) {
                        final isSelected = mesesSeleccionados == mes;
                        return GestureDetector(
                          onTap: () {
                            setStateModal(() {
                              mesesSeleccionados = mes;
                              montoCobrado = mes * 120.0; // Pre-sugerir monto
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? GingaColors.brandGreen : Colors.white,
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              border: Border.all(
                                  color: isSelected
                                      ? GingaColors.brandGreen
                                      : GingaColors.borderLight),
                            ),
                            child: Text('$mes',
                                style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : GingaColors.textPrimary)),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),
                    Text('Monto Cobrado (Soles S/):',
                        style: GoogleFonts.montserrat(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: 'S/ ',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          borderSide: BorderSide(color: GingaColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          borderSide: const BorderSide(color: GingaColors.brandGreen),
                        ),
                      ),
                      controller: TextEditingController(text: montoCobrado.toStringAsFixed(2))
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: montoCobrado.toStringAsFixed(2).length),
                        ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null) {
                          montoCobrado = parsed;
                        }
                      },
                    ),

                    const SizedBox(height: 18),
                    Text('Método de Pago:',
                        style: GoogleFonts.montserrat(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: metodoPagoSeleccionado,
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down, color: GingaColors.textSecondary),
                          style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary, fontWeight: FontWeight.w700),
                          items: metodosPago.map((metodo) {
                            return DropdownMenuItem<String>(
                              value: metodo,
                              child: Text(metodo),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateModal(() {
                                metodoPagoSeleccionado = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final fechaFin = DateTime(
                            fechaInicioMembresia.year,
                            fechaInicioMembresia.month + mesesSeleccionados,
                            fechaInicioMembresia.day,
                          );

                          // Mostrar carga
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(color: GingaColors.brandGreen),
                            ),
                          );

                          try {
                            final String fechaFinTexto = "${fechaFin.day}/${fechaFin.month}/${fechaFin.year}";

                            // 1. Registrar Pago en Firestore
                            await FirebaseFirestore.instance.collection('pagos').add({
                              'user_id': uid,
                              'user_name': nombre,
                              'user_sede': alumnoData['sede'] ?? 'Sin sede',
                              'monto': montoCobrado,
                              'moneda': 'PEN',
                              'meses_pagados': mesesSeleccionados,
                              'metodo_pago': metodoPagoSeleccionado,
                              'fecha_pago': FieldValue.serverTimestamp(),
                              'fecha_vencimiento': Timestamp.fromDate(fechaFin),
                              'estado': 'completado',
                              'registrado_por': FirebaseAuth.instance.currentUser?.uid,
                            });

                            // 2. Actualizar perfil del Alumno
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({
                              'status': 'activo',
                              'membresia_inicio': Timestamp.fromDate(fechaInicioMembresia),
                              'membresia_fin': Timestamp.fromDate(fechaFin),
                              'membresia_meses_pagados': mesesSeleccionados,
                            });

                            // 3. Crear notificación in-app para el alumno
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('notificaciones')
                                .add({
                              'titulo': '¡Membresía Activa! 🥋',
                              'mensaje': 'Recibimos tu pago de S/ ${montoCobrado.toStringAsFixed(2)} vía $metodoPagoSeleccionado. Tu membresía ha sido renovada hasta el $fechaFinTexto.',
                              'fecha': FieldValue.serverTimestamp(),
                              'leido': false,
                              'tipo': 'membresia',
                            });

                            // Cerrar diálogos
                            if (context.mounted) {
                              Navigator.pop(context); // Cierra loader
                              Navigator.pop(ctx); // Cierra modal
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '¡Membresía activada y pago registrado de S/ ${montoCobrado.toStringAsFixed(2)}! 🎉',
                                    style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: GingaColors.brandGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context); // Cierra loader
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error al registrar el pago: $e',
                                    style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Activar & Registrar Pago',
                          style: GoogleFonts.montserrat(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pagos').snapshots(),
        builder: (context, pagosSnapshot) {
          double totalMes = 0;
          double totalYape = 0;
          double totalPlin = 0;
          double totalEfectivo = 0;
          double totalTransf = 0;

          if (pagosSnapshot.hasData) {
            final ahora = DateTime.now();
            for (var doc in pagosSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['fecha_pago'] as Timestamp?;
              if (timestamp != null) {
                final fecha = timestamp.toDate();
                // Filtrar solo transacciones del mes actual
                if (fecha.month == ahora.month && fecha.year == ahora.year) {
                  final monto = (data['monto'] as num?)?.toDouble() ?? 0.0;
                  totalMes += monto;

                  final metodo = (data['metodo_pago'] as String?)?.toLowerCase() ?? '';
                  if (metodo.contains('yape')) {
                    totalYape += monto;
                  } else if (metodo.contains('plin')) {
                    totalPlin += monto;
                  } else if (metodo.contains('efectivo')) {
                    totalEfectivo += monto;
                  } else {
                    totalTransf += monto;
                  }
                }
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Header ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Finanzas y Pagos',
                            style: GoogleFonts.montserrat(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: GingaColors.textPrimary)),
                        Text('Control de cobros y caja',
                            style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: GingaColors.textSecondary)),
                      ],
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: GingaColors.brandGreen.withValues(alpha: 0.15),
                      child: const Icon(Icons.monetization_on, color: GingaColors.brandGreen, size: 22),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Tarjeta Gradiente de Caja Mensual ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GingaRadius.lg),
                    gradient: const LinearGradient(
                      colors: [GingaColors.brandGreen, Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: GingaColors.brandGreen.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECAUDACIÓN DE ESTE MES',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: totalMes),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            'S/ ${value.toStringAsFixed(2)}',
                            style: GoogleFonts.montserrat(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Desglose compacto de métodos
                       Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _DesgloseItem(label: '📱 Yape', value: totalYape),
                          _DesgloseItem(label: '⚡ Plin', value: totalPlin),
                          _DesgloseItem(label: '💵 Efec', value: totalEfectivo),
                          _DesgloseItem(label: '🏦 Trans', value: totalTransf),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Alertas de Vencimiento / Morosidad ──
                Text('Alertas de Cobro y Vencimiento ⚠️',
                    style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary)),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('rol', isEqualTo: 'alumno') // Solo alumnos
                      .snapshots(),
                  builder: (context, usersSnapshot) {
                    if (usersSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: GingaColors.brandGreen, strokeWidth: 2),
                        ),
                      );
                    }

                    final List<QueryDocumentSnapshot> alumnosMorosos = [];

                    if (usersSnapshot.hasData) {
                      final hoy = DateTime.now();
                      for (var doc in usersSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'] ?? 'nuevo';

                        // Alumnos inactivos o activos cuya membresía venza pronto (próximos 7 días)
                        if (status == 'inactivo') {
                          alumnosMorosos.add(doc);
                        } else if (status == 'activo' && data['membresia_fin'] != null) {
                          final fin = (data['membresia_fin'] as Timestamp).toDate();
                          final diasRestantes = fin.difference(hoy).inDays;
                          if (diasRestantes <= 7) {
                            alumnosMorosos.add(doc);
                          }
                        }
                      }
                    }

                    if (alumnosMorosos.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        child: Center(
                          child: Text(
                            '¡Excelente! Todos tus alumnos están al día con sus pagos. 🎉',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: GingaColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: alumnosMorosos.length,
                      itemBuilder: (context, index) {
                        final doc = alumnosMorosos[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final nombre = data['nombre'] ?? 'Sin nombre';
                        final status = data['status'] ?? 'nuevo';
                        final telefono = data['telefono'] ?? '';
                        final finTimestamp = data['membresia_fin'] as Timestamp?;
                        final finDate = finTimestamp?.toDate();
                        
                        String fechaTexto = 'Sin registro';
                        String estadoAlerta = 'NUEVO';
                        Color alertaColor = Colors.blue;

                        if (status == 'inactivo') {
                          estadoAlerta = 'VENCIDO';
                          alertaColor = Colors.red;
                          if (finDate != null) {
                            fechaTexto = 'Venció: ${finDate.day}/${finDate.month}/${finDate.year}';
                          }
                        } else if (status == 'activo' && finDate != null) {
                          estadoAlerta = 'POR VENCER';
                          alertaColor = Colors.orange;
                          fechaTexto = 'Vence: ${finDate.day}/${finDate.month}/${finDate.year}';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(GingaRadius.lg),
                            border: Border.all(color: GingaColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: alertaColor.withValues(alpha: 0.1),
                                child: Icon(Icons.warning_amber_rounded, color: alertaColor, size: 18),
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
                                      fechaTexto,
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        color: GingaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: alertaColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  estadoAlerta,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: alertaColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Botón de WhatsApp
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.comment_outlined, color: Colors.green, size: 18),
                                onPressed: () {
                                  final fechaTextoForm = finDate != null 
                                      ? '${finDate.day}/${finDate.month}/${finDate.year}'
                                      : 'su fecha programada';
                                  _enviarRecordatorioWhatsApp(context, nombre, telefono, fechaTextoForm, 120.0);
                                },
                              ),
                              // Botón de Cobrar
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.monetization_on, color: GingaColors.brandGreen, size: 20),
                                onPressed: () => _mostrarModalCobroRapido(context, doc.id, nombre, data),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Historial de Transacciones Recientes ──
                Text('Historial de Transacciones 🧾',
                    style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary)),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('pagos')
                      .orderBy('fecha_pago', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: GingaColors.brandGreen),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        child: Center(
                          child: Text(
                            'Aún no has registrado transacciones en esta academia.',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: GingaColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String pagoId = doc.id;
                        final String userId = data['user_id'] ?? '';
                        final String nombreOriginal = data['user_name'] ?? 'Alumno';
                        final monto = (data['monto'] as num?)?.toDouble() ?? 0.0;
                        final metodo = data['metodo_pago'] ?? 'Yape';
                        final timestamp = data['fecha_pago'] as Timestamp?;
                        final date = timestamp?.toDate();
                        final String dateStr = date != null ? '${date.day}/${date.month}' : '';

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                          builder: (context, userSnap) {
                            bool isDeBaja = false;
                            if (userSnap.hasData && userSnap.data!.exists) {
                              final uData = userSnap.data!.data() as Map<String, dynamic>;
                              isDeBaja = uData['status'] == 'eliminado';
                            }

                            final String displayName = isDeBaja ? '$nombreOriginal (De Baja 📂)' : nombreOriginal;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(GingaRadius.lg),
                                border: Border.all(color: GingaColors.borderLight),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: GingaColors.brandGreen.withValues(alpha: 0.1),
                                          child: const Icon(Icons.payment, color: GingaColors.brandGreen, size: 14),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDeBaja ? Colors.redAccent : GingaColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Método: $metodo • $dateStr',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 10,
                                                  color: GingaColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '+ S/ ${monto.toStringAsFixed(2)}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: GingaColors.brandGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, size: 16, color: GingaColors.textSecondary),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _editarPagoModal(context, pagoId, data),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _confirmarEliminarPago(context, pagoId, nombreOriginal, monto),
                                      ),
                                    ],
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

                const SizedBox(height: 36),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmarEliminarPago(BuildContext context, String pagoId, String alumno, double monto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.lg)),
        title: Text(
          'Eliminar Transacción 🗑️',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: GingaColors.textPrimary),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente el registro de pago de S/ ${monto.toStringAsFixed(2)} para $alumno?\n\nEsta acción recalculará la caja mensual al instante y no se puede deshacer.',
          style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.montserrat(color: GingaColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('pagos').doc(pagoId).delete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transacción eliminada con éxito 🎉', style: GoogleFonts.nunito(color: Colors.white)),
                      backgroundColor: GingaColors.brandGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar transacción: $e', style: GoogleFonts.nunito(color: Colors.white)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Eliminar',
              style: GoogleFonts.montserrat(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _editarPagoModal(BuildContext context, String pagoId, Map<String, dynamic> pagoData) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final double originalMonto = (pagoData['monto'] as num?)?.toDouble() ?? 0.0;
    final String originalMetodo = pagoData['metodo_pago'] ?? 'Yape';
    final Timestamp? originalTs = pagoData['fecha_pago'] as Timestamp?;
    final DateTime originalDate = originalTs?.toDate() ?? DateTime.now();

    final TextEditingController montoController = TextEditingController(text: originalMonto.toString());
    String selectedMetodo = originalMetodo;
    DateTime selectedDate = originalDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Editar Transacción ✏️',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Alumno: ${pagoData['user_name'] ?? 'Alumno'}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Monto
                    Text(
                      'Monto Cobrado (S/)',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: montoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Ej. 120.00',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          borderSide: BorderSide(color: GingaColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          borderSide: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Método de pago
                    Text(
                      'Método de Pago',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMetodo,
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: GingaColors.textSecondary),
                          items: ['Yape', 'Plin', 'Efectivo', 'Transferencia'].map((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text(
                                val,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w600,
                                  color: GingaColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedMetodo = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Fecha
                    Text(
                      'Fecha de Pago',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: GingaColors.brandGreen,
                                  onPrimary: Colors.white,
                                  onSurface: GingaColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          if (!context.mounted) return;
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (pickedTime != null) {
                            setModalState(() {
                              selectedDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} ${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w600,
                                color: GingaColors.textPrimary,
                              ),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: GingaColors.brandGreen),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botones de Acción
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.full)),
                              minimumSize: const Size(0, 48),
                            ),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: GingaColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final double? nuevoMonto = double.tryParse(montoController.text);
                              if (nuevoMonto == null || nuevoMonto <= 0) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Por favor, ingresa un monto válido', style: GoogleFonts.nunito(color: Colors.white)),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(context);
                              try {
                                await FirebaseFirestore.instance.collection('pagos').doc(pagoId).update({
                                  'monto': nuevoMonto,
                                  'metodo_pago': selectedMetodo,
                                  'fecha_pago': Timestamp.fromDate(selectedDate),
                                });

                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Transacción actualizada con éxito 🎉', style: GoogleFonts.nunito(color: Colors.white)),
                                    backgroundColor: GingaColors.brandGreen,
                                  ),
                                );
                              } catch (e) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Error al actualizar: $e', style: GoogleFonts.nunito(color: Colors.white)),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GingaColors.brandGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.full)),
                              minimumSize: const Size(0, 48),
                              elevation: 0,
                            ),
                            child: Text(
                              'Guardar Cambios',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
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
            );
          },
        );
      },
    );
  }
}

class _DesgloseItem extends StatelessWidget {
  final String label;
  final double value;

  const _DesgloseItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 2),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, animatedVal, child) {
            return Text(
              'S/ ${animatedVal.toStringAsFixed(0)}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            );
          },
        ),
      ],
    );
  }
}
