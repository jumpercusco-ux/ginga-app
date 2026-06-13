import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/models/cuerdas_fiu.dart';

int _obtenerAsistenciasObjetivo(String cordaUsuario) {
  final cordaObj = CuerdasFIU.encontrarCordaFIU(cordaUsuario);
  if (cordaObj != null) {
    return CuerdasFIU.obtenerClasesObjetivo(cordaObj.index);
  }
  return 100;
}

String _obtenerSiguienteCorda(String cordaUsuario) {
  final cordaObj = CuerdasFIU.encontrarCordaFIU(cordaUsuario);
  if (cordaObj != null) {
    final nextIndex = cordaObj.index; 
    if (nextIndex < CuerdasFIU.lista.length) {
      return CuerdasFIU.lista[nextIndex].nombre;
    }
    return 'Graduado';
  }
  return 'Crua e Verde';
}

Map<String, dynamic> _obtenerToquesInfo(String cordaActual, int totalAsistencias) {
  int requerido = 4;
  String nombreToques = 'Toques Básicos (Angola / São Bento)';
  
  final cordaFiu = CuerdasFIU.encontrarCordaFIU(cordaActual);
  if (cordaFiu != null) {
    final idx = cordaFiu.index;
    if (idx <= 4) {
      requerido = 4;
      nombreToques = 'Toques Básicos (Angola / São Bento)';
    } else if (idx <= 8) {
      requerido = 10;
      nombreToques = 'Toques Medios (Benguela / S. Bento Pequeno)';
    } else if (idx <= 10) {
      requerido = 20;
      nombreToques = 'Toque de Roda (Iúna)';
    } else {
      requerido = 30;
      nombreToques = 'Toques Avanzados (Cavalaria / Santa Maria)';
    }
  }
  
  final bool completado = totalAsistencias >= requerido;
  final String label = completado 
      ? 'Dominio de $nombreToques' 
      : 'Progreso de $nombreToques: $totalAsistencias / $requerido clases';
      
  return {
    'label': label,
    'completado': completado,
  };
}

String _obtenerAntiguedad(Timestamp? fechaInicio) {
  if (fechaInicio == null) return 'Nuevo miembro';
  final inicio = fechaInicio.toDate();
  final ahora = DateTime.now();
  final dias = ahora.difference(inicio).inDays;
  
  if (dias < 30) {
    return '$dias ${dias == 1 ? 'día' : 'días'} en Ginga';
  } else {
    final meses = (dias / 30).floor();
    if (meses < 12) {
      return '$meses ${meses == 1 ? 'mes' : 'meses'} en Ginga';
    } else {
      final anos = (meses / 12).floor();
      final mesesRestantes = meses % 12;
      if (mesesRestantes == 0) {
        return '$anos ${anos == 1 ? 'año' : 'años'} en Ginga';
      }
      return '$anos ${anos == 1 ? 'año' : 'años'} y $mesesRestantes ${mesesRestantes == 1 ? 'mes' : 'meses'}';
    }
  }
}

