import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';

class InstructorAlumnosScreen extends StatelessWidget {
  const InstructorAlumnosScreen({super.key});

  void _mostrarModalActivacion(BuildContext context, Map<String, dynamic> data, String uid) {
    int mesesSeleccionados = 1;
    String? claseSeleccionadaId;
    bool isClassesLoaded = false;
    List<QueryDocumentSnapshot> clasesList = [];
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
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('clases').get(),
              builder: (context, classesSnapshot) {
                if (classesSnapshot.hasData && !isClassesLoaded) {
                  clasesList = classesSnapshot.data!.docs;
                  isClassesLoaded = true;
                  
                  // Intentar pre-seleccionar si el usuario ya tiene una clase asignada
                  claseSeleccionadaId = data['clase_id'];
                }

                return Padding(
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
                      Text('Activar Membresía',
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
                      Text('Fecha de Inicio de Membresía:',
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
                      Text('Meses a pagar:',
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
                              }

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .update(updateData);
                              
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Alumno activado y clase asociada con éxito 🎉'),
                                    backgroundColor: GingaColors.brandGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al activar: $e'),
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
                          child: Text('Confirmar Activación',
                              style: GoogleFonts.montserrat(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
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
                Text('Activa membresías de alumnos en prueba o inactivos',
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: GingaColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('status', whereIn: ['nuevo', 'prueba', 'inactivo'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: GingaColors.brandGreen),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No hay alumnos pendientes de activación',
                        style: GoogleFonts.nunito(color: GingaColors.textSecondary)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'desconocido';

                    return Container(
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
                            backgroundColor: status == 'prueba'
                                ? GingaColors.accentAmber.withOpacity(0.2)
                                : status == 'nuevo'
                                    ? GingaColors.brandGreen.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              color: status == 'prueba'
                                  ? GingaColors.accentAmber
                                  : status == 'nuevo'
                                      ? GingaColors.brandGreen
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
                                Text(status.toUpperCase(),
                                    style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: status == 'prueba'
                                            ? GingaColors.accentAmber
                                            : status == 'nuevo'
                                                ? GingaColors.brandGreen
                                                : Colors.red)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _mostrarModalActivacion(context, data, doc.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GingaColors.brandGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text('Activar',
                                style: GoogleFonts.montserrat(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
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
}
