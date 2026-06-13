import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/models/cuerdas_fiu.dart';

class GraduacionesScreen extends StatelessWidget {
  const GraduacionesScreen({super.key});



  Widget _buildCordaVisual(CordaFIU corda) {
    if (corda.esMixta) {
      // Dibujar cuerda trenzada dividida verticalmente
      return Container(
        width: double.infinity,
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [corda.colores[0], corda.colores[0].withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [corda.colores[1], corda.colores[1].withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Dibujar cuerda sólida estilizada
      return Container(
        width: double.infinity,
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            colors: corda.colores,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: corda.nombre == 'Branca'
              ? Border.all(color: Colors.grey.shade300, width: 0.8)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            String userCorda = 'Sin cuerda';
            String userNombre = 'Alumno';
            String userRol = 'alumno';

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>;
              userCorda = data['corda'] ?? 'Sin cuerda';
              userNombre = data['nombre'] ?? 'Alumno';
              userRol = data['rol'] ?? 'alumno';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Barra Superior (App Bar) ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: GingaColors.textPrimary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Graduaciones FIU',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Banner de Perfil de Cuerda Actual ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [GingaColors.brandGreen, Color(0xFF2E7D32)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(GingaRadius.lg),
                              boxShadow: [
                                BoxShadow(
                                  color: GingaColors.brandGreen.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.military_tech_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '¡Hola, $userNombre! 🥋',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.nunito(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(0.9),
                                          ),
                                          children: [
                                            const TextSpan(text: 'Tu rango oficial registrado: '),
                                            TextSpan(
                                              text: userCorda.toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: GingaColors.accentAmber,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Sección de explicación
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'El Sistema de Cuerdas (Cordonéis) 🎓',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: GingaColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'El camino de graduación en la Família Irmãos Unidos. Cada cuerda simboliza un elemento de la naturaleza y una etapa de sabiduría corporal y musical.',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: GingaColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Listado de Cuerdas ──
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: CuerdasFIU.lista.length,
                          itemBuilder: (context, index) {
                            final corda = CuerdasFIU.lista[index];
                            final isActive = CuerdasFIU.verificarCordaActiva(userCorda, corda);
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final currentCardBg = isDark
                                ? (isActive ? const Color(0xFF1E351E) : GingaColors.surfaceDark)
                                : (isActive ? const Color(0xFFE8F5E9) : Colors.white);
                            final currentBorderColor = isDark
                                ? (isActive ? GingaColors.accentGreenDark : Colors.transparent)
                                : (isActive ? GingaColors.brandGreen : GingaColors.borderLight);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: currentCardBg,
                                borderRadius: BorderRadius.circular(GingaRadius.lg),
                                border: Border.all(
                                  color: currentBorderColor,
                                  width: isActive ? 2.0 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isActive
                                        ? (isDark ? GingaColors.accentGreenDark.withOpacity(0.12) : GingaColors.brandGreen.withOpacity(0.12))
                                        : Colors.black.withOpacity(0.01),
                                    blurRadius: isActive ? 12 : 10,
                                    spreadRadius: isActive ? 1 : 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Fila Superior: Número + Rango + Insignia
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? GingaColors.brandGreen
                                                : (isDark ? GingaColors.backgroundDark : GingaColors.borderLight.withOpacity(0.5)),
                                            borderRadius: BorderRadius.circular(GingaRadius.sm),
                                          ),
                                          child: Text(
                                            corda.index < 10 ? '0${corda.index}' : '${corda.index}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: isActive
                                                  ? Colors.white
                                                  : GingaColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            corda.rango,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: GingaColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: GingaColors.brandGreen,
                                              borderRadius: BorderRadius.circular(4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: GingaColors.brandGreen.withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star, color: GingaColors.accentAmber, size: 10),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'MI RANGO',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Cuerda Visual Renderizada
                                    _buildCordaVisual(corda),
                                    const SizedBox(height: 12),

                                    // Detalles e Info
                                    Row(
                                      children: [
                                        Text(
                                          'Cuerda ${corda.nombre}',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: GingaColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '•',
                                          style: TextStyle(color: GingaColors.textSecondary.withOpacity(0.5)),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            corda.simbolismo,
                                            style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: GingaColors.brandGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      corda.descripcion,
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: GingaColors.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
