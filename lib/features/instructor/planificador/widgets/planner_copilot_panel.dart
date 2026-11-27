import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/ginga_theme.dart';
import '../models/class_plan_models.dart';
import '../models/copilot_models.dart';
import '../theme/planner_palette.dart';
import '../services/planner_copilot_client.dart';
import '../services/planner_v2_engine_client.dart';

/// Panel conversacional contextual del Copiloto Pedagógico GINGA (`PED-04C3`).
/// Integrado en el Editor V2 sin modificar el tema global y con aprobación explícita
/// (Antes/Después, Aplicar, Descartar, Deshacer y detección de conflictos).
class PlannerCopilotPanel extends StatefulWidget {
  final ClassPlanModel currentPlan;
  final String currentDraftVersion;
  final ClassPlanBlock? selectedBlock;
  final ClassPlanExercise? selectedExercise;
  final List<PlannerResourceItem> availableResources;
  final PedagogicalContinuityContext? continuityContext;
  final PlannerCopilotClient copilotClient;
  final List<CopilotChatMessage> messages;
  final ValueChanged<List<CopilotChatMessage>> onMessagesChanged;
  final ValueChanged<CopilotChatMessage> onApplyProposal;
  final bool canUndo;
  final VoidCallback onUndoLastApply;
  final VoidCallback? onClose;

  const PlannerCopilotPanel({
    super.key,
    required this.currentPlan,
    required this.currentDraftVersion,
    this.selectedBlock,
    this.selectedExercise,
    this.availableResources = const [],
    this.continuityContext,
    required this.copilotClient,
    required this.messages,
    required this.onMessagesChanged,
    required this.onApplyProposal,
    this.canUndo = false,
    required this.onUndoLastApply,
    this.onClose,
  });

  @override
  State<PlannerCopilotPanel> createState() => _PlannerCopilotPanelState();
}

