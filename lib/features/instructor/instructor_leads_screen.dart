import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/theme/ginga_theme.dart';

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
  final List<String> _statuses = ['Todos', 'Nuevo', 'Conversando', 'Reservado', 'Matriculado', 'Perdido'];

  Color _colorForStatus(String status) {
    switch (status) {
      case 'reservado':
        return GingaColors.accentAmber;
      case 'matriculado':
        return GingaColors.brandGreen;
      case 'conversando':
        return Colors.blue;
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
                  label: Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 12)),
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
                        style: GoogleFonts.nunito(color: GingaColors.textSecondary)),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  if (_selectedStatusFilter == 'Todos') return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? 'nuevo') as String;
                  return status.toLowerCase() == _selectedStatusFilter.toLowerCase();
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text('Sin leads en "$_selectedStatusFilter".',
                        style: GoogleFonts.nunito(color: GingaColors.textSecondary)),
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
                            Text(telefono, style: GoogleFonts.nunito(fontSize: 12, color: GingaColors.textSecondary)),
                            if (origen != null && origen['ad_id'] != null)
                              Text('Origen: anuncio ${origen['ad_id']}',
                                  style: GoogleFonts.nunito(fontSize: 11, color: GingaColors.textSecondary)),
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
                                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                            ),
                            const SizedBox(height: 4),
                            Text(_formatearHora(ultimaInteraccion),
                                style: GoogleFonts.nunito(fontSize: 10, color: GingaColors.textSecondary)),
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

  Future<void> _enviarMensajeManual() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('sendManualWhatsAppMessage').call({
        'leadId': widget.leadId,
        'texto': texto,
      });
      _mensajeController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo enviar el mensaje: $e', style: GoogleFonts.nunito(color: Colors.white)),
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
                      Text('IA', style: GoogleFonts.nunito(fontSize: 12, color: GingaColors.textSecondary)),
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
                          style: GoogleFonts.nunito(fontSize: 13, color: GingaColors.textPrimary),
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
