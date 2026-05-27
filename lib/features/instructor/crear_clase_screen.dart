import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';

class CrearClaseScreen extends StatefulWidget {
  const CrearClaseScreen({super.key});

  @override
  State<CrearClaseScreen> createState() => _CrearClaseScreenState();
}

class _CrearClaseScreenState extends State<CrearClaseScreen> {
  String _nombreClase = 'Kids';
  String _nivelSeleccionado = 'Iniciantes';
  String _selectedSede = 'Cusco';
  final _descripcionController = TextEditingController();

  final Set<String> _diasSeleccionados = {'J'};
  TimeOfDay _horaInicio = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 19, minute: 0);

  int _maxAlumnos = 12;
  String _modalidad = 'Presencial';
  final _ubicacionController = TextEditingController();
  bool _claseGratuita = true;
  bool _publicarInmediatamente = true;

  bool _isLoading = false;

  final List<String> _nombresClase = ['Kids', 'Adultos', 'Todos los niveles'];
  final List<String> _sedes = ['Cusco', 'U. Continental', 'Lima', 'Chimbote'];
  final List<String> _niveles = ['Iniciantes', 'Intermedio', 'Avanzado', 'Todos'];
  final List<String> _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  final List<String> _modalidades = ['Presencial', 'Online', 'Híbrido'];

  @override
  void dispose() {
    _descripcionController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool esInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: esInicio ? _horaInicio : _horaFin,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: GingaColors.brandGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => esInicio ? _horaInicio = picked : _horaFin = picked);
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _publicarClase() async {
    if (_diasSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecciona al menos un día',
            style: GoogleFonts.nunito(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('clases').add({
        'nombre': _nombreClase,
        'nivel': _nivelSeleccionado,
        'sede': _selectedSede,
        'badge': _nombreClase,
        'descripcion': _descripcionController.text.trim(),
        'dias': _diasSeleccionados.join(', '),
        'hora': _formatTime(_horaInicio),
        'hora_fin': _formatTime(_horaFin),
        'cupos_max': _maxAlumnos,
        'cupos_disponibles': _maxAlumnos,
        'modalidad': _modalidad,
        'ubicacion': _ubicacionController.text.trim(),
        'clase_gratuita': _claseGratuita,
        'publicar_inmediatamente': _publicarInmediatamente,
        'instructor_id': uid,
        'tipo': 'regular',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.go('/instructor-clase');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Clase publicada exitosamente!',
              style: GoogleFonts.nunito(color: Colors.white)),
          backgroundColor: GingaColors.brandGreen,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al publicar clase',
              style: GoogleFonts.nunito(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GingaColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Crear clase',
            style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: GingaColors.textPrimary)),
        centerTitle: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _publicarClase,
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.full),
                ),
                elevation: 0,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.add, size: 20),
              label: Text('Publicar clase',
                  style: GoogleFonts.montserrat(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Información básica ────────────────────────
            _buildCard(
              title: 'Información básica',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Nombre de la clase'),
                  const SizedBox(height: 8),
                  _dropdown(),
                  const SizedBox(height: 16),
                  _label('Sede de la clase'),
                  const SizedBox(height: 8),
                  _sedeDropdown(),
                  const SizedBox(height: 16),
                  _label('Nivel'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _niveles
                        .map((n) => _chip(
                              label: n,
                              selected: _nivelSeleccionado == n,
                              onTap: () => setState(() => _nivelSeleccionado = n),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _label('Descripción (opcional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descripcionController,
                    maxLines: 3,
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: GingaColors.textPrimary),
                    decoration: _inputDecoration(
                        'Describe el contenido o la dinámica de la clase...'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Horario recurrente ────────────────────────
            _buildCard(
              title: 'Horario recurrente',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Días de la clase'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _dias.map((dia) {
                      final sel = _diasSeleccionados.contains(dia);
                      return GestureDetector(
                        onTap: () => setState(() => sel
                            ? _diasSeleccionados.remove(dia)
                            : _diasSeleccionados.add(dia)),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: sel
                                ? GingaColors.brandGreen
                                : const Color(0xFFF0F0F0),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(dia,
                                style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? Colors.white
                                        : GingaColors.textSecondary)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Hora inicio'),
                            const SizedBox(height: 8),
                            _timePicker(_formatTime(_horaInicio),
                                () => _pickTime(true)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Hora fin'),
                            const SizedBox(height: 8),
                            _timePicker(_formatTime(_horaFin),
                                () => _pickTime(false)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Cupos y Modalidad ────────────────────────
            _buildCard(
              title: 'Cupos y Modalidad',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Máximo de alumnos'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _counterBtn(Icons.add,
                          () => setState(() => _maxAlumnos++)),
                      Expanded(
                        child: Center(
                          child: Text('$_maxAlumnos',
                              style: GoogleFonts.montserrat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: GingaColors.brandGreen)),
                        ),
                      ),
                      _counterBtn(Icons.remove, () {
                        if (_maxAlumnos > 1) setState(() => _maxAlumnos--);
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Modalidad'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _modalidades
                        .map((m) => _chip(
                              label: m,
                              selected: _modalidad == m,
                              onTap: () => setState(() => _modalidad = m),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _label('Ubicación'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ubicacionController,
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: GingaColors.textPrimary),
                    decoration: _inputDecoration('Parque de la roda').copyWith(
                      suffixIcon: const Icon(Icons.location_on_outlined,
                          color: GingaColors.textSecondary, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _toggleRow(
                    title: 'Clase de prueba gratuita',
                    subtitle: 'Primera clase gratis para alumnos nuevos',
                    value: _claseGratuita,
                    onChanged: (v) => setState(() => _claseGratuita = v),
                  ),
                  const Divider(height: 24, color: GingaColors.borderLight),
                  _toggleRow(
                    title: 'Publicar inmediatamente',
                    subtitle: 'Visible para los alumnos al publicar',
                    value: _publicarInmediatamente,
                    onChanged: (v) =>
                        setState(() => _publicarInmediatamente = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Precio ────────────────────────────────────
            _buildCard(
              title: null,
              child: Column(
                children: [
                  _precioRow('Precio por clase', 'Para alumnos recurrentes',
                      'S/. 35'),
                  const Divider(height: 24, color: GingaColors.borderLight),
                  _precioRow('Primera clase', 'Alumnos nuevos', 'gratis'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Banner info ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GingaColors.brandGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(GingaRadius.md),
                border: Border.all(
                    color: GingaColors.brandGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: GingaColors.brandGreen, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'La clase quedara publicada y los alumnos podrán reservar su lugar desde la sección ARoda. Recibirás una notificación por cada reserva confirmada',
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: GingaColors.brandGreen),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────

  Widget _buildCard({required String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title,
                style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.textPrimary)),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.nunito(
          fontSize: 12, color: GingaColors.textSecondary));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.nunito(color: GingaColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          borderSide:
              const BorderSide(color: GingaColors.brandGreen, width: 2),
        ),
      );

  Widget _dropdown() => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(GingaRadius.md),
          border: Border.all(color: GingaColors.borderLight),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _nombreClase,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down,
                color: GingaColors.textSecondary),
            style: GoogleFonts.nunito(
                fontSize: 14, color: GingaColors.textPrimary),
            items: _nombresClase
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (val) => setState(() => _nombreClase = val!),
          ),
        ),
      );

  Widget _sedeDropdown() => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(GingaRadius.md),
          border: Border.all(color: GingaColors.borderLight),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedSede,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down,
                color: GingaColors.textSecondary),
            style: GoogleFonts.nunito(
                fontSize: 14, color: GingaColors.textPrimary),
            items: _sedes
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (val) => setState(() => _selectedSede = val!),
          ),
        ),
      );

  Widget _chip(
          {required String label,
          required bool selected,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? GingaColors.brandGreen
                : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(GingaRadius.full),
          ),
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : GingaColors.textSecondary)),
        ),
      );

  Widget _timePicker(String time, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(color: GingaColors.borderLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(time,
                  style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary)),
              const Icon(Icons.access_time,
                  color: GingaColors.textSecondary, size: 18),
            ],
          ),
        ),
      );

  Widget _counterBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(GingaRadius.sm),
          ),
          child: Icon(icon, size: 20, color: GingaColors.textPrimary),
        ),
      );

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary)),
                Text(subtitle,
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: GingaColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: GingaColors.brandGreen,
            activeTrackColor: GingaColors.brandGreen.withValues(alpha: 0.4),
          ),
        ],
      );

  Widget _precioRow(String title, String subtitle, String precio) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textPrimary)),
                Text(subtitle,
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: GingaColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: GingaColors.brandGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(GingaRadius.full),
            ),
            child: Text(precio,
                style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: GingaColors.brandGreen)),
          ),
        ],
      );
}
