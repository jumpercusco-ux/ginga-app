import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/ginga_theme.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _cordaController = TextEditingController();
  final _sedeController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _dniController = TextEditingController();
  final _contactoNombreController = TextEditingController();
  final _contactoTelefonoController = TextEditingController();
  final _observacionesController = TextEditingController();

  // State values
  String _selectedSede = 'Virtual / A Distancia';
  String? _selectedGenero;
  String? _selectedGrupoSanguineo;
  DateTime? _fechaNacimiento;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _sedes = ['Virtual / A Distancia', 'Lima', 'Cusco', 'Chimbote', 'U. Continental'];
  final List<String> _generos = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];
  final List<String> _gruposSanguineos = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _cordaController.dispose();
    _sedeController.dispose();
    _telefonoController.dispose();
    _dniController.dispose();
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          _nombreController.text = data['nombre'] ?? '';
          _emailController.text = data['email'] ?? '';
          _cordaController.text = data['corda'] ?? 'Crua';
          _sedeController.text = data['sede'] ?? 'Virtual / A Distancia';
          _telefonoController.text = data['telefono'] ?? '';
          _dniController.text = data['dni'] ?? '';
          _contactoNombreController.text = data['contacto_emergencia_nombre'] ?? '';
          _contactoTelefonoController.text = data['contacto_emergencia_telefono'] ?? '';
          _observacionesController.text = data['observaciones_medicas'] ?? '';

          if (data['genero'] != null && _generos.contains(data['genero'])) {
            _selectedGenero = data['genero'];
          }
          if (data['grupo_sanguineo'] != null && _gruposSanguineos.contains(data['grupo_sanguineo'])) {
            _selectedGrupoSanguineo = data['grupo_sanguineo'];
          }
          if (data['fecha_nacimiento'] != null) {
            _fechaNacimiento = (data['fecha_nacimiento'] as Timestamp).toDate();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos de perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _seleccionarFechaNacimiento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(2000),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: buildGingaDatePickerTheme,
    );
    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final Map<String, dynamic> updatedData = {
      'telefono': _telefonoController.text.trim(),
      'dni': _dniController.text.trim(),
      'genero': _selectedGenero,
      'grupo_sanguineo': _selectedGrupoSanguineo,
      'fecha_nacimiento': _fechaNacimiento != null ? Timestamp.fromDate(_fechaNacimiento!) : null,
      'contacto_emergencia_nombre': _contactoNombreController.text.trim(),
      'contacto_emergencia_telefono': _contactoTelefonoController.text.trim(),
      'observaciones_medicas': _observacionesController.text.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(updatedData, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Ficha de datos actualizada con éxito! 🥋'),
            backgroundColor: GingaColors.brandGreen,
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Suscribir al tema para regenerar la pantalla al alternar claro/oscuro
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Ficha del Alumno',
          style: GoogleFonts.montserrat(
            color: GingaColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: GingaColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GingaColors.brandGreen),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SECCIÓN 1: Cuenta y Academia
                          _buildSeccionHeader('Datos de Cuenta y Academia 🥋'),
                          _buildDisabledField(
                            controller: _nombreController,
                            label: 'Nombre Completo',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildDisabledField(
                            controller: _emailController,
                            label: 'Correo Electrónico',
                            icon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildDisabledField(
                            controller: _cordaController,
                            label: 'Graduación / Corda',
                            icon: Icons.shield_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildDisabledField(
                            controller: _sedeController,
                            label: 'Sede de Entrenamiento',
                            icon: Icons.location_on_outlined,
                          ),

                          const SizedBox(height: 28),

                          // SECCIÓN 2: Información Personal
                          _buildSeccionHeader('Información Personal 📋'),
                          _buildTextField(
                            controller: _telefonoController,
                            label: 'Número de Teléfono',
                            hint: 'Ej: 987654321',
                            icon: Icons.phone_android_rounded,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val != null && val.isNotEmpty) {
                                if (!RegExp(r'^[0-9+\s-]{7,15}$').hasMatch(val)) {
                                  return 'Número de teléfono inválido';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _dniController,
                            label: 'DNI / Documento de Identidad',
                            hint: 'Ej: 77665544',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          _buildDatePickerField(
                            label: 'Fecha de Nacimiento',
                            icon: Icons.cake_outlined,
                            date: _fechaNacimiento,
                            onTap: _seleccionarFechaNacimiento,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            value: _selectedGenero,
                            label: 'Género',
                            hint: 'Selecciona tu género',
                            icon: Icons.face_outlined,
                            items: _generos,
                            onChanged: (val) {
                              setState(() => _selectedGenero = val);
                            },
                          ),

                          const SizedBox(height: 28),

                          // SECCIÓN 3: Salud y Emergencias
                          _buildSeccionHeader('Salud y Emergencias 🚨'),
                          _buildTextField(
                            controller: _contactoNombreController,
                            label: 'Contacto de Emergencia (Nombre)',
                            hint: 'Ej: María Gómez (Mamá)',
                            icon: Icons.contact_emergency_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _contactoTelefonoController,
                            label: 'Contacto de Emergencia (Teléfono)',
                            hint: 'Ej: 999888777',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val != null && val.isNotEmpty) {
                                  if (!RegExp(r'^[0-9+\s-]{7,15}$').hasMatch(val)) {
                                    return 'Número de teléfono inválido';
                                  }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            value: _selectedGrupoSanguineo,
                            label: 'Grupo Sanguíneo',
                            hint: 'Selecciona tu tipo de sangre',
                            icon: Icons.bloodtype_outlined,
                            items: _gruposSanguineos,
                            onChanged: (val) {
                              setState(() => _selectedGrupoSanguineo = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _observacionesController,
                            label: 'Observaciones Médicas / Alergias',
                            hint: 'Ingresa asma, lesiones previas, alergias a medicamentos, etc.',
                            icon: Icons.medical_services_outlined,
                            maxLines: 3,
                            requiredField: false,
                          ),

                          const SizedBox(height: 36),

                          // Botón Guardar
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _guardarPerfil,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GingaColors.brandGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: GingaColors.brandGreen.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Guardar Cambios',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSeccionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: GingaColors.brandGreen,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildDisabledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: false,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        color: GingaColors.textPrimary.withOpacity(0.7),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(
          color: GingaColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: GingaColors.textSecondary.withOpacity(0.6), size: 20),
        filled: true,
        fillColor: GingaColors.borderLight.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide: BorderSide(color: GingaColors.borderLight.withOpacity(0.5)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide: BorderSide(color: GingaColors.borderLight.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = false,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        color: GingaColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(
          color: GingaColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(
          color: GingaColors.textSecondary.withOpacity(0.5),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: GingaColors.textSecondary, size: 20),
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide: const BorderSide(color: GingaColors.brandGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator ?? (val) {
        if (requiredField && (val == null || val.trim().isEmpty)) {
          return 'Este campo es requerido';
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    String? hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        style: GoogleFonts.montserrat(
          fontSize: 14,
          color: GingaColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.montserrat(
            color: GingaColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.montserrat(
            color: GingaColors.textSecondary.withOpacity(0.5),
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: GingaColors.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        ),
        icon: Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: GingaColors.textSecondary),
        ),
        isExpanded: true,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required IconData icon,
    DateTime? date,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? GingaColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.transparent : GingaColors.borderLight;

    final text = date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Selecciona fecha';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GingaRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(GingaRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: GingaColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      color: GingaColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: date != null ? GingaColors.textPrimary : GingaColors.textSecondary.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today_outlined, color: GingaColors.textSecondary, size: 16),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