class _PlannerCopilotPanelState extends State<PlannerCopilotPanel> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant PlannerCopilotPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<String> _contextualQuickPrompts() {
    if (widget.selectedExercise != null) {
      return [
        'Explica errores frecuentes en "${widget.selectedExercise!.nombre}"',
        'Adapta "${widget.selectedExercise!.nombre}" por niveles',
        'Asegura participación simultánea sin filas',
      ];
    }
    return [
      'Explica progresiones seguras de Ginga, Armada y Aú',
      'Sustituye un juego por otro técnico de Armada',
      'Redistribuye la clase a 45 minutos',
      if (widget.availableResources.isNotEmpty)
        'Incorpora el recurso "${widget.availableResources.first.title}"',
    ];
  }

  Future<void> _sendPrompt([String? forcedText]) async {
    final text = (forcedText ?? _inputCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    final userMsg = CopilotChatMessage(
      id: 'msg_u_${DateTime.now().microsecondsSinceEpoch}',
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
    );
    final withUser = [...widget.messages, userMsg];
    widget.onMessagesChanged(withUser);

    setState(() {
      _sending = true;
      _errorMessage = null;
      if (forcedText == null) {
        _inputCtrl.clear();
      }
    });

    try {
      final resp = await widget.copilotClient.sendMessage(
        plan: widget.currentPlan,
        baseDraftVersion: widget.currentDraftVersion,
        message: text,
        selectedBlockId: widget.selectedBlock?.blockId,
        selectedExerciseId: widget.selectedExercise?.exerciseId,
        availableResources: widget.availableResources,
        conversationHistory: widget.messages,
        continuityContext: widget.continuityContext,
      );
      if (!mounted) return;
      final assistantMsg = CopilotChatMessage(
        id: 'msg_a_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        text: resp.assistantMessage,
        timestamp: DateTime.now(),
        response: resp,
      );
      widget.onMessagesChanged([...withUser, assistantMsg]);
      setState(() => _sending = false);
    } on PlannerV2EngineException catch (e) {
      if (!mounted) return;
      // Restaura texto en caso de error para no perder lo escrito ni el borrador.
      if (forcedText == null && _inputCtrl.text.trim().isEmpty) {
        _inputCtrl.text = text;
      }
      setState(() {
        _sending = false;
        _errorMessage = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      if (forcedText == null && _inputCtrl.text.trim().isEmpty) {
        _inputCtrl.text = text;
      }
      setState(() {
        _sending = false;
        _errorMessage =
            'Error inesperado consultando al copiloto ($e). Tu borrador sigue intacto.';
      });
    }
  }

  void _discardProposal(CopilotChatMessage msg) {
    final updated = [
      for (final m in widget.messages)
        if (m.id == msg.id)
          m.copyWith(resolution: CopilotProposalResolution.discarded)
        else
          m,
    ];
    widget.onMessagesChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final pal = PlannerPalette.of(context);
    final contextLabel = widget.selectedExercise != null
        ? '${widget.selectedBlock?.fase ?? 'Bloque'} · ${widget.selectedExercise!.nombre}'
        : widget.selectedBlock != null
            ? 'Bloque: ${widget.selectedBlock!.fase}'
            : 'Toda la clase (${widget.currentPlan.duracionTotal} min)';

    return Container(
      key: const Key('copilot_panel_root'),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 18, color: pal.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copiloto Pedagógico GINGA',
                        style: GoogleFonts.montserrat(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                      Text(
                        'Consultas y ajustes controlados (aprobación manual)',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.canUndo)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: TextButton.icon(
                      key: const Key('copilot_undo_button'),
                      onPressed: widget.onUndoLastApply,
                      icon: const Icon(Icons.undo_rounded, size: 15),
                      label: Text(
                        'Deshacer',
                        style: GoogleFonts.montserrat(
                            fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                if (widget.onClose != null)
                  IconButton(
                    key: const Key('copilot_close_button'),
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close, size: 18, color: pal.textSecondary),
                    tooltip: 'Cerrar copiloto',
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: pal.border),

          // Indicador de contexto activo
          Container(
            key: const Key('copilot_context_indicator'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: pal.surfaceTint,
            child: Row(
              children: [
                Icon(Icons.center_focus_weak, size: 14, color: pal.infoBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Contexto activo: $contextLabel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sugerencias rápidas contextualizadas
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _contextualQuickPrompts())
                  ActionChip(
                    onPressed: _sending ? null : () => _sendPrompt(s),
                    backgroundColor: pal.background,
                    side: BorderSide(color: pal.border),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        s,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Mensajes de error no destructivos
          if (_errorMessage != null)
            Container(
              key: const Key('copilot_error_banner'),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(GingaRadius.md),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.montserrat(
                        fontSize: 11.5,
                        color: pal.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Hilo conversacional
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Pregúntame sobre progresiones, errores comunes o pídeme ajustar un ejercicio, enlazar un recurso de Pizarra o redistribuir la duración. Ningún cambio se aplicará sin tu aprobación.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: pal.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.messages.length,
                    itemBuilder: (ctx, i) => _buildMessageBubble(pal, widget.messages[i]),
                  ),
          ),

          if (_sending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: pal.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analizando clase y validando reglas pedagógicas...',
                    style: GoogleFonts.montserrat(
                      fontSize: 11.5,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Campo de entrada natural
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('copilot_input_field'),
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendPrompt(),
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      color: pal.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej. "Adapta Aú por niveles" o "Explica errores de Armada"',
                      hintStyle: GoogleFonts.montserrat(
                        fontSize: 11.5,
                        color: pal.textSecondary,
                      ),
                      filled: true,
                      fillColor: pal.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        borderSide: BorderSide(color: pal.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        borderSide: BorderSide(color: pal.accent, width: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const Key('copilot_send_button'),
                  onPressed: _sending ? null : () => _sendPrompt(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    backgroundColor: pal.accent,
                    foregroundColor: pal.onAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(PlannerPalette pal, CopilotChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: pal.accent,
            borderRadius: BorderRadius.circular(GingaRadius.md),
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pal.onAccent,
            ),
          ),
        ),
      );
    }

    final resp = msg.response;
    final isConflict = resp?.mode == CopilotMode.conflict || msg.conflictNotice != null;
    final hasProposal = resp?.hasApplicableChanges == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(
          color: isConflict
              ? pal.amber.withValues(alpha: 0.65)
              : hasProposal
                  ? pal.accent.withValues(alpha: 0.55)
                  : pal.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConflict
                    ? Icons.warning_amber_rounded
                    : hasProposal
                        ? Icons.difference_outlined
                        : Icons.chat_bubble_outline,
                size: 15,
                color: isConflict
                    ? pal.amber
                    : hasProposal
                        ? pal.accent
                        : pal.infoBlue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isConflict
                      ? 'Conflicto / Restricción pedagógica'
                      : hasProposal
                          ? 'Propuesta de modificación'
                          : 'Consulta pedagógica',
                  style: GoogleFonts.montserrat(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isConflict
                        ? pal.amber
                        : hasProposal
                            ? pal.accent
                            : pal.infoBlue,
                  ),
                ),
              ),
              if (resp != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (resp.isSimulated ? pal.textSecondary : pal.accent)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(GingaRadius.full),
                  ),
                  child: Text(
                    resp.isSimulated
                        ? 'Simulado offline'
                        : 'OpenAI · ${resp.modelName ?? 'gpt-4o-mini'}',
                    style: GoogleFonts.montserrat(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: resp.isSimulated ? pal.textSecondary : pal.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            msg.text,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: pal.textPrimary,
              height: 1.4,
            ),
          ),
          if (resp?.conflictReason != null && resp!.conflictReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Motivo: ${resp.conflictReason}',
              style: GoogleFonts.montserrat(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: pal.amber,
              ),
            ),
          ],
          if (resp?.safeAlternative != null && resp!.safeAlternative!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Alternativa segura: ${resp.safeAlternative}',
              style: GoogleFonts.montserrat(
                fontSize: 11.5,
                color: pal.textSecondary,
              ),
            ),
          ],
          if (msg.conflictNotice != null) ...[
            const SizedBox(height: 6),
            Text(
              msg.conflictNotice!,
              style: GoogleFonts.montserrat(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: pal.amber,
              ),
            ),
          ],
          if (hasProposal && resp!.diffSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final d in resp.diffSummary)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pal.surface,
                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d.scopeLabel} · ${d.fieldLabel}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Antes: ${d.before}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: pal.textSecondary,
                      ),
                    ),
                    Text(
                      'Después: ${d.after}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pal.accent,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (hasProposal) ...[
            const SizedBox(height: 6),
            if (msg.resolution == CopilotProposalResolution.pending)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ElevatedButton.icon(
                    key: const Key('copilot_apply_button'),
                    onPressed: () => widget.onApplyProposal(msg),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      backgroundColor: pal.accent,
                      foregroundColor: pal.onAccent,
                    ),
                    icon: const Icon(Icons.check, size: 15),
                    label: Text(
                      'Aplicar cambios',
                      style: GoogleFonts.montserrat(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('copilot_discard_button'),
                    onPressed: () => _discardProposal(msg),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      side: BorderSide(color: pal.border),
                      foregroundColor: pal.textSecondary,
                    ),
                    icon: const Icon(Icons.close, size: 15),
                    label: Text(
                      'Descartar',
                      style: GoogleFonts.montserrat(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )
            else
              Text(
                switch (msg.resolution) {
                  CopilotProposalResolution.applied => 'Cambios aplicados al borrador.',
                  CopilotProposalResolution.discarded => 'Propuesta descartada.',
                  CopilotProposalResolution.undone => 'Cambios revertidos (Deshacer).',
                  CopilotProposalResolution.staleConflict =>
                    'Propuesta desactualizada por edición manual posterior.',
                  CopilotProposalResolution.pending => '',
                },
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: msg.resolution == CopilotProposalResolution.applied
                      ? pal.accent
                      : pal.textSecondary,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
