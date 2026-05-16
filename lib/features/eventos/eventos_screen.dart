import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';
import 'evento_detalle_screen.dart';

class EventosScreen extends StatefulWidget {
  const EventosScreen({super.key});

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  int _selectedDayIndex = 3; // día 16 seleccionado por defecto

  final List<_DayData> _days = [
    _DayData(dia: 'LUN', numero: '12'),
    _DayData(dia: 'MAR', numero: '13'),
    _DayData(dia: 'MIÉ', numero: '14'),
    _DayData(dia: 'JUE', numero: '15'),
    _DayData(dia: 'VIE', numero: '16'),
    _DayData(dia: 'SÁB', numero: '17'),
  ];

  final List<_EventoData> _eventos = [
    _EventoData(
      titulo: 'Workshop de Capoeira Regional',
      fecha: '15 de Octubre · 18:00 hrs',
      lugar: 'Centro Cultural Mira, Miraflores',
      tag: 'CUPOS LIMITADOS',
      tagColor: GingaColors.accentAmber,
    ),
    _EventoData(
      titulo: 'Batizado e Troca de Cordas',
      fecha: '22 de Octubre · 10:00 hrs',
      lugar: 'Coliseo Manuel Bonilla',
      tag: null,
      tagColor: null,
    ),
    _EventoData(
      titulo: 'Roda Aberta con Mestre Sidney',
      fecha: '29 de Octubre · 16:00 hrs',
      lugar: 'Parque de la Roda, Cusco',
      tag: 'EVENTO DESTACADO',
      tagColor: GingaColors.brandGreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eventos y Talleres',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: GingaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: GingaColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            'Lima, Perú',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: GingaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.search,
                        color: GingaColors.textPrimary, size: 22),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Calendario horizontal ────────────────
            SizedBox(
              height: 68,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  final day = _days[index];
                  final isSelected = _selectedDayIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? GingaColors.brandGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        border: Border.all(
                          color: isSelected
                              ? GingaColors.brandGreen
                              : GingaColors.borderLight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day.dia,
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : GingaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            day.numero,
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : GingaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Lista de eventos ─────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _eventos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _EventoCard(evento: _eventos[index]);
                },
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  EVENTO CARD
// ─────────────────────────────────────────

class _EventoCard extends StatelessWidget {
  final _EventoData evento;
  const _EventoCard({required this.evento});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Imagen ──────────────────────────────
          Stack(
            children: [
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: GingaColors.backgroundDark,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(GingaRadius.lg),
                    topRight: Radius.circular(GingaRadius.lg),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.sports_martial_arts,
                    color: GingaColors.brandGreen,
                    size: 56,
                  ),
                ),
              ),
              // Tag (si existe)
              if (evento.tag != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: evento.tagColor,
                      borderRadius: BorderRadius.circular(GingaRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          evento.tagColor == GingaColors.accentAmber
                              ? Icons.warning_amber_rounded
                              : Icons.star_rounded,
                          size: 12,
                          color: evento.tagColor == GingaColors.accentAmber
                              ? const Color(0xFF412402)
                              : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          evento.tag!,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: evento.tagColor == GingaColors.accentAmber
                                ? const Color(0xFF412402)
                                : Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Info ────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evento.titulo,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: GingaColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      evento.fecha,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: GingaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: GingaColors.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        evento.lugar,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: GingaColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Botón Ver Detalles
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const EventoDetalleScreen(),
    ),
  );
},                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Ver Detalles',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
//  MODELOS
// ─────────────────────────────────────────

class _DayData {
  final String dia;
  final String numero;
  _DayData({required this.dia, required this.numero});
}

class _EventoData {
  final String titulo;
  final String fecha;
  final String lugar;
  final String? tag;
  final Color? tagColor;

  _EventoData({
    required this.titulo,
    required this.fecha,
    required this.lugar,
    required this.tag,
    required this.tagColor,
  });
}