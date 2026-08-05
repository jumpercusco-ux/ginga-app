import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/ginga_theme.dart';
import '../../core/models/cuerdas_fiu.dart';
import 'agent_prompt_screen.dart';

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
    'Todos', 'Nuevo', 'Conversando', 'Requiere atención', 'Reservado', 'Matriculado', 'Perdido'
  ];

  /// Convierte la etiqueta visible del filtro al valor real guardado en `status`.
  String _statusValueForLabel(String label) {
    if (label == 'Requiere atención') return 'requiere_atencion';
    return label.toLowerCase();
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'reservado':
        return GingaColors.accentAmber;
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
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        title: Text('Leads de WhatsApp',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: GingaColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
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
                  selectedColor: GingaColors.brandGreen.withOpacity(0.15),
                  labelStyle: TextStyle(color: selected ? GingaColors.brandGreen : GingaColors.textSecondary),
                  onSelected: (_) => setState(() => _selectedStatusFilter = label),
                );
              },
            ),
          ),
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
                        style: GoogleFonts.montserrat(color: GingaColors.textSecondary)),
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
                        style: GoogleFonts.montserrat(color: GingaColors.textSecondary)),
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
                      margin: const EdgeInsets.only(bottom: GingaSpacing.sm),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.lg)),
                      child: ListTile(
                        onTap: () => _mostrarDetalleLead(context, doc.id, data),
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(Icons.chat_bubble_outline, color: color),
                        ),
                        title: Text(nombre,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: GingaColors.textPrimary)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(telefono, style: GoogleFonts.montserrat(fontSize: 12, color: GingaColors.textSecondary)),
                            if (origen != null && origen['ad_id'] != null)
                              Text('Origen: anuncio ${origen['ad_id']}',
                                  style: GoogleFonts.montserrat(fontSize: 11, color: GingaColors.textSecondary)),
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
                                style: GoogleFonts.montserrat(fontSize: 10, color: GingaColors.textSecondary)),
                            const SizedBox(height: 4),
                            Icon(
                              aiHabilitada ? Icons.smart_toy_outlined : Icons.person_outline,
                              size: 16,
                              color: GingaColors.textSecondary,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (ctx) => _LeadDetalleSheet(leadId: leadId, leadData: leadData),
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
          title: Text('Convertir en alumno', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se crea un alumno "sin aplicación" (offline) para tu control interno, sin que necesite instalar la app.',
                  style: GoogleFonts.montserrat(fontSize: 12, color: GingaColors.textSecondary),
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
      await leadRef.update({'convertido_uid': newUserRef.id});

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
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: GingaColors.textPrimary)),
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: leadRef.snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final aiHabilitada = (data?['ai_habilitada'] ?? true) != false;
                  return Row(
                    children: [
                      Text('IA', style: GoogleFonts.montserrat(fontSize: 12, color: GingaColors.textSecondary)),
                      Switch(
                        value: aiHabilitada,
                        activeThumbColor: GingaColors.brandGreen,
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
                      Text('Ya convertido en alumno', style: GoogleFonts.montserrat(fontSize: 12, color: GingaColors.textSecondary)),
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
                          style: GoogleFonts.montserrat(fontSize: 11, color: GingaColors.textPrimary)),
                      backgroundColor: GingaColors.brandGreen.withOpacity(0.1),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          Divider(color: GingaColors.borderLight),
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
                    return Align(
                      alignment: esLead ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: esLead ? GingaColors.borderLight : GingaColors.brandGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                        child: Text(
                          data['texto'] ?? '',
                          style: GoogleFonts.montserrat(fontSize: 13, color: GingaColors.textPrimary),
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
                  decoration: const InputDecoration(hintText: 'Responder manualmente...'),
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
