import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/models/cuerdas_fiu.dart';

class InstructorAlumnosScreen extends StatefulWidget {
  const InstructorAlumnosScreen({super.key});

  @override
  State<InstructorAlumnosScreen> createState() => _InstructorAlumnosScreenState();
}

class _InstructorAlumnosScreenState extends State<InstructorAlumnosScreen> {
  String _searchQuery = '';
  String _selectedSedeFilter = 'Todos';
  final List<String> _sedes = ['Todos', 'Virtual / A Distancia', 'Lima', 'Cusco', 'U. Continental', 'Chimbote'];
  String _selectedStatusFilter = 'Todos';
  final List<String> _statuses = ['Todos', 'Activo', 'Nuevo', 'Prueba', 'Inactivo'];

  // Función para construir cada fila informativa de la Ficha
  Widget _buildFichaRow(IconData icon, String label, String value, {bool isAlert = false, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isAlert ? Colors.red : GingaColors.brandGreen),
          const SizedBox(width: 10),
          Text('$label: ', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: GingaColors.textSecondary)),
          Expanded(
            child: Text(
              value, 
              style: GoogleFonts.montserrat(
                fontSize: 13, 
                fontWeight: FontWeight.w700, 
                color: isAlert ? Colors.red : GingaColors.textPrimary
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            suffix,
          ],
        ],
      ),
    );
  }

  // Modal para ver la Ficha Detallada del Alumno (disponible en todos los estados) - Con Scroll para evitar Overflows
  void _mostrarFichaAlumno(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] ?? 'nuevo';
    final userSede = data['sede'] ?? 'Sin sede';
    final corda = data['corda'] ?? 'Crua';
    final email = data['email'] ?? 'Sin correo';
    final String? fotoUrl = data['foto_url'];
    final created = data['created_at'] != null 
        ? (data['created_at'] as Timestamp).toDate()
        : null;
    final inicio = data['membresia_inicio'] != null
        ? (data['membresia_inicio'] as Timestamp).toDate()
        : null;
    final fin = data['membresia_fin'] != null
        ? (data['membresia_fin'] as Timestamp).toDate()
        : null;
    final meses = data['membresia_meses_pagados'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Habilita crecimiento dinámico de la hoja
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85, // Límite de alto para no comerse la pantalla
          ),
          child: SingleChildScrollView( // Scroll de seguridad para pantallas pequeñas
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con avatar y estado
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: status == 'activo'
                          ? GingaColors.brandGreen.withOpacity(0.15)
                          : status == 'prueba'
                              ? GingaColors.accentAmber.withOpacity(0.15)
                              : status == 'nuevo'
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                      backgroundImage: fotoUrl != null && fotoUrl!.isNotEmpty
                          ? NetworkImage(fotoUrl!)
                          : null,
                      child: fotoUrl != null && fotoUrl!.isNotEmpty
                          ? null
                          : Icon(
                              Icons.person,
                              size: 32,
                              color: status == 'activo'
                                  ? GingaColors.brandGreen
                                  : status == 'prueba'
                                      ? GingaColors.accentAmber
                                      : status == 'nuevo'
                                          ? Colors.blue
                                          : Colors.red,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['nombre'] ?? 'Sin nombre',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: GingaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: status == 'activo'
                                  ? GingaColors.brandGreen.withOpacity(0.15)
                                  : status == 'prueba'
                                      ? GingaColors.accentAmber.withOpacity(0.15)
                                      : status == 'nuevo'
                                          ? Colors.blue.withOpacity(0.15)
                                          : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: status == 'activo'
                                    ? GingaColors.brandGreen
                                    : status == 'prueba'
                                        ? GingaColors.accentAmber
                                        : status == 'nuevo'
                                            ? Colors.blue
                                            : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32, color: GingaColors.borderLight),

                // Datos Personales
                Text('Información Académica y de Contacto',
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: GingaColors.textSecondary)),
                const SizedBox(height: 12),
                
                _buildFichaRow(Icons.email_outlined, 'Correo electrónico', email),
                _buildFichaRow(Icons.location_on_outlined, 'Sede asignada', userSede),
                _buildFichaRow(
                  Icons.sports_kabaddi_outlined, 
                  'Corda / Nivel', 
                  corda,
                  suffix: GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Cierra la ficha actual
                      _mostrarModalPromocionCorda(context, data, data['uid'] ?? '');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: GingaColors.brandGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: GingaColors.brandGreen,
                      ),
                    ),
                  ),
                ),
                if (created != null)
                  _buildFichaRow(Icons.calendar_today_outlined, 'Fecha de registro', '${created.day}/${created.month}/${created.year}'),

                const Divider(height: 32, color: GingaColors.borderLight),

                // Detalles de Membresía
                Text('Detalles de Membresía',
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: GingaColors.textSecondary)),
                const SizedBox(height: 12),

                if (status == 'activo' || status == 'inactivo') ...[
                  if (inicio != null && fin != null) ...[
                    _buildFichaRow(Icons.play_circle_outline, 'Inicio de membresía', '${inicio.day}/${inicio.month}/${inicio.year}'),
                    _buildFichaRow(Icons.error_outline, 'Vencimiento de membresía', '${fin.day}/${fin.month}/${fin.year}', isAlert: status == 'inactivo'),
                    _buildFichaRow(Icons.payment_outlined, 'Meses contratados', '$meses ${meses == 1 ? 'mes' : 'meses'}'),
                  ] else
                    Text('No hay registros de fechas de membresía.', style: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textSecondary)),
                ] else
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: GingaColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        status == 'nuevo' 
                            ? 'Alumno recién registrado sin membresía.' 
                            : 'Alumno en periodo de prueba gratuita.',
                        style: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textSecondary),
                      ),
                    ],
                  ),

                const Divider(height: 32, color: GingaColors.borderLight),

                _FichaAsistenciasCalendar(uid: data['uid'] ?? ''),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _registrarAsistenciaRetroactiva(context, data);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GingaColors.brandGreen,
                      side: const BorderSide(color: GingaColors.brandGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      'Registrar Asistencia Manual',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modal para Activar/Gestionar/Renovar la Membresía - Con Scroll y resguardo de teclado para evitar Overflows
  void _mostrarModalActivacion(BuildContext context, Map<String, dynamic> data, String uid) {
    int mesesSeleccionados = 1;
    String? claseSeleccionadaId;
    bool isClassesLoaded = false;
    List<QueryDocumentSnapshot> clasesList = [];
    
    // Variables para el control de pago unificado
    String metodoPagoSeleccionado = 'Yape';
    final List<String> metodosPago = ['Yape', 'Plin', 'Efectivo', 'Transferencia'];
    double montoCobrado = 120.0;
    
    // Si el alumno ya está activo y tiene vencimiento en el futuro, sugerimos encadenar la fecha de inicio desde su vencimiento actual para evitar pérdida de días
    DateTime fechaInicioMembresia = DateTime.now();
    if (data['status'] == 'activo' && data['membresia_fin'] != null) {
      final DateTime finActual = (data['membresia_fin'] as Timestamp).toDate();
      if (finActual.isAfter(DateTime.now())) {
        fechaInicioMembresia = finActual;
      }
    }

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
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('clases').get(),
              builder: (context, classesSnapshot) {
                if (classesSnapshot.hasData && !isClassesLoaded) {
                  clasesList = classesSnapshot.data!.docs;
                  isClassesLoaded = true;
                  
                  // Intentar pre-seleccionar si el usuario ya tiene una clase asignada
                  claseSeleccionadaId = data['clase_id'];
                }

                final isRenewing = data['status'] == 'activo';

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85, // Resguardo contra overflows
                  ),
                  child: SingleChildScrollView( // Scrollable para soportar teclados y pantallas pequeñas
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
                        Text(isRenewing ? 'Gestionar / Renovar Membresía' : 'Activar Membresía',
                            style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: GingaColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text('Alumno: ${data['nombre'] ?? 'Sin nombre'}',
                            style: GoogleFonts.nunito(
                                fontSize: 16, color: GingaColors.textSecondary)),
                        
                        const SizedBox(height: 20),
                        Text('Asignar Clase regular:',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        
                        if (classesSnapshot.connectionState == ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
                        else if (clasesList.isEmpty)
                          Text('No hay clases creadas en la base de datos.',
                              style: GoogleFonts.nunito(fontSize: 13, color: Colors.red))
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              border: Border.all(color: GingaColors.borderLight),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: claseSeleccionadaId,
                                hint: Text('Selecciona una clase regular', style: GoogleFonts.nunito(fontSize: 13)),
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, color: GingaColors.textSecondary),
                                style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                                items: clasesList.map((doc) {
                                  final cData = doc.data() as Map<String, dynamic>;
                                  final nombre = cData['nombre'] ?? 'Sin nombre';
                                  final nivel = cData['nivel'] ?? '';
                                  final dias = cData['dias'] ?? '';
                                  final hora = cData['hora'] ?? '';
                                  return DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text('$nombre - $nivel ($dias $hora)'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setStateModal(() {
                                    claseSeleccionadaId = val;
                                  });
                                },
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),
                        Text('Fecha de Inicio:',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: fechaInicioMembresia,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)), // hasta 1 año en el pasado
                              lastDate: DateTime.now().add(const Duration(days: 365)), // hasta 1 año en el futuro
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(primary: GingaColors.brandGreen),
                                ),
                                child: child!,
                              ),
                            );
                            if (selected != null) {
                              setStateModal(() {
                                fechaInicioMembresia = selected;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              border: Border.all(color: GingaColors.borderLight),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${fechaInicioMembresia.day}/${fechaInicioMembresia.month}/${fechaInicioMembresia.year}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.textPrimary,
                                  ),
                                ),
                                const Icon(Icons.calendar_today_rounded, size: 18, color: GingaColors.brandGreen),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Text('Meses a contratar:',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [1, 2, 3, 6, 12].map((mes) {
                            final isSelected = mesesSeleccionados == mes;
                            return GestureDetector(
                              onTap: () {
                                setStateModal(() {
                                  mesesSeleccionados = mes;
                                  montoCobrado = mes * 120.0;
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
                        
                        const SizedBox(height: 20),
                        Text('Monto Cobrado (Soles S/):',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600)),
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
                              borderSide: const BorderSide(color: GingaColors.borderLight),
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

                        const SizedBox(height: 20),
                        Text('Método de Pago:',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600)),
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
                              icon: const Icon(Icons.keyboard_arrow_down, color: GingaColors.textSecondary),
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

                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final fechaFin = DateTime(
                                fechaInicioMembresia.year,
                                fechaInicioMembresia.month + mesesSeleccionados,
                                fechaInicioMembresia.day,
                              );

                              try {
                                // Buscar si el alumno tiene alguna reservación si no seleccionó clase manual
                                String? finalClaseId = claseSeleccionadaId;
                                if (finalClaseId == null) {
                                  final reservasQuery = await FirebaseFirestore.instance
                                      .collection('reservas')
                                      .where('user_id', isEqualTo: uid)
                                      .get();
                                  if (reservasQuery.docs.isNotEmpty) {
                                    finalClaseId = reservasQuery.docs.first['clase_id'];
                                  }
                                }

                                final Map<String, dynamic> updateData = {
                                  'status': 'activo',
                                  'membresia_inicio': Timestamp.fromDate(fechaInicioMembresia),
                                  'membresia_fin': Timestamp.fromDate(fechaFin),
                                  'membresia_meses_pagados': mesesSeleccionados,
                                };

                                if (finalClaseId != null) {
                                  updateData['clase_id'] = finalClaseId;
                                  
                                  // Auto-sincronizar la sede del alumno con la sede/nombre de la clase asignada
                                  try {
                                    final claseDoc = await FirebaseFirestore.instance
                                        .collection('clases')
                                        .doc(finalClaseId)
                                        .get();
                                    if (claseDoc.exists) {
                                      final claseData = claseDoc.data() ?? {};
                                      final claseSede = claseData['sede']; // ej: "Cusco", "Lima"
                                      final claseNombre = claseData['nombre']; // ej: "Kids", "Adultos"
                                      if (claseSede != null && claseSede.toString().isNotEmpty) {
                                        updateData['sede'] = claseSede.toString();
                                      } else if (claseNombre != null && claseNombre.toString().isNotEmpty) {
                                        updateData['sede'] = claseNombre.toString();
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint('Error al auto-obtener la sede de la clase: $e');
                                  }
                                }

                                await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .update(updateData);

                                 // Registrar la transacción contable en la colección /pagos
                                 await FirebaseFirestore.instance.collection('pagos').add({
                                   'user_id': uid,
                                   'user_name': data['nombre'] ?? 'Sin nombre',
                                   'user_sede': data['sede'] ?? 'Sin sede',
                                   'monto': montoCobrado,
                                   'moneda': 'PEN',
                                   'meses_pagados': mesesSeleccionados,
                                   'metodo_pago': metodoPagoSeleccionado,
                                   'fecha_pago': FieldValue.serverTimestamp(),
                                   'fecha_vencimiento': Timestamp.fromDate(fechaFin),
                                   'estado': 'completado',
                                   'registrado_por': FirebaseAuth.instance.currentUser?.uid,
                                 });

                                // Generar notificación en el buzón del alumno
                                try {
                                  final fechaFinTexto = "${fechaFin.day}/${fechaFin.month}/${fechaFin.year}";
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(uid)
                                      .collection('notificaciones')
                                      .add({
                                    'titulo': isRenewing ? '¡Membresía Renovada! 🥋' : '¡Membresía Activa! 🥋',
                                    'mensaje': isRenewing 
                                        ? '¡Tu membresía ha sido renovada con éxito! Tu nuevo vencimiento es el $fechaFinTexto.'
                                        : '¡Tu acceso regular a la sede ha sido activado! Vence el $fechaFinTexto. ¡Nos vemos en la Roda!',
                                    'fecha': FieldValue.serverTimestamp(),
                                    'leido': false,
                                    'tipo': 'membresia',
                                  });
                                } catch (notiError) {
                                  debugPrint('Error al guardar notificación de membresía: $notiError');
                                }
                                
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(isRenewing 
                                          ? 'Membresía renovada con éxito 🎉'
                                          : 'Alumno activado y clase asociada con éxito 🎉'),
                                      backgroundColor: GingaColors.brandGreen,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al procesar membresía: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GingaColors.brandGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                              ),
                              elevation: 2,
                            ),
                            child: Text(isRenewing ? 'Confirmar Renovación' : 'Confirmar Activación',
                                style: GoogleFonts.montserrat(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Modal para actualizar y promover la cuerda/rango del Alumno
  void _mostrarModalPromocionCorda(BuildContext context, Map<String, dynamic> data, String uid) {
    final String currentCorda = data['corda'] ?? 'Sin cuerda';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                (MediaQuery.of(ctx).padding.bottom > 0
                    ? MediaQuery.of(ctx).padding.bottom + 12
                    : 20),
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Promover Graduación 🎓',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Alumno: ${data['nombre'] ?? 'Sin nombre'}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: GingaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: GingaColors.brandGreen,
                    ),
                    children: [
                      const TextSpan(text: 'Cuerda Actual: '),
                      TextSpan(
                        text: currentCorda.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: GingaColors.brandGreen),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona el nuevo nivel o cuerda:',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: GingaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: CuerdasFIU.lista.length,
                  itemBuilder: (context, index) {
                    final corda = CuerdasFIU.lista[index];
                    
                    final isCurrent = currentCorda.toLowerCase().contains(corda.nombre.toLowerCase()) || 
                                     currentCorda.toLowerCase().contains(corda.rango.toLowerCase()) ||
                                     (currentCorda.toLowerCase() == 'iniciante' && corda.nombre.toLowerCase() == 'crua');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({'corda': corda.nombre});

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('¡${data['nombre'] ?? 'Alumno'} promovido a Cuerda ${corda.nombre}! 🌟'),
                                  backgroundColor: GingaColors.brandGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error al actualizar graduación: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent ? GingaColors.brandGreen.withOpacity(0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(
                              color: isCurrent ? GingaColors.brandGreen : GingaColors.borderLight,
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Mini Cuerda Visual
                              Container(
                                width: 44,
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 1.5,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: corda.esMixta
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                color: corda.colores[0],
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                color: corda.colores[1],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: corda.colores,
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cuerda ${corda.nombre}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: GingaColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      corda.rango,
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        color: GingaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: GingaColors.brandGreen,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gestión de Alumnos',
                    style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary)),
                Text('Administra el perfil, fichas y membresías de tus alumnos',
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: GingaColors.textSecondary)),
              ],
            ),
          ),
          
          // Controles de Búsqueda y Filtros de Sede/Estado Premium
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                // 1. Buscador por nombre (Ancho completo)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre...',
                      hintStyle: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: GingaColors.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                
                // 2. Filtros de Sede y Estado (Lado a lado)
                Row(
                  children: [
                    // Filtro Sede
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSedeFilter,
                            icon: const Icon(Icons.location_on_outlined, size: 16, color: GingaColors.brandGreen),
                            isExpanded: true,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary,
                            ),
                            items: _sedes.map((sede) {
                              return DropdownMenuItem<String>(
                                value: sede,
                                child: Text(sede),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSedeFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Filtro Estado
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatusFilter,
                            icon: const Icon(Icons.tune, size: 16, color: GingaColors.brandGreen),
                            isExpanded: true,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary,
                            ),
                            items: _statuses.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStatusFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('rol', isEqualTo: 'alumno')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: GingaColors.brandGreen),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No hay alumnos registrados',
                        style: GoogleFonts.nunito(color: GingaColors.textSecondary)),
                  );
                }

                // Filtrar alumnos client-side por nombre, sede y estado
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final sede = (data['sede'] ?? '').toString();
                  final status = (data['status'] ?? '').toString();

                  final matchesSearch = nombre.contains(_searchQuery.toLowerCase());
                  final matchesSede = _selectedSedeFilter == 'Todos' || sede == _selectedSedeFilter;
                  final matchesStatus = _selectedStatusFilter == 'Todos' || status.toLowerCase() == _selectedStatusFilter.toLowerCase();

                  return matchesSearch && matchesSede && matchesStatus;
                }).toList();

                // Ordenar alumnos por fecha de creación (los más nuevos arriba)
                filteredDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  final aTime = aData['created_at'] as Timestamp?;
                  final bTime = bData['created_at'] as Timestamp?;
                  
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1; // Nulos abajo
                  if (bTime == null) return -1;
                  
                  return bTime.compareTo(aTime);
                });

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('No se encontraron alumnos con los filtros seleccionados',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(color: GingaColors.textSecondary)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'desconocido';
                    final userSede = data['sede'] ?? 'Sin sede';
                    final String? fotoUrl = data['foto_url'];

                    return GestureDetector(
                      onTap: () {
                        final Map<String, dynamic> dataWithUid = Map.from(data);
                        dataWithUid['uid'] = doc.id;
                        _mostrarFichaAlumno(context, dataWithUid);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: status == 'activo'
                                  ? GingaColors.brandGreen.withOpacity(0.2)
                                  : status == 'prueba'
                                      ? GingaColors.accentAmber.withOpacity(0.2)
                                      : status == 'nuevo'
                                          ? Colors.blue.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                              backgroundImage: fotoUrl != null && fotoUrl!.isNotEmpty
                                  ? NetworkImage(fotoUrl!)
                                  : null,
                              child: fotoUrl != null && fotoUrl!.isNotEmpty
                                  ? null
                                  : Icon(
                                      Icons.person,
                                      color: status == 'activo'
                                          ? GingaColors.brandGreen
                                          : status == 'prueba'
                                              ? GingaColors.accentAmber
                                              : status == 'nuevo'
                                                  ? Colors.blue
                                                  : Colors.red,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['nombre'] ?? 'Sin nombre',
                                      style: GoogleFonts.montserrat(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: GingaColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: status == 'activo'
                                              ? GingaColors.brandGreen.withOpacity(0.15)
                                              : status == 'prueba'
                                                  ? GingaColors.accentAmber.withOpacity(0.15)
                                                  : status == 'nuevo'
                                                      ? Colors.blue.withOpacity(0.15)
                                                      : Colors.red.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(status.toUpperCase(),
                                            style: GoogleFonts.nunito(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: status == 'activo'
                                                    ? GingaColors.brandGreen
                                                    : status == 'prueba'
                                                        ? GingaColors.accentAmber
                                                        : status == 'nuevo'
                                                            ? Colors.blue
                                                            : Colors.red)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('•  $userSede',
                                          style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: GingaColors.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _mostrarModalActivacion(context, data, doc.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: status == 'activo'
                                    ? Colors.blueGrey
                                    : GingaColors.brandGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: Text(status == 'activo' ? 'Gestionar' : (status == 'inactivo' ? 'Renovar' : 'Activar'),
                                  style: GoogleFonts.montserrat(
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarAsistenciaRetroactiva(BuildContext context, Map<String, dynamic> userData) async {
    final String userUid = userData['uid'] ?? '';
    if (userUid.isEmpty) return;

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: GingaColors.brandGreen,
              onPrimary: Colors.white,
              onSurface: GingaColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada == null) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: GingaColors.brandGreen),
      ),
    );

    try {
      final String fechaStr = '${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}';

      // Verificar si ya existe asistencia para esa fecha
      final checkQuery = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('user_id', isEqualTo: userUid)
          .where('fecha', isEqualTo: fechaStr)
          .get();

      if (checkQuery.docs.isNotEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // Cierra loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El alumno ya tiene asistencia registrada para el $fechaStr',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final String userName = userData['nombre'] ?? 'Sin nombre';
      final String userEmail = userData['email'] ?? 'Sin correo';
      final String claseId = userData['clase_id'] ?? '';
      final String corda = userData['corda'] ?? 'Crua';

      // Insertar ticket
      await FirebaseFirestore.instance.collection('asistencias').add({
        'sesion_id': 'manual_instructor',
        'user_id': userUid,
        'user_name': userName,
        'user_email': userEmail,
        'clase_id': claseId,
        'nivel': corda,
        'hora': '19:00',
        'fecha': fechaStr,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context); // Cierra loader
        Navigator.pop(context); // Cierra la ficha del alumno de forma segura
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Asistencia registrada con éxito para el $fechaStr! 🎉',
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
              'Error al registrar la asistencia. Intenta de nuevo.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────
//  WIDGET DE CALENDARIO DE ASISTENCIAS EN LA FICHA
// ─────────────────────────────────────────

class _FichaAsistenciasCalendar extends StatefulWidget {
  final String uid;
  const _FichaAsistenciasCalendar({required this.uid});

  @override
  State<_FichaAsistenciasCalendar> createState() => _FichaAsistenciasCalendarState();
}

class _FichaAsistenciasCalendarState extends State<_FichaAsistenciasCalendar> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('asistencias')
          .where('user_id', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(color: GingaColors.brandGreen),
            ),
          );
        }

        final Set<String> asistenciasFechas = snapshot.hasData
            ? snapshot.data!.docs
                .map((doc) => (doc.data() as Map<String, dynamic>)['fecha'] as String)
                .toSet()
            : {};

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GingaColors.borderLight.withOpacity(0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Historial de Asistencia del Mes',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${asistenciasFechas.length} clases',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.brandGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                rowHeight: 38,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mes',
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  headerPadding: const EdgeInsets.symmetric(vertical: 4),
                  titleTextStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: GingaColors.textPrimary,
                  ),
                  leftChevronIcon: const Icon(Icons.chevron_left, color: GingaColors.brandGreen, size: 20),
                  rightChevronIcon: const Icon(Icons.chevron_right, color: GingaColors.brandGreen, size: 20),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: GingaColors.textSecondary),
                  weekendStyle: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: GingaColors.brandGreen),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: GoogleFonts.nunito(fontSize: 12, color: GingaColors.textPrimary),
                  weekendTextStyle: GoogleFonts.nunito(fontSize: 12, color: GingaColors.textPrimary),
                  outsideDaysVisible: false,
                ),
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final fechaStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final bool asistio = asistenciasFechas.contains(fechaStr);
                    if (asistio) {
                      return Container(
                        margin: const EdgeInsets.all(3),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: GingaColors.brandGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final fechaStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final bool asistio = asistenciasFechas.contains(fechaStr);
                    return Container(
                      margin: const EdgeInsets.all(3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: asistio ? GingaColors.brandGreen : Colors.transparent,
                        border: Border.all(color: GingaColors.brandGreen, width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: asistio ? Colors.white : GingaColors.brandGreen,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
