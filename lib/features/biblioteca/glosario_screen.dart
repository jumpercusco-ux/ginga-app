import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class GlosarioTermino {
  final String termino;
  final String categoria; // 'Ataques', 'Esquivas', 'Desequilibrios', 'Cultura'
  final String pronunciacion;
  final String significado;
  final String consejo;

  const GlosarioTermino({
    required this.termino,
    required this.categoria,
    required this.pronunciacion,
    required this.significado,
    required this.consejo,
  });
}

class GlosarioScreen extends StatefulWidget {
  const GlosarioScreen({super.key});

  @override
  State<GlosarioScreen> createState() => _GlosarioScreenState();
}

class _GlosarioScreenState extends State<GlosarioScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  static const List<GlosarioTermino> _terminos = [
    GlosarioTermino(
      termino: 'Bênção',
      categoria: 'Ataques',
      pronunciacion: '[ben-saon]',
      significado: 'Patada frontal empujando con la planta del pie dirigida al pecho del oponente. Movimiento básico pero sumamente potente.',
      consejo: 'Asegúrate de extender la cadera y empujar con la planta, no patear como si fuera fútbol.',
    ),
    GlosarioTermino(
      termino: 'Martelo',
      categoria: 'Ataques',
      pronunciacion: '[mar-te-lu]',
      significado: 'Patada lateral que golpea con el empeine del pie, buscando el costado de la cabeza o el tronco del rival.',
      consejo: 'Gira el pie de apoyo por completo para proteger la rodilla y ganar alcance.',
    ),
    GlosarioTermino(
      termino: 'Queixada',
      categoria: 'Ataques',
      pronunciacion: '[kei-sha-da]',
      significado: 'Patada circular de adentro hacia afuera golpeando con la parte externa del pie (el filo).',
      consejo: 'Cruza el paso primero para tener más impulso rotacional en el torso.',
    ),
    GlosarioTermino(
      termino: 'Armada',
      categoria: 'Ataques',
      pronunciacion: '[ar-ma-da]',
      significado: 'Patada giratoria con talón donde el cuerpo rota 360 grados sobre el pie de apoyo antes de lanzar el golpe.',
      consejo: 'La cabeza debe girar primero y ubicar el objetivo visual antes de soltar la pierna.',
    ),
    GlosarioTermino(
      termino: 'Meia-lua de compasso',
      categoria: 'Ataques',
      pronunciacion: '[meia-lua ji com-pas-su]',
      significado: 'La patada más icónica de la Capoeira: combina acrobacia y golpe. El cuerpo baja colocando una o ambas manos en el suelo y gira lanzando la pierna trasera en un compás perfecto.',
      consejo: 'Mantén la mirada fija en el oponente por entre tus brazos en todo momento.',
    ),
    GlosarioTermino(
      termino: 'Meia-lua de frente',
      categoria: 'Ataques',
      pronunciacion: '[meia-lua ji fren-ti]',
      significado: 'Patada semicircular de adentro hacia afuera que pasa directamente frente al rostro del oponente, utilizada para medir distancias.',
      consejo: 'Mantén la pierna de golpe completamente estirada y la guardia arriba.',
    ),
    GlosarioTermino(
      termino: 'Chapéu de couro',
      categoria: 'Ataques',
      pronunciacion: '[sha-peu ji cou-ru]',
      significado: 'Patada especial que se ejecuta bajando lateralmente con una mano en el suelo mientras se patea de lado con la otra pierna.',
      consejo: 'Excelente contraataque para pasar por debajo de una patada alta del rival.',
    ),
    GlosarioTermino(
      termino: 'Cocorinha',
      categoria: 'Esquivas',
      pronunciacion: '[co-co-ri-nha]',
      significado: 'Esquiva básica bajando completamente en cuclillas, manteniendo los pies planos en el suelo y protegiendo los costados de la cabeza con los puños cerrados.',
      consejo: 'Nunca te levantes sobre las puntas de los pies; mantén toda la planta pegada para no perder el equilibrio.',
    ),
    GlosarioTermino(
      termino: 'Negativa',
      categoria: 'Esquivas',
      pronunciacion: '[ne-ga-ti-va]',
      significado: 'Esquiva muy baja extendiendo una pierna al frente y flexionando la otra por completo sobre el talón, manteniendo el torso pegado al suelo.',
      consejo: 'Una mano protege tu rostro del ataque rival y la otra se apoya en el suelo para soporte.',
    ),
    GlosarioTermino(
      termino: 'Negativa de Angola',
      categoria: 'Esquivas',
      pronunciacion: '[ne-ga-ti-va ji an-go-la]',
      significado: 'Postura defensiva tradicional de la capoeira angola apoyando pies y manos de costado en una diagonal baja.',
      consejo: 'Es ideal para salir de ataques desequilibrantes y prepararse para barrer.',
    ),
    GlosarioTermino(
      termino: 'Rolamento na ginga',
      categoria: 'Esquivas',
      pronunciacion: '[ru-la-men-tu na jin-ga]',
      significado: 'Transición corporal giratoria baja para desplazarse de forma segura en la roda, cambiar de dirección y evadir patadas de barrido.',
      consejo: 'Mantén los hombros bajos y no despegues los ojos de la roda.',
    ),
    GlosarioTermino(
      termino: 'Esquiva básica',
      categoria: 'Esquivas',
      pronunciacion: '[es-ki-va ba-zi-ca]',
      significado: 'Defensa fundamental dando un paso largo hacia atrás y flexionando el torso hacia el costado contrario para esquivar golpes altos.',
      consejo: 'La mano de la pierna trasera protege tu cara; la delantera permanece lista para contragolpear.',
    ),
    GlosarioTermino(
      termino: 'Aú',
      categoria: 'Esquivas',
      pronunciacion: '[a-u]',
      significado: 'La rueda o pirueta lateral típica. No solo es acrobacia, sino un movimiento dinámico para atacar, esquivar o reposicionarse en la roda.',
      consejo: 'Hazlo siempre mirando hacia tu oponente, nunca mirando hacia el piso.',
    ),
    GlosarioTermino(
      termino: 'Bananeira',
      categoria: 'Esquivas',
      pronunciacion: '[ba-na-nei-ra]',
      significado: 'Parada de manos tradicional que demuestra un control excepcional del equilibrio y la fuerza del tren superior.',
      consejo: 'Aprende a controlar el peso con los dedos de las manos bien abiertos y flexionados.',
    ),
    GlosarioTermino(
      termino: 'Macaco',
      categoria: 'Esquivas',
      pronunciacion: '[ma-ca-cu]',
      significado: 'Salto acrobático hacia atrás apoyando una sola mano en el suelo de espaldas, impulsándote con las piernas flexionadas.',
      consejo: 'Empuja la cadera hacia arriba con fuerza y sigue tu mano con la mirada.',
    ),
    GlosarioTermino(
      termino: 'Queda de rim',
      categoria: 'Esquivas',
      pronunciacion: '[ke-da ji rim]',
      significado: 'Postura clásica de equilibrio sobre los brazos apoyando la cadera en el codo flexionado a la altura de los riñones.',
      consejo: 'Es la base para muchas acrobacias y transiciones avanzadas de suelo.',
    ),
    GlosarioTermino(
      termino: 'Rasteira',
      categoria: 'Desequilibrios',
      pronunciacion: '[ras-tei-ra]',
      significado: 'Barrido rasante con el pie jalando el talón o la pantorrilla del oponente en el momento que apoya el peso para tirarlo.',
      consejo: 'Aprovecha la inercia del rival; no uses fuerza bruta, sino sincronización perfecta.',
    ),
    GlosarioTermino(
      termino: 'Arpão',
      categoria: 'Desequilibrios',
      pronunciacion: '[ar-paon]',
      significado: 'Técnica de desequilibrio directo barriendo con la pierna y cadera estirada desde el suelo.',
      consejo: 'Entra rápido y sorpresivo cuando el rival termine de patear.',
    ),
    GlosarioTermino(
      termino: 'Vingativa',
      categoria: 'Desequilibrios',
      pronunciacion: '[vin-ga-ti-va]',
      significado: 'Derribo de corta distancia dando un paso por detrás del pie de apoyo del oponente y empujándolo firmemente con el codo/espalda.',
      consejo: 'Protege tu rostro del codo rival al entrar en su guardia.',
    ),
    GlosarioTermino(
      termino: 'Banda de costas',
      categoria: 'Desequilibrios',
      pronunciacion: '[ban-da ji cos-tas]',
      significado: 'Desequilibrio enganchando el pie de apoyo del rival por detrás mientras está concentrado en un ataque alto.',
      consejo: 'Sincroniza el tirón con un empuje sutil del hombro.',
    ),
    GlosarioTermino(
      termino: 'Apelido',
      categoria: 'Cultura',
      pronunciacion: '[a-pe-li-du]',
      significado: 'Apodo oficial que recibe un capoeirista. Históricamente servía para ocultar la identidad de los practicantes ante la persecución policial.',
      consejo: 'Se recibe oficialmente en el Batizado y suele inspirarse en tu forma de jugar o personalidad.',
    ),
    GlosarioTermino(
      termino: 'Bateria',
      categoria: 'Cultura',
      pronunciacion: '[ba-te-ri-a]',
      significado: 'La orquesta de instrumentos musicales colocados en hilera que comanda y rige el ritmo y velocidad del juego de Capoeira.',
      consejo: 'Tradicionalmente compuesta por tres Berimbaus, dos Pandeiros, un Atabaque, Agogô y Reco-reco.',
    ),
    GlosarioTermino(
      termino: 'Batizado',
      categoria: 'Cultura',
      pronunciacion: '[ba-ti-za-du]',
      significado: 'Ceremonia anual de la academia. Los alumnos nuevos juegan con un Mestre, reciben su primera cuerda y su "Apelido" oficial.',
      consejo: 'Es el evento más importante del año escolar capoeirista.',
    ),
    GlosarioTermino(
      termino: 'Mestre',
      categoria: 'Cultura',
      pronunciacion: '[mes-tri]',
      significado: 'El rango más alto de conocimiento de la Capoeira. Domina el juego físico, el canto, todos los instrumentos y la filosofía de vida.',
      consejo: 'Un Mestre es un protector de la tradición y guía pedagógico del grupo.',
    ),
    GlosarioTermino(
      termino: 'Axé',
      categoria: 'Cultura',
      pronunciacion: '[a-she]',
      significado: 'La energía vital espiritual, vibración positiva y entusiasmo colectivo que se genera al cantar y tocar en la Roda.',
      consejo: 'Bate palmas con ritmo y responde el coro con energía para elevar el Axé de la Roda.',
    ),
    GlosarioTermino(
      termino: 'Roda',
      categoria: 'Cultura',
      pronunciacion: '[ho-da]',
      significado: 'El círculo de capoeiristas donde se lleva a cabo el juego físico. Es el escenario central de la expresión del Axé, la música y la lucha.',
      consejo: 'La Roda es un espacio de respeto absoluto y hermandad.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTerminos = _terminos.where((item) {
      final matchesSearch = item.termino.toLowerCase().contains(_searchQuery) ||
          item.significado.toLowerCase().contains(_searchQuery);
      final matchesCategory = _selectedCategory == 'Todos' ||
          item.categoria == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
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
                    'Glosario Oficial',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Título Principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diccionario FIU 📖',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Domina el lenguaje oficial de la roda, golpes e historia',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: GingaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Barra de Búsqueda ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  style: GoogleFonts.montserrat(
                      fontSize: 14, color: GingaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar término o significado...',
                    hintStyle: GoogleFonts.montserrat(
                        fontSize: 14, color: GingaColors.textSecondary),
                    prefixIcon: const Icon(Icons.search,
                        color: GingaColors.brandGreen, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Chips de Filtros ──
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  'Todos',
                  'Ataques',
                  'Esquivas',
                  'Desequilibrios',
                  'Cultura',
                ].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? GingaColors.brandGreen
                              : cardBg,
                          borderRadius: BorderRadius.circular(GingaRadius.full),
                          border: Border.all(
                            color: isSelected
                                ? GingaColors.brandGreen
                                : borderColor,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat == 'Todos'
                                ? 'Todos 🌐'
                                : cat == 'Ataques'
                                    ? 'Ataques 🥋'
                                    : cat == 'Esquivas'
                                        ? 'Esquivas 🌀'
                                        : cat == 'Desequilibrios'
                                            ? 'Desequilibrios 💥'
                                            : 'Cultura 🥁',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : GingaColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // ── Listado de Términos ──
            Expanded(
              child: filteredTerminos.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron términos.',
                        style: GoogleFonts.montserrat(
                            color: GingaColors.textSecondary, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: filteredTerminos.length,
                      itemBuilder: (context, index) {
                        final item = filteredTerminos[index];
                        return _TerminoCard(item: item);
                      },
                    ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminoCard extends StatefulWidget {
  final GlosarioTermino item;
  const _TerminoCard({required this.item});

  @override
  State<_TerminoCard> createState() => _TerminoCardState();
}

class _TerminoCardState extends State<_TerminoCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Colores basados en categoría
    Color categoryColor = GingaColors.brandGreen;
    if (widget.item.categoria == 'Ataques') {
      categoryColor = GingaColors.brandGreen;
    } else if (widget.item.categoria == 'Esquivas') {
      categoryColor = GingaColors.accentAmber;
    } else if (widget.item.categoria == 'Desequilibrios') {
      categoryColor = Colors.red.shade400;
    } else {
      categoryColor = Colors.purple.shade400;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.item.categoria == 'Ataques'
                  ? Icons.sports_martial_arts_rounded
                  : widget.item.categoria == 'Esquivas'
                      ? Icons.change_history_rounded
                      : widget.item.categoria == 'Desequilibrios'
                          ? Icons.swap_vert_rounded
                          : Icons.menu_book_outlined,
              color: categoryColor,
              size: 20,
            ),
          ),
          title: Text(
            widget.item.termino,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: GingaColors.textPrimary,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                widget.item.pronunciacion,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: GingaColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.item.categoria.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          trailing: Icon(
            _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: GingaColors.textSecondary,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 1,
                    color: borderColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.significado,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: GingaColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(
                        color: categoryColor.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            color: categoryColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TIP DEL MESTRE 💡',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: categoryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.item.consejo,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: GingaColors.textSecondary,
                                  height: 1.3,
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
          ],
        ),
      ),
    );
  }
}
