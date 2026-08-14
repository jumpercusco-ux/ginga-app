import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/ginga_theme.dart';
import '../../core/models/cuerdas_fiu.dart';
import 'agent_prompt_screen.dart';

// Paleta oscura fija — mismo tratamiento que instructor_clase_screen/login:
// esta vista debe verse igual sin importar el modo de sistema del profesor.
const Color _kFondoOscuro = Colors.black;
const Color _kTarjetaOscura = Color(0xFF161616);
const Color _kBordeOscuro = Color(0x33FFFFFF);
const Color _kTextoSecundarioOscuro = Colors.white70;

/// Tema oscuro para el contenido de los AlertDialog de esta pantalla —
/// evita que los TextField/Dropdown por defecto (sin estilo propio)
/// hereden colores claros del tema ambiente sobre el fondo oscuro fijo.
ThemeData _darkDialogTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    canvasColor: _kTarjetaOscura,
    textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    colorScheme: base.colorScheme.copyWith(onSurface: Colors.white, onSurfaceVariant: _kTextoSecundarioOscuro),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
      floatingLabelStyle: GoogleFonts.montserrat(color: GingaColors.brandGreen),
      hintStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
      border: const OutlineInputBorder(borderSide: BorderSide(color: _kBordeOscuro)),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: _kBordeOscuro)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: GingaColors.brandGreen, width: 1.5)),
    ),
  );
}

/// Pipeline de leads capturados por WhatsApp (anuncios "Click to WhatsApp").
/// La IA responde automáticamente vía la Cloud Function `whatsappWebhook`;
/// aquí el profesor supervisa la conversación y puede tomar control manual.
class InstructorLeadsScreen extends StatefulWidget {
  const InstructorLeadsScreen({super.key});

  @override
  State<InstructorLeadsScreen> createState() => _InstructorLeadsScreenState();
}

class _InstructorLeadsScreenState extends State<InstructorLeadsScreen> {
  String _selectedStatusFilter = 'Todos';
  final List<String> _statuses = [
    'Todos', 'Nuevo', 'Conversando', 'Requiere atención', 'Reservado', 'Asistió', 'Matriculado', 'Perdido'
  ];

