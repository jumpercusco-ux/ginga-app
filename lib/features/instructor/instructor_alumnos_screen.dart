import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';

class InstructorAlumnosScreen extends StatelessWidget {
  const InstructorAlumnosScreen({super.key});

  void _mostrarModalActivacion(BuildContext context, Map<String, dynamic> data, String uid) {
    int mesesSeleccionados = 1;

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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
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
                  const SizedBox(height: 24),
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
                        // Calcular fecha de fin
                        final ahora = DateTime.now();
                        // Asumimos 30 días por mes para simplificar o usamos DateTime(year, month + meses, day)
                        final fechaFin = DateTime(
                          ahora.year,
                          ahora.month + mesesSeleccionados,
                          ahora.day,
                        );

                        try {
                          // Buscar si el alumno tiene alguna reservación para asociarle esa clase
                          final reservasQuery = await FirebaseFirestore.instance
                              .collection('reservas')
                              .where('user_id', isEqualTo: uid)
                              .get();

                          String? claseId;
                          if (reservasQuery.docs.isNotEmpty) {
                            claseId = reservasQuery.docs.first['clase_id'];
                          }

                          final Map<String, dynamic> updateData = {
                            'status': 'activo',
                            'membresia_fin': Timestamp.fromDate(fechaFin),
                            'membresia_meses_pagados': mesesSeleccionados,
                          };

                          if (claseId != null) {
                            updateData['clase_id'] = claseId;
                          }

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update(updateData);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Alumno activado con éxito'),
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
                  const SizedBox(height: 24),
                ],
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
