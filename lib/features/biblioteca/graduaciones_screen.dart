import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/models/cuerdas_fiu.dart';

class GraduacionesScreen extends StatelessWidget {
  const GraduacionesScreen({super.key});

  String _limpiarNombreCorda(String cordaRaw) {
    return cordaRaw
        .toLowerCase()
        .replaceAll('cuerda', '')
        .replaceAll('corda', '')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  bool _verificarCordaActiva(String cordaUsuario, CordaFIU cordaItem) {
    if (cordaUsuario.isEmpty) return false;
    final u = _limpiarNombreCorda(cordaUsuario);
    final n = _limpiarNombreCorda(cordaItem.nombre);
    final r = _limpiarNombreCorda(cordaItem.rango);

    // 1. Coincidencia exacta de nombres o rangos limpios
    if (u == n || u == r) return true;

    // 2. Mapeos específicos de términos en español/portugués y sinónimos
    
    // Crua / Cruda / Gris / Iniciante
    if ((u == 'crua' || u == 'cruda' || u == 'gris' || u == 'iniciante') && n == 'crua') {
      return true;
    }

    // Verde
    if ((u == 'verde' || u == 'alumno iniciante') && n == 'verde') {
      return true;
    }

    // Naranja / Laranja
    if ((u == 'laranja' || u == 'naranja' || u == 'alumno regular') && n == 'laranja') {
      return true;
    }

    // Amarilla / Amarela
    if ((u == 'amarela' || u == 'amarilla' || u == 'amarillo' || u == 'alumno graduado' || u == 'graduado' || u == 'intermedio') && n == 'amarela') {
      return true;
    }

    // Monitor
    if ((u == 'monitor' || u == 'monitora' || u == 'amarelo e azul' || u == 'amarillo y azul') && n == 'amarelo e azul') {
      return true;
    }

    // Azul / Instrutor
    if ((u == 'azul' || u == 'instructor' || u == 'instrutor' || u == 'instrutora') && n == 'azul') {
      return true;
    }

    // Roxa / Morada / Professor
    if ((u == 'roxa' || u == 'morada' || u == 'profesor' || u == 'profesora' || u == 'professor' || u == 'professora') && n == 'roxa') {
      return true;
    }

    // Marrom / Marrón / Contra Mestre
    if ((u == 'marrom' || u == 'marron' || u == 'contra mestre' || u == 'contramestre') && n == 'marrom') {
      return true;
    }

    // Preta / Negra / Negro / Mestre
    if ((u == 'preta' || u == 'negra' || u == 'negro' || u == 'mestre' || u == 'maestro') && n == 'preta') {
      return true;
    }

    // Branca / Blanca / Blanco / Grão Mestre
    if ((u == 'branca' || u == 'blanca' || u == 'blanco' || u == 'grao mestre' || u == 'gran mestre' || u == 'gran maestro') && n == 'branca') {
      return true;
    }

    return false;
  }

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
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: GingaColors.textPrimary),
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
                            final isActive = _verificarCordaActiva(userCorda, corda);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFE8F5E9) : Colors.white,
                                borderRadius: BorderRadius.circular(GingaRadius.lg),
                                border: Border.all(
                                  color: isActive
                                      ? GingaColors.brandGreen
                                      : GingaColors.borderLight,
                                  width: isActive ? 2.0 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isActive
                                        ? GingaColors.brandGreen.withOpacity(0.12)
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
                                                : GingaColors.borderLight.withOpacity(0.5),
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
