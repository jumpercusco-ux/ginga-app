import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class MiProgresoScreen extends StatelessWidget {
  const MiProgresoScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(Icons.arrow_back_ios_new,
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
              _EstadoActualCard(),

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

              // Timeline de cordas
              _CordaTimeline(),

              const SizedBox(height: 24),

              // ── Próximo objetivo ─────────────────────
              _ProximoObjetivoCard(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ESTADO ACTUAL CARD
// ─────────────────────────────────────────

class _EstadoActualCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GingaColors.cardLight,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.brandGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Ícono corda
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
                  'Corda Verde',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.brandGreen,
                  ),
                ),
                Text(
                  '1 año, 4 meses',
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
//  CORDA TIMELINE
// ─────────────────────────────────────────

class _CordaTimeline extends StatelessWidget {
  final List<_CordaItem> _cordas = [
    _CordaItem(
      nombre: 'Corda Verde (Presente)',
      ano: null,
      status: _CordaStatus.activa,
    ),
    _CordaItem(
      nombre: 'Corda Amarela',
      ano: '2023',
      status: _CordaStatus.completada,
    ),
    _CordaItem(
      nombre: 'Iniciación',
      ano: '2022',
      status: _CordaStatus.completada,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cordas.length,
      itemBuilder: (context, index) {
        final corda = _cordas[index];
        final isLast = index == _cordas.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
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
            // Contenido
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
                          ? GingaColors.brandGreen.withOpacity(0.3)
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
                              color: GingaColors.textPrimary,
                            ),
                          ),
                          Text(
                            corda.status == _CordaStatus.activa
                                ? 'Active'
                                : 'Completado',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: corda.status == _CordaStatus.activa
                                  ? GingaColors.brandGreen
                                  : GingaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (corda.ano != null)
                        Text(
                          corda.ano!,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: GingaColors.textSecondary,
                          ),
                        ),
                      if (corda.status == _CordaStatus.completada)
                        const Icon(Icons.check_circle,
                            color: GingaColors.brandGreen, size: 20),
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
          : const Icon(Icons.check, color: Colors.white, size: 12),
    );
  }
}

// ─────────────────────────────────────────
//  PRÓXIMO OBJETIVO
// ─────────────────────────────────────────

class _ProximoObjetivoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                  color: GingaColors.accentAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                child: Text(
                  'META 2024',
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
            'Corda Azul',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: GingaColors.brandGreen,
            ),
          ),

          const SizedBox(height: 12),

          // Progress bar
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
                    '60%',
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
                  value: 0.6,
                  minHeight: 8,
                  backgroundColor: GingaColors.borderLight,
                  valueColor: const AlwaysStoppedAnimation(
                      GingaColors.brandGreen),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Requisitos
          _RequisitoItem(
            icon: Icons.groups_outlined,
            label: 'Asistencias: 45/80',
            completado: false,
          ),
          const SizedBox(height: 8),
          _RequisitoItem(
            icon: Icons.event_available_outlined,
            label: 'Workshop Oficial',
            completado: true,
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
      children: [
        Icon(
          icon,
          size: 16,
          color: completado
              ? GingaColors.brandGreen
              : GingaColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: completado
                ? GingaColors.textPrimary
                : GingaColors.textSecondary,
          ),
        ),
        const Spacer(),
        Icon(
          completado ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: completado
              ? GingaColors.brandGreen
              : GingaColors.borderLight,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  MODELOS
// ─────────────────────────────────────────

enum _CordaStatus { activa, completada }

class _CordaItem {
  final String nombre;
  final String? ano;
  final _CordaStatus status;

  _CordaItem({
    required this.nombre,
    required this.ano,
    required this.status,
  });
}