  /// Convierte la etiqueta visible del filtro al valor real guardado en `status`.
  String _statusValueForLabel(String label) {
    if (label == 'Requiere atención') return 'requiere_atencion';
    if (label == 'Asistió') return 'asistio';
    return label.toLowerCase();
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'reservado':
        return GingaColors.accentAmber;
      case 'asistio':
        return Colors.teal;
      case 'matriculado':
        return GingaColors.brandGreen;
      case 'conversando':
        return Colors.blue;
      case 'requiere_atencion':
        return Colors.deepOrange;
      case 'perdido':
        return Colors.red;
      case 'nuevo':
      default:
        return Colors.blueGrey;
    }
  }

  String _formatearHora(Timestamp? ts) {
    if (ts == null) return '';
    final fecha = ts.toDate();
    final ahora = DateTime.now();
    final esHoy = fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day;
    final hh = fecha.hour.toString().padLeft(2, '0');
    final mm = fecha.minute.toString().padLeft(2, '0');
    if (esHoy) return '$hh:$mm';
    return '${fecha.day}/${fecha.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondoOscuro,
      appBar: AppBar(
        backgroundColor: _kFondoOscuro,
        foregroundColor: Colors.white,
        title: Text('Leads de WhatsApp',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Configurar Agente IA',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AgentPromptScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: GingaSpacing.md, vertical: GingaSpacing.sm),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: GingaSpacing.sm),
              itemBuilder: (context, index) {
                final label = _statuses[index];
                final selected = _selectedStatusFilter == label;
                return ChoiceChip(
                  label: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 12)),
                  selected: selected,
                  backgroundColor: _kTarjetaOscura,
                  selectedColor: GingaColors.brandGreen.withOpacity(0.2),
                  side: BorderSide(color: selected ? GingaColors.brandGreen : _kBordeOscuro),
                  labelStyle: TextStyle(color: selected ? GingaColors.brandGreen : _kTextoSecundarioOscuro),
                  onSelected: (_) => setState(() => _selectedStatusFilter = label),
                );
              },
            ),
          ),
          const _ChecklistPruebasHoy(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('whatsapp_leads')
                  .orderBy('ultima_interaccion', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('Todavía no hay leads de WhatsApp.',
                        style: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro)),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  if (_selectedStatusFilter == 'Todos') return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? 'nuevo') as String;
                  return status == _statusValueForLabel(_selectedStatusFilter);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text('Sin leads en "$_selectedStatusFilter".',
                        style: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(GingaSpacing.md),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = (data['status'] ?? 'nuevo') as String;
                    final color = _colorForStatus(status);
                    final nombre = data['nombre'] ?? 'Lead';
                    final telefono = data['telefono'] ?? doc.id;
                    final origen = data['origen'] as Map<String, dynamic>?;
                    final aiHabilitada = data['ai_habilitada'] != false;
                    final ultimaInteraccion = data['ultima_interaccion'] as Timestamp?;

                    return Card(
                      color: _kTarjetaOscura,
                      margin: const EdgeInsets.only(bottom: GingaSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        side: const BorderSide(color: _kBordeOscuro),
                      ),
                      child: ListTile(
                        onTap: () => _mostrarDetalleLead(context, doc.id, data),
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(Icons.chat_bubble_outline, color: color),
                        ),
                        title: Text(nombre,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(telefono, style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro)),
                            if (origen != null && origen['ad_id'] != null)
                              Text('Origen: anuncio ${origen['ad_id']}',
                                  style: GoogleFonts.montserrat(fontSize: 11, color: _kTextoSecundarioOscuro)),
                            const SizedBox(height: 2),
                            StreamBuilder<QuerySnapshot>(
                              stream: doc.reference
                                  .collection('mensajes')
                                  .orderBy('timestamp', descending: true)
                                  .limit(1)
                                  .snapshots(),
                              builder: (context, msgSnapshot) {
                                if (!msgSnapshot.hasData || msgSnapshot.data!.docs.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final ultimoMsg = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                                final esDelLead = (ultimoMsg['from'] ?? 'lead') == 'lead';
                                final texto = (ultimoMsg['texto'] ?? '').toString();
                                return Text(
                                  esDelLead ? texto : 'Tú: $texto',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(status.toUpperCase(),
                                  style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                            ),
                            const SizedBox(height: 4),
                            Text(_formatearHora(ultimaInteraccion),
                                style: GoogleFonts.montserrat(fontSize: 10, color: _kTextoSecundarioOscuro)),
                            const SizedBox(height: 4),
                            Icon(
                              aiHabilitada ? Icons.smart_toy_outlined : Icons.person_outline,
                              size: 16,
                              color: _kTextoSecundarioOscuro,
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

  void _mostrarDetalleLead(BuildContext context, String leadId, Map<String, dynamic> leadData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kTarjetaOscura,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (ctx) => _LeadDetalleSheet(leadId: leadId, leadData: leadData),
    );
  }
}

/// Panel de check-in: muestra los leads en `reservado` para marcar si llegaron
/// a la clase de prueba, y permite dar de alta a quien vino acompañando a
/// alguien sin haber reservado antes por WhatsApp.
class _ChecklistPruebasHoy extends StatefulWidget {
  const _ChecklistPruebasHoy();

  @override
  State<_ChecklistPruebasHoy> createState() => _ChecklistPruebasHoyState();
}

class _ChecklistPruebasHoyState extends State<_ChecklistPruebasHoy> {
  bool _expandido = true;

  String _formatearFechaCorta(Timestamp ts) {
    const dias = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final f = ts.toDate();
    return '${dias[f.weekday]} ${f.day} de ${mesesCortos[f.month - 1]}';
  }

  void _mostrarDialogoWalkIn(BuildContext context) {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final edadController = TextEditingController();
    String tipoSeleccionado = 'niño';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _kTarjetaOscura,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            side: const BorderSide(color: _kBordeOscuro),
          ),
          title: Text('Agregar quien vino sin reservar',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: Colors.white)),
          content: Theme(
            data: _darkDialogTheme(dialogContext),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para poder darle seguimiento después (matrícula, avisos), como mínimo necesitamos su nombre y teléfono.',
                  style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro),
                ),
                const SizedBox(height: GingaSpacing.md),
                TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre completo *')),
                const SizedBox(height: GingaSpacing.sm),
                TextField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp * (con código de país)'),
                ),
                const SizedBox(height: GingaSpacing.sm),
                TextField(
                  controller: edadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Edad (opcional)'),
                ),
                const SizedBox(height: GingaSpacing.sm),
                DropdownButtonFormField<String>(
                  value: tipoSeleccionado,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'niño', child: Text('Niño/a')),
                    DropdownMenuItem(value: 'adulto', child: Text('Adulto')),
                  ],
                  onChanged: (val) => setDialogState(() => tipoSeleccionado = val ?? tipoSeleccionado),
                ),
              ],
            ),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreController.text.trim();
                final telefono = telefonoController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                if (nombre.isEmpty || telefono.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Nombre y teléfono son obligatorios.'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                try {
                  final edad = edadController.text.trim();
                  await FirebaseFirestore.instance.collection('whatsapp_leads').doc(telefono).set({
                    'telefono': telefono,
                    'nombre': nombre,
                    'status': 'asistio',
                    'perfil_personas': [
                      {'nombre': nombre, 'tipo': tipoSeleccionado, 'edad': edad.isNotEmpty ? edad : null},
                    ],
                    'origen': {'tipo': 'presencial'},
                    'created_at': FieldValue.serverTimestamp(),
                    'ultima_interaccion': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$nombre agregado(a) 🎉'), backgroundColor: GingaColors.brandGreen),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: GingaColors.brandGreen, foregroundColor: Colors.white),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('whatsapp_leads')
          .where('status', isEqualTo: 'reservado')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Container(
          margin: const EdgeInsets.fromLTRB(GingaSpacing.md, 0, GingaSpacing.md, GingaSpacing.sm),
          padding: const EdgeInsets.all(GingaSpacing.md),
          decoration: BoxDecoration(
            color: GingaColors.accentAmber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            border: Border.all(color: GingaColors.accentAmber.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _expandido = !_expandido),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text('Check-in de pruebas 📋',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                          ),
                          if (docs.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: GingaColors.accentAmber, borderRadius: BorderRadius.circular(10)),
                              child: Text('${docs.length}',
                                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(_expandido ? Icons.expand_less : Icons.expand_more, color: _kTextoSecundarioOscuro),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _mostrarDialogoWalkIn(context),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: Text('Agregar sin reserva', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    foregroundColor: GingaColors.brandGreen,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              if (_expandido)
                if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('No hay reservas pendientes de check-in.',
                        style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final nombreLead = data['nombre'] ?? doc.id;
                        final personas = (data['perfil_personas'] as List?) ?? [];
                        final nombresPersonas = personas
                            .whereType<Map>()
                            .map((p) => p['nombre'])
                            .whereType<String>()
                            .where((n) => n.trim().isNotEmpty)
                            .join(', ');
                        final etiqueta = nombresPersonas.isNotEmpty ? nombresPersonas : nombreLead;
                        final fechaReservada = data['fecha_clase_reservada'] as Timestamp?;
                        return Padding(
                          padding: const EdgeInsets.only(top: GingaSpacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(etiqueta,
                                        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                    if (fechaReservada != null)
                                      Text(_formatearFechaCorta(fechaReservada),
                                          style: GoogleFonts.montserrat(fontSize: 11, color: _kTextoSecundarioOscuro)),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => doc.reference
                                    .update({'status': 'asistio', 'ultima_interaccion': FieldValue.serverTimestamp()}),
                                style: TextButton.styleFrom(foregroundColor: GingaColors.brandGreen, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                child: Text('Asistió', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              TextButton(
                                onPressed: () => doc.reference
                                    .update({'status': 'perdido', 'ultima_interaccion': FieldValue.serverTimestamp()}),
                                style: TextButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                child: Text('No asistió', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ],
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

class _LeadDetalleSheet extends StatefulWidget {
  final String leadId;
  final Map<String, dynamic> leadData;
  const _LeadDetalleSheet({required this.leadId, required this.leadData});

  @override
  State<_LeadDetalleSheet> createState() => _LeadDetalleSheetState();
}

class _LeadDetalleSheetState extends State<_LeadDetalleSheet> {
  final TextEditingController _mensajeController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  String _formatearFechaHoraMensaje(Timestamp ts) {
    final fecha = ts.toDate();
    final dd = fecha.day.toString().padLeft(2, '0');
    final mm = fecha.month.toString().padLeft(2, '0');
    final hh = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${fecha.year} $hh:$min';
  }

  Future<void> _convertirEnAlumno(BuildContext context, DocumentReference leadRef) async {
    final nombreController = TextEditingController(text: widget.leadData['nombre'] ?? '');
    final sedesDisponibles = ['Cusco', 'Lima', 'Virtual / A Distancia', 'U. Continental', 'Chimbote'];
    String selectedSede = sedesDisponibles.first;
    String selectedCorda = CuerdasFIU.lista.first.nombre;
    String selectedStatus = 'activo';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _kTarjetaOscura,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            side: const BorderSide(color: _kBordeOscuro),
          ),
          title: Text('Convertir en alumno',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: Colors.white)),
          content: Theme(
            data: _darkDialogTheme(dialogContext),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se crea un alumno "sin aplicación" (offline) para tu control interno, sin que necesite instalar la app.',
                  style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro),
                ),
                const SizedBox(height: GingaSpacing.md),
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre completo'),
                ),
                const SizedBox(height: GingaSpacing.sm),
                DropdownButtonFormField<String>(
                  value: selectedSede,
                  decoration: const InputDecoration(labelText: 'Sede'),
                  items: sedesDisponibles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setDialogState(() => selectedSede = val ?? selectedSede),
                ),
                const SizedBox(height: GingaSpacing.sm),
                DropdownButtonFormField<String>(
                  value: selectedCorda,
                  decoration: const InputDecoration(labelText: 'Cuerda / Graduación inicial'),
                  items: CuerdasFIU.lista.map((c) => DropdownMenuItem(value: c.nombre, child: Text(c.nombre))).toList(),
                  onChanged: (val) => setDialogState(() => selectedCorda = val ?? selectedCorda),
                ),
                const SizedBox(height: GingaSpacing.sm),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'activo', child: Text('Activo')),
                    DropdownMenuItem(value: 'prueba', child: Text('Periodo de Prueba')),
                    DropdownMenuItem(value: 'nuevo', child: Text('Nuevo')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedStatus = val ?? selectedStatus),
                ),
              ],
            ),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: GingaColors.brandGreen, foregroundColor: Colors.white),
              child: const Text('Crear alumno'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || !context.mounted) return;

    final nombre = nombreController.text.trim();
    if (nombre.isEmpty) return;

    try {
      final whatsappId = (widget.leadData['telefono'] as String?) ?? widget.leadId;
      // Un BSUID (username de WhatsApp en vez de número compartido) tiene forma
      // "PE.123..." — si no calza con ese patrón, es un número real marcable.
      final esTelefonoReal = !RegExp(r'^[A-Z]{2}\.\d+$').hasMatch(whatsappId);

      final newUserRef = FirebaseFirestore.instance.collection('users').doc();
      await newUserRef.set({
        'uid': newUserRef.id,
        'nombre': nombre,
        'email': 'sin_app_${DateTime.now().millisecondsSinceEpoch}@ginga.app',
        'sede': selectedSede,
        'corda': selectedCorda,
        'rol': 'alumno',
        'status': selectedStatus,
        'is_offline': true,
        'created_at': FieldValue.serverTimestamp(),
        'whatsapp_id': whatsappId,
        'whatsapp_id_es_telefono': esTelefonoReal,
        'whatsapp_lead_id': widget.leadId,
        'notas': 'Convertido desde lead de WhatsApp ($whatsappId).',
      });
      await leadRef.update({'convertido_uid': newUserRef.id, 'status': 'matriculado'});

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Alumno "$nombre" creado con éxito.', style: GoogleFonts.montserrat(color: Colors.white)),
        backgroundColor: GingaColors.brandGreen,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al crear alumno: $e', style: GoogleFonts.montserrat(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
    }
  }

  /// Marca manualmente una reserva cuando TÚ coordinaste directo con la
  /// persona (con la IA apagada) — hace lo mismo que hacía la IA con
  /// reservar_clase_prueba: busca la clase real que le corresponde, guarda
  /// la reserva con fecha, y deja el lead en status 'reservado'.
  Future<void> _marcarComoReservado(BuildContext context, DocumentReference leadRef) async {
    final personas = (widget.leadData['perfil_personas'] as List?) ?? [];
    final primeraPersona = personas.isNotEmpty ? personas.first as Map : null;

    final nombreController = TextEditingController(
      text: (primeraPersona?['nombre'] as String?) ?? (widget.leadData['nombre'] as String?) ?? '',
    );
    String tipoSeleccionado = (primeraPersona?['tipo'] as String?) ?? 'adulto';
    DateTime? fechaSeleccionada;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _kTarjetaOscura,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            side: const BorderSide(color: _kBordeOscuro),
          ),
          title: Text('Marcar como reservado',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: Colors.white)),
          content: Theme(
            data: _darkDialogTheme(dialogContext),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Úsalo cuando coordinaste tú directamente (con la IA apagada) y quieres dejar la reserva guardada igual que si lo hubiera hecho la IA.',
                  style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro),
                ),
                const SizedBox(height: GingaSpacing.md),
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre de quien va a la clase'),
                ),
                const SizedBox(height: GingaSpacing.sm),
                DropdownButtonFormField<String>(
                  value: tipoSeleccionado,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'niño', child: Text('Niño/a')),
                    DropdownMenuItem(value: 'adulto', child: Text('Adulto')),
                  ],
                  onChanged: (val) => setDialogState(() => tipoSeleccionado = val ?? tipoSeleccionado),
                ),
                const SizedBox(height: GingaSpacing.sm),
                InkWell(
                  onTap: () async {
                    final ahora = DateTime.now();
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: ahora,
                      firstDate: ahora,
                      lastDate: ahora.add(const Duration(days: 90)),
                      // Las clases (incluida la de prueba) son solo martes y jueves.
                      selectableDayPredicate: (d) => d.weekday == DateTime.tuesday || d.weekday == DateTime.thursday,
                      builder: buildGingaDatePickerTheme,
                    );
                    if (picked != null) setDialogState(() => fechaSeleccionada = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha de la clase'),
                    child: Text(
                      fechaSeleccionada == null
                          ? 'Toca para elegir (solo martes o jueves)'
                          : '${fechaSeleccionada!.day.toString().padLeft(2, '0')}/${fechaSeleccionada!.month.toString().padLeft(2, '0')}/${fechaSeleccionada!.year}',
                      style: GoogleFonts.montserrat(
                        color: fechaSeleccionada == null ? _kTextoSecundarioOscuro : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: fechaSeleccionada == null || nombreController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: GingaColors.brandGreen, foregroundColor: Colors.white),
              child: const Text('Guardar reserva'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || !context.mounted || fechaSeleccionada == null) return;

    final nombre = nombreController.text.trim();
    if (nombre.isEmpty) return;

    try {
      final publicoBuscado = tipoSeleccionado == 'niño' ? 'niños' : 'jovenes_adultos';
      final claseSnap = await FirebaseFirestore.instance
          .collection('clases')
          .where('tipo', isEqualTo: 'regular')
          .where('publico', isEqualTo: publicoBuscado)
          .limit(1)
          .get();

      if (claseSnap.docs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No encontré una clase regular para "$tipoSeleccionado". Revisa la colección "clases".',
              style: GoogleFonts.montserrat(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final claseDoc = claseSnap.docs.first;
      final claseData = claseDoc.data();
      final fechaTimestamp = Timestamp.fromDate(
        DateTime(fechaSeleccionada!.year, fechaSeleccionada!.month, fechaSeleccionada!.day, 12),
      );

      final reservaRef = FirebaseFirestore.instance.collection('reservas').doc();
      await reservaRef.set({
        'lead_id': widget.leadId,
        'clase_id': claseDoc.id,
        'nombre_persona': nombre,
        'nivel': claseData['nivel'] ?? '',
        'hora': claseData['hora'] ?? '',
        'dias': claseData['dias'] ?? '',
        'fecha_clase': fechaTimestamp,
        'status': 'confirmado',
        'tipo': 'prueba',
        'origen': 'manual',
        'created_at': FieldValue.serverTimestamp(),
      });

      await leadRef.update({
        'status': 'reservado',
        'clase_reservada_id': claseDoc.id,
        'reserva_id': reservaRef.id,
        'fecha_clase_reservada': fechaTimestamp,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reserva guardada para $nombre.', style: GoogleFonts.montserrat(color: Colors.white)),
        backgroundColor: GingaColors.brandGreen,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al guardar la reserva: $e', style: GoogleFonts.montserrat(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _enviarMensajeManual() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    try {
      // No se usa cloud_functions/httpsCallable a propósito: en builds web release
      // (dart2js) tiene un bug conocido del plugin ("Unsupported operation: Int64
      // accessor not supported by dart2js") que rompe toda llamada callable con
      // parámetros. Se llama al endpoint HTTP directo con el mismo protocolo que
      // usa una callable function, para evitar esa serialización rota.
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final resp = await http.post(
        Uri.parse('https://us-central1-capoeirafiu-ea8ljo.cloudfunctions.net/sendManualWhatsAppMessage'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'data': {'leadId': widget.leadId, 'texto': texto},
        }),
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['error'] != null) {
        throw Exception(body['error']['message'] ?? 'Error desconocido');
      }
      _mensajeController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo enviar el mensaje: $e', style: GoogleFonts.montserrat(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadRef = FirebaseFirestore.instance.collection('whatsapp_leads').doc(widget.leadId);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.only(
        left: GingaSpacing.md,
        right: GingaSpacing.md,
        top: GingaSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + GingaSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.leadData['nombre'] ?? 'Lead',
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: leadRef.snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final aiHabilitada = (data?['ai_habilitada'] ?? true) != false;
                  return Row(
                    children: [
                      Text('IA', style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro)),
                      Switch(
                        value: aiHabilitada,
                        activeThumbColor: GingaColors.brandGreen,
                        activeTrackColor: GingaColors.brandGreen.withOpacity(0.3),
                        inactiveThumbColor: Colors.white70,
                        inactiveTrackColor: _kBordeOscuro,
                        onChanged: (value) => leadRef.update({'ai_habilitada': value}),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: leadRef.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final status = data?['status'] as String?;
              if (status == 'reservado') {
                return Padding(
                  padding: const EdgeInsets.only(top: GingaSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available, size: 16, color: GingaColors.accentAmber),
                      const SizedBox(width: 4),
                      Text('Ya tiene una reserva guardada', style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro)),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: GingaSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _marcarComoReservado(context, leadRef),
                    icon: const Icon(Icons.event_available, size: 16, color: GingaColors.accentAmber),
                    label: Text('Marcar como reservado', style: GoogleFonts.montserrat(fontSize: 12, color: GingaColors.accentAmber)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: GingaColors.accentAmber)),
                  ),
                ),
              );
            },
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: leadRef.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final status = data?['status'] as String?;
              if (status != 'requiere_atencion') return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: GingaSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => leadRef.update({'status': 'conversando'}),
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.deepOrange),
                    label: Text('Marcar como resuelto', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.deepOrange)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.deepOrange)),
                  ),
                ),
              );
            },
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: leadRef.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final convertidoUid = data?['convertido_uid'] as String?;
              if (convertidoUid != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: GingaSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: GingaColors.brandGreen),
                      const SizedBox(width: 4),
                      Text('Ya convertido en alumno', style: GoogleFonts.montserrat(fontSize: 12, color: _kTextoSecundarioOscuro)),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: GingaSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _convertirEnAlumno(context, leadRef),
                    icon: const Icon(Icons.school_outlined, size: 16, color: GingaColors.brandGreen),
                    label: Text('Convertir en alumno', style: GoogleFonts.montserrat(fontSize: 12, color: GingaColors.brandGreen)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: GingaColors.brandGreen)),
                  ),
                ),
              );
            },
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: leadRef.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final personas = data?['perfil_personas'] as List<dynamic>?;
              if (personas == null || personas.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: GingaSpacing.xs),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: personas.map((p) {
                    final persona = p as Map<String, dynamic>;
                    final nombre = persona['nombre'] ?? 'Sin nombre';
                    final tipo = persona['tipo'] ?? '';
                    final edad = persona['edad'];
                    return Chip(
                      label: Text('$nombre ($tipo${edad != null ? ', $edad años' : ''})',
                          style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white)),
                      backgroundColor: GingaColors.brandGreen.withOpacity(0.1),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          Divider(color: _kBordeOscuro),
          Flexible(
            child: StreamBuilder<QuerySnapshot>(
              stream: leadRef.collection('mensajes').orderBy('timestamp', descending: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(GingaSpacing.lg),
                    child: Center(child: CircularProgressIndicator(color: GingaColors.brandGreen)),
                  );
                }
                final mensajes = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: GingaSpacing.sm),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final data = mensajes[index].data() as Map<String, dynamic>;
                    final from = data['from'] ?? 'lead';
                    final esLead = from == 'lead';
                    final ts = data['timestamp'] as Timestamp?;
                    return Align(
                      alignment: esLead ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: esLead ? _kBordeOscuro : GingaColors.brandGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data['texto'] ?? '',
                              style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white),
                            ),
                            if (ts != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                _formatearFechaHoraMensaje(ts),
                                style: GoogleFonts.montserrat(fontSize: 10, color: _kTextoSecundarioOscuro),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: GingaSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mensajeController,
                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Responder manualmente...',
                    hintStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0x14FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      borderSide: const BorderSide(color: _kBordeOscuro),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      borderSide: const BorderSide(color: _kBordeOscuro),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      borderSide: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: GingaSpacing.sm),
              IconButton(
                icon: _enviando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, color: GingaColors.brandGreen),
                onPressed: _enviarMensajeManual,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
