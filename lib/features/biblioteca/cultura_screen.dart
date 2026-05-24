import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';
import 'song_detail_screen.dart';

class CulturaScreen extends StatefulWidget {
  const CulturaScreen({super.key});

  @override
  State<CulturaScreen> createState() => _CulturaScreenState();
}

class _CulturaScreenState extends State<CulturaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  final TextEditingController _searchController = TextEditingController();

  // Lista estática de cantigas tradicionales de Capoeira
  final List<Cantiga> _cantigas = [
    Cantiga(
      id: '1',
      titulo: 'Dona Maria Como Vai Você',
      ritmo: 'Corrido',
      autor: 'Tradicional',
      duracion: '2:15',
      contexto: 'Este corrido es uno de los cantos de juego más alegres y dinámicos de la roda. Se canta con un ritmo rápido para inyectar vitalidad y llamar a los jugadores a acelerar sus movimientos e interacciones en el centro.',
      letraPt: '''Dona Maria como vai você?
Dona Maria como vai você?

Eu vou na roda pra ver a jogada,
Eu vou na roda pra ver você.

Dona Maria como vai você?
Dona Maria como vai você?

O berimbau tá tocando na praça,
A capoeira é pra quem quer ver.

Dona Maria como vai você?
Dona Maria como vai você?''',
      letraEs: '''Doña María ¿cómo le va?
Doña María ¿cómo le va?

Voy a la roda para ver el juego,
Voy a la roda para verte a ti.

Doña María ¿cómo le va?
Doña María ¿cómo le va?

El berimbau está sonando en la plaza,
La capoeira es para quien quiera ver.

Doña María ¿cómo le va?
Doña María ¿cómo le va?''',
    ),
    Cantiga(
      id: '2',
      titulo: 'Paraná Ê',
      ritmo: 'Corrido',
      autor: 'Tradicional',
      duracion: '3:05',
      contexto: 'Uno de los cantos más emblemáticos y solemnes de la capoeira. Su origen se remonta a la Guerra de la Triple Alianza (Guerra del Paraguay), donde muchos esclavizados lucharon y recordaban su añoranza y nostalgia por la libertad de Bahía.',
      letraPt: '''Paraná ê, Paraná ê, Paraná.
Paraná ê, Paraná ê, Paraná.

Vou me embora pra Bahia,
Terra de São Salvador.

Paraná ê, Paraná ê, Paraná.
Paraná ê, Paraná ê, Paraná.

Berimbau bateu com força,
Meu peito até chorou.

Paraná ê, Paraná ê, Paraná.
Paraná ê, Paraná ê, Paraná.

Quem não sabe andar de gunga,
Não se mete a capoeira.

Paraná ê, Paraná ê, Paraná.
Paraná ê, Paraná ê, Paraná.''',
      letraEs: '''Paraná eh, Paraná eh, Paraná.
Paraná eh, Paraná eh, Paraná.

Me voy a ir para Bahía,
Tierra de San Salvador (capital).

Paraná eh, Paraná eh, Paraná.
Paraná eh, Paraná eh, Paraná.

El berimbau sonó con fuerza,
Mi pecho hasta lloró.

Paraná eh, Paraná eh, Paraná.
Paraná eh, Paraná eh, Paraná.

Quien no sabe tocar el gunga,
No se mete a la capoeira.

Paraná eh, Paraná eh, Paraná.
Paraná eh, Paraná eh, Paraná.''',
    ),
    Cantiga(
      id: '3',
      titulo: 'Muriacá',
      ritmo: 'Samba de Roda',
      autor: 'Tradicional',
      duracion: '1:58',
      contexto: 'Un canto festivo con raíces en el Samba de Roda del Recôncavo Bahiano. Suele cantarse hacia el final de la roda para liberar la tensión, permitiendo un juego rítmico, más danzado, relajado y lleno de floreos.',
      letraPt: '''Muriacá, Muriacá, Muriacá.
Muriacá, Muriacá, Muriacá.

A capoeira é jogo de mandinga,
Muriacá, Muriacá, Muriacá.

Muriacá, Muriacá, Muriacá.
Muriacá, Muriacá, Muriacá.

Berimbau tocou, a roda começou,
Muriacá, Muriacá, Muriacá.

Muriacá, Muriacá, Muriacá.
Muriacá, Muriacá, Muriacá.''',
      letraEs: '''Muriacá, Muriacá, Muriacá.
Muriacá, Muriacá, Muriacá.

La capoeira es juego de hechicería,
Muriacá, Muriacá, Muriacá.

Muriacá, Muriacá, Muriacá.
Muriacá, Muriacá, Muriacá.

El berimbau sonó, la roda comenzó,
Muriacá, Muriacá, Muriacá.

Muriacá, Muriacá, Muriacá.
Muriacá, Muriacá, Muriacá.''',
    ),
    Cantiga(
      id: '4',
      titulo: 'Sim Sim Sim, Não Não Não',
      ritmo: 'Corrido',
      autor: 'Mestre Bimba',
      duracion: '2:40',
      contexto: 'Atribuido históricamente a Mestre Bimba, creador de la Capoeira Regional. Es un corrido muy lúdico que genera alta interactividad con la Roda, jugando con preguntas del solista y respuestas del coro alternando afirmaciones y negaciones.',
      letraPt: '''Sim, sim, sim, não, não, não.
Sim, sim, sim, não, não, não.

Hoje tem jogo de capoeira,
sim senhor.

Amanhã tem roda na ribeira,
não senhor.

Sim, sim, sim, não, não, não.
Sim, sim, sim, não, não, não.

Mestre Bimba é o criador,
sim senhor.

Que ensinou com muito amor,
não senhor.

Sim, sim, sim, não, não, não.
Sim, sim, sim, não, não, não.''',
      letraEs: '''Sí, sí, sí, no, no, no.
Sí, sí, sí, no, no, no.

Hoy hay juego de capoeira,
sí señor.

Mañana hay roda en la ribera,
no señor.

Sí, sí, sí, no, no, no.
Sí, sí, sí, no, no, no.

El Mestre Bimba es el creador,
sí señor.

Que enseñó con mucho amor,
no señor.

Sí, sí, sí, no, no, no.
Sí, sí, sí, no, no, no.''',
    ),
    Cantiga(
      id: '5',
      titulo: 'Lamento de Mandingueiro',
      ritmo: 'Ladainha',
      autor: 'Mestre Pastinha',
      duracion: '3:30',
      contexto: 'Una de las Ladainhas más hermosas de la Capoeira Angola. Es un canto introspectivo e introductorio que el solista canta solo al pie del berimbau antes del juego propiamente dicho. Invoca protección y recuerda la herencia de los ancestros.',
      letraPt: '''Iê! Valha-me Deus, Senhor São Bento,
Que o mundo está em movimento.
Capoeira é minha vida.
Peço licença ao terreiro,
Ao criador do cativeiro,
E a todos os presentes,
Que me escutam cantar.

Iê, vamos jogar!
(Coro: Iê, vamos jogar, camará!)

Iê, viva meu mestre!
(Coro: Iê, viva meu mestre, camará!)''',
      letraEs: '''¡Iê! Válgame Dios, Señor San Bento,
Que el mundo está en movimiento.
La capoeira es mi vida.
Pido licencia a este patio,
Al creador del cautiverio,
Y a todos los presentes,
Que me escuchan cantar.

¡Iê, vamos a jugar!
(Coro: ¡Iê, vamos a jugar, camarada!)

¡Iê, viva mi maestro!
(Coro: ¡Iê, viva mi maestro, camarada!)''',
    ),
  ];

  final List<HistoriaArticulo> _articulos = [
    HistoriaArticulo(
      titulo: 'Orígenes y Resistencia',
      subtitulo: 'El nacimiento de un arte prohibido',
      icono: Icons.shield_outlined,
      color: GingaColors.brandGreen,
      tag: 'HISTORIA',
      contenido: 'La capoeira nació en el siglo XVI como un mecanismo de supervivencia y liberación de los esclavos africanos traídos al Brasil. Para camuflar su letal entrenamiento de combate de los capataces de las plantaciones, los capoeiristas le añadieron danza, música e instrumentos como el berimbau.\n\nDurante casi cuatro siglos fue prohibida y perseguida en Brasil, castigada con trabajos forzados en las calles, hasta que en 1937 fue legalizada y declarada patrimonio cultural nacional gracias al incansable trabajo del Mestre Bimba, quien la introdujo en los círculos deportivos e intelectuales.',
    ),
    HistoriaArticulo(
      titulo: 'Angola vs. Regional',
      subtitulo: 'Dos filosofías de juego, una misma raíz',
      icono: Icons.compare_arrows_rounded,
      color: GingaColors.accentAmber,
      tag: 'FILOSOFÍA',
      contenido: 'Existen dos estilos tradicionales principales en la Capoeira:\n\n• Capoeira Angola: Preservada por Mestre Pastinha, es el estilo tradicional, táctico, más cercano al suelo y cargado de astucia (mandinga). El juego es teatral, ritualizado y lento, pero altamente impredecible.\n\n• Capoeira Regional: Creada por Mestre Bimba, es un estilo moderno, rápido y acrobático. Bimba incorporó técnicas de lucha y sistematizó la enseñanza con una metodología rigurosa para dotar a la capoeira de un carácter más deportivo y defensivo.',
    ),
    HistoriaArticulo(
      titulo: 'Fundamentos de la Roda',
      subtitulo: 'Reglas, respeto y el ritual del juego',
      icono: Icons.hub_outlined,
      color: Colors.purple,
      tag: 'ETIQUETA',
      contenido: 'La Roda es el círculo sagrado donde ocurre la capoeira. Está gobernada por los instrumentos colocados en la cabecera (gunga, médio, viola, atabaque y pandero). Ningún jugador entra a la roda sin pedir permiso o "comprar el juego" en el pie del berimbau gunga.\n\nEl respeto mutuo, la picardía y la sincronización con el canto del solista son fundamentales. Nunca des la espalda a tu oponente, mantén siempre el contacto visual y mantente en movimiento constante con la ginga tradicional.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Cantiga> get _filteredCantigas {
    return _cantigas.where((cantiga) {
      final matchesSearch = cantiga.titulo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cantiga.letraPt.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cantiga.letraEs.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todos' || cantiga.ritmo == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _mostrarDetalleHistoria(BuildContext context, HistoriaArticulo articulo) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.88,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GingaRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado estético
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    color: articulo.color.withOpacity(0.08),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: articulo.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                          ),
                          child: Icon(articulo.icono, color: articulo.color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: articulo.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  articulo.tag,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: articulo.color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                articulo.titulo,
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: GingaColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            articulo.subtitulo,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: GingaColors.textPrimary.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            articulo.contenido,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: GingaColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botón cerrar inferior
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Entendido',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Barra Superior Personalizada (App Bar) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: GingaColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Cultura Capoeira',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, color: GingaColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Pestañas Segmentadas (TabBar Personalizada) ────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              height: 48,
              decoration: BoxDecoration(
                color: GingaColors.borderLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(GingaRadius.md),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                labelColor: GingaColors.brandGreen,
                unselectedLabelColor: GingaColors.textSecondary,
                labelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Cancionero 🎶'),
                  Tab(text: 'Historia & Mestres 📜'),
                ],
              ),
            ),

            // ── Contenido de las Pestañas ──────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ─────────────────────────────────────────
                  //  PESTAÑA 1: CANCIONERO
                  // ─────────────────────────────────────────
                  Column(
                    children: [
                      // Buscador de Cantigas
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar canciones, letras...',
                            hintStyle: GoogleFonts.nunito(color: GingaColors.textSecondary.withOpacity(0.6)),
                            prefixIcon: const Icon(Icons.search, color: GingaColors.textSecondary),
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
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: const BorderSide(color: GingaColors.borderLight),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: const BorderSide(color: GingaColors.borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                            ),
                          ),
                        ),
                      ),

                      // Filtro horizontal de Ritmos
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: ['Todos', 'Corrido', 'Ladainha', 'Samba de Roda'].map((ritmo) {
                            final isSelected = _selectedCategory == ritmo;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = ritmo;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? GingaColors.brandGreen : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? GingaColors.brandGreen : GingaColors.borderLight,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  ritmo,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : GingaColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Listado de canciones
                      Expanded(
                        child: _filteredCantigas.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.library_music_outlined, size: 48, color: GingaColors.borderLight),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No se encontraron cantigas',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: GingaColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Prueba con otra búsqueda o filtro',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: GingaColors.textSecondary.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                itemCount: _filteredCantigas.length,
                                itemBuilder: (context, index) {
                                  final cantiga = _filteredCantigas[index];
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(GingaRadius.lg),
                                      border: Border.all(color: GingaColors.borderLight),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SongDetailScreen(cantiga: cantiga),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              // Icono decorativo de audio
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: GingaColors.brandGreen.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                                ),
                                                child: const Icon(
                                                  Icons.music_video_rounded,
                                                  color: GingaColors.brandGreen,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 14),

                                              // Información de la Cantiga
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      cantiga.titulo,
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: GingaColors.textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: GingaColors.cardLight,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            cantiga.ritmo,
                                                            style: GoogleFonts.montserrat(
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.w800,
                                                              color: cantiga.ritmo == 'Ladainha'
                                                                  ? Colors.purple
                                                                  : (cantiga.ritmo == 'Samba de Roda'
                                                                      ? GingaColors.accentAmber
                                                                      : GingaColors.brandGreen),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          cantiga.autor,
                                                          style: GoogleFonts.nunito(
                                                            fontSize: 11,
                                                            color: GingaColors.textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Botón circular Play
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: const BoxDecoration(
                                                  color: GingaColors.brandGreen,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // ─────────────────────────────────────────
                  //  PESTAÑA 2: HISTORIA & MESTRES
                  // ─────────────────────────────────────────
                  ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _articulos.length,
                    itemBuilder: (context, index) {
                      final articulo = _articulos[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: GingaColors.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.015),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _mostrarDetalleHistoria(context, articulo),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Icono Editorial
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: articulo.color.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(GingaRadius.md),
                                    ),
                                    child: Icon(articulo.icono, color: articulo.color, size: 26),
                                  ),
                                  const SizedBox(width: 14),

                                  // Textos descriptivos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              articulo.titulo,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: GingaColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: articulo.color.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                articulo.tag,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w800,
                                                  color: articulo.color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          articulo.subtitulo,
                                          style: GoogleFonts.nunito(
                                            fontSize: 12,
                                            color: GingaColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: GingaColors.textSecondary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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

// ── Modelos de datos locales auxiliares ──

class Cantiga {
  final String id;
  final String titulo;
  final String ritmo;
  final String autor;
  final String duracion;
  final String contexto;
  final String letraPt;
  final String letraEs;

  Cantiga({
    required this.id,
    required this.titulo,
    required this.ritmo,
    required this.autor,
    required this.duracion,
    required this.contexto,
    required this.letraPt,
    required this.letraEs,
  });
}

class HistoriaArticulo {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final String tag;
  final String contenido;

  HistoriaArticulo({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.tag,
    required this.contenido,
  });
}