class MiProgresoScreen extends StatelessWidget {
  const MiProgresoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        String cordaActual = 'Crua';
        Timestamp? fechaInicio;

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          cordaActual = userData['corda'] ?? 'Crua';
          fechaInicio = userData['fecha_inicio'] as Timestamp?;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('asistencias')
              .where('user_id', isEqualTo: uid)
              .snapshots(),
          builder: (context, asistenciasSnapshot) {
            int totalAsistencias = 0;
            if (asistenciasSnapshot.hasData) {
              totalAsistencias = asistenciasSnapshot.data!.docs.length;
            }

            final String siguienteCorda = _obtenerSiguienteCorda(cordaActual);
            final int objetivoAsistencias = _obtenerAsistenciasObjetivo(cordaActual);
            final double porcentaje = (totalAsistencias / objetivoAsistencias).clamp(0.0, 1.0);
            final int porcentajeInt = (porcentaje * 100).toInt();

            return Scaffold(
              backgroundColor: GingaColors.backgroundLight,
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // ── AppBar ──────────────────────────────
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Icon(Icons.arrow_back_ios_new,
                                size: 18, color: GingaColors.textPrimary),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Mi Progreso',
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: GingaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Estado actual ───────────────────────
                      _EstadoActualCard(
                        corda: cordaActual,
                        antiguedad: _obtenerAntiguedad(fechaInicio),
                      ),

                      const SizedBox(height: 24),

                      // ── Camino de graduación ─────────────────
                      Text(
                        'Camino de Graduación',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: GingaColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Timeline de cordas dinámico
                      _CordaTimeline(cordaActual: cordaActual),

                      const SizedBox(height: 24),

                      // ── Próximo objetivo ─────────────────────
                      if (siguienteCorda != 'Graduado')
                        _ProximoObjetivoCard(
                          cordaActual: cordaActual,
                          siguienteCorda: siguienteCorda,
                          totalAsistencias: totalAsistencias,
                          objetivo: objetivoAsistencias,
                          porcentaje: porcentaje,
                          porcentajeInt: porcentajeInt,
                        ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  ESTADO ACTUAL CARD
// ─────────────────────────────────────────

class _EstadoActualCard extends StatelessWidget {
  final String corda;
  final String antiguedad;

  const _EstadoActualCard({
    required this.corda,
    required this.antiguedad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GingaColors.cardLight,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.brandGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: GingaColors.brandGreen,
              borderRadius: BorderRadius.circular(GingaRadius.md),
            ),
            child: const Icon(Icons.emoji_events,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTADO ACTUAL',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: GingaColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  corda,
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.brandGreen,
                  ),
                ),
                Text(
                  antiguedad,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: GingaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CORDA TIMELINE (DINÁMICA)
// ─────────────────────────────────────────

class _CordaTimeline extends StatelessWidget {
  final String cordaActual;

  const _CordaTimeline({required this.cordaActual});

  @override
  Widget build(BuildContext context) {
    final List<String> todasLasCordas = CuerdasFIU.lista.map((c) => c.nombre).toList();

    int indiceActual = -1;
    final cordaObj = CuerdasFIU.encontrarCordaFIU(cordaActual);
    if (cordaObj != null) {
      indiceActual = CuerdasFIU.lista.indexWhere((c) => c.index == cordaObj.index);
    }
    if (indiceActual == -1) indiceActual = 0;

    final List<_CordaItem> timelineItems = [];
    final int maxIndexToShow = (indiceActual + 1).clamp(0, todasLasCordas.length - 1);

    for (int i = maxIndexToShow; i >= 0; i--) {
      final String nombre = todasLasCordas[i];
      _CordaStatus status;
      
      if (i == indiceActual) {
        status = _CordaStatus.activa;
      } else if (i < indiceActual) {
        status = _CordaStatus.completada;
      } else {
        status = _CordaStatus.bloqueada;
      }

      timelineItems.add(_CordaItem(
        nombre: nombre + (status == _CordaStatus.activa ? ' (Presente)' : ''),
        status: status,
      ));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timelineItems.length,
      itemBuilder: (context, index) {
        final corda = timelineItems[index];
        final isLast = index == timelineItems.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                _TimelineDot(status: corda.status),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: corda.status == _CordaStatus.completada
                        ? GingaColors.brandGreen
                        : GingaColors.borderLight,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: corda.status == _CordaStatus.activa
                        ? GingaColors.cardLight
                        : Colors.white,
                    borderRadius: BorderRadius.circular(GingaRadius.lg),
                    border: Border.all(
                      color: corda.status == _CordaStatus.activa
                          ? GingaColors.brandGreen.withValues(alpha: 0.3)
                          : GingaColors.borderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            corda.nombre,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: corda.status == _CordaStatus.bloqueada
                                  ? GingaColors.textSecondary
                                  : GingaColors.textPrimary,
                            ),
                          ),
                          Text(
                            corda.status == _CordaStatus.activa
                                ? 'Cinturón Activo'
                                : corda.status == _CordaStatus.completada
                                    ? 'Completado'
                                    : 'Próximo Objetivo',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: corda.status == _CordaStatus.activa
                                  ? GingaColors.brandGreen
                                  : GingaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (corda.status == _CordaStatus.completada)
                        const Icon(Icons.check_circle,
                            color: GingaColors.brandGreen, size: 20)
                      else if (corda.status == _CordaStatus.bloqueada)
                        Icon(Icons.lock_outline,
                            color: GingaColors.textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final _CordaStatus status;
  const _TimelineDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status == _CordaStatus.activa
            ? GingaColors.brandGreen
            : status == _CordaStatus.completada
                ? GingaColors.brandGreen
                : GingaColors.borderLight,
        border: Border.all(
          color: status == _CordaStatus.activa
              ? GingaColors.brandGreen
              : GingaColors.borderLight,
          width: 2,
        ),
      ),
      child: status == _CordaStatus.activa
          ? const Icon(Icons.circle, color: Colors.white, size: 10)
          : status == _CordaStatus.completada
              ? const Icon(Icons.check, color: Colors.white, size: 12)
              : Icon(Icons.lock_outline, color: GingaColors.textSecondary, size: 10),
    );
  }
}

// ─────────────────────────────────────────
//  PRÓXIMO OBJETIVO CARD
// ─────────────────────────────────────────

class _ProximoObjetivoCard extends StatelessWidget {
  final String cordaActual;
  final String siguienteCorda;
  final int totalAsistencias;
  final int objetivo;
  final double porcentaje;
  final int porcentajeInt;

  const _ProximoObjetivoCard({
    required this.cordaActual,
    required this.siguienteCorda,
    required this.totalAsistencias,
    required this.objetivo,
    required this.porcentaje,
    required this.porcentajeInt,
  });

  @override
  Widget build(BuildContext context) {
    final toquesInfo = _obtenerToquesInfo(cordaActual, totalAsistencias);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Próximo Objetivo',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: GingaColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GingaColors.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                child: Text(
                  'META GRADUACIÓN',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.accentAmber,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            siguienteCorda,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: GingaColors.brandGreen,
            ),
          ),

          const SizedBox(height: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso Total',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: GingaColors.textSecondary,
                    ),
                  ),
                  Text(
                    '$porcentajeInt%',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.brandGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(GingaRadius.full),
                child: LinearProgressIndicator(
                  value: porcentaje,
                  minHeight: 8,
                  backgroundColor: GingaColors.borderLight,
                  valueColor: const AlwaysStoppedAnimation(
                      GingaColors.brandGreen),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _RequisitoItem(
            icon: Icons.groups_outlined,
            label: 'Asistencias: $totalAsistencias / $objetivo clases',
            completado: totalAsistencias >= objetivo,
          ),
          const SizedBox(height: 8),
          _RequisitoItem(
            icon: Icons.event_available_outlined,
            label: toquesInfo['label'],
            completado: toquesInfo['completado'],
          ),
        ],
      ),
    );
  }
}

class _RequisitoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool completado;

  const _RequisitoItem({
    required this.icon,
    required this.label,
    required this.completado,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 16,
            color: completado
                ? GingaColors.brandGreen
                : GingaColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: completado
                ? GingaColors.textPrimary
                : GingaColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            completado ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: completado
                ? GingaColors.brandGreen
                : GingaColors.borderLight,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  MODELOS
// ─────────────────────────────────────────

enum _CordaStatus { activa, completada, bloqueada }

class _CordaItem {
  final String nombre;
  final _CordaStatus status;

  _CordaItem({
    required this.nombre,
    required this.status,
  });
}