import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/ginga_theme.dart';

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({super.key});

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedSede = 'Virtual / A Distancia';
  String _selectedCorda = '';
  DateTime? _fechaInicio;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final List<String> _sedes = ['Virtual / A Distancia', 'Lima', 'Cusco', 'U. Continental', 'Chimbote'];
  final List<String> _cordas = [
    'Iniciante',
    'Corda Amarela',
    'Corda Laranja',
    'Corda Azul',
    'Corda Verde',
    'Corda Roxa',
    'Corda Marrom',
    'Corda Vermelha',
  ];

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2020),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: GingaColors.brandGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fechaInicio = picked);
  }

  Future<void> _crearPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1 — Crear usuario en Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2 — Guardar perfil en Firestore
      final Map<String, dynamic> userData = {
        'uid': credential.user!.uid,
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'sede': _selectedSede,
        'corda': 'Iniciante',
        'fecha_inicio': null,
        'rol': 'alumno',
        'created_at': FieldValue.serverTimestamp(),
        'status': 'nuevo',//los estados son con minuscula nuevo, prueba, activo, inactivo
      };

      if (_selectedSede == 'U. Continental') {
        userData['clase_id'] = 'iY6t5VpENijlWdzrHWWS';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set(userData);

      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'Este email ya está registrado.';
            break;
          case 'weak-password':
            _errorMessage = 'La contraseña debe tener al menos 6 caracteres.';
            break;
          case 'invalid-email':
            _errorMessage = 'Email inválido.';
            break;
          default:
            _errorMessage = 'Error al crear cuenta. Intenta de nuevo.';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

                // Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo_ginga.png', width: 100, height: 100),

                    // const SizedBox(width: 8),
                    // Text('Ginga App',
                    //     style: GoogleFonts.montserrat(
                    //         color: GingaColors.textPrimary,
                    //         fontWeight: FontWeight.w700,
                    //         fontSize: 15)),
                  ],
                ),

                const SizedBox(height: 28),

                Text('Tu Identidad',
                    style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary)),
                const SizedBox(height: 6),
                Text('Completa tu perfil de capoeira',
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: GingaColors.textSecondary)),

                const SizedBox(height: 28),

                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: GingaColors.cardLight,
                      child: const Icon(Icons.person_outline,
                          size: 40, color: GingaColors.textSecondary),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: GingaColors.brandGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Nombre
                _buildTextField(
                  controller: _nombreController,
                  hint: 'Nombre Completo',
                  icon: Icons.person_outline,
                ),

                const SizedBox(height: 14),

                // Email
                _buildTextField(
                  controller: _emailController,
                  hint: 'Correo electrónico',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Ingresa tu email';
                    if (!val.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: GingaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
                    hintStyle: GoogleFonts.nunito(
                        color: GingaColors.textSecondary, fontSize: 14),
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: GingaColors.textSecondary, size: 20),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: GingaColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      borderSide:
                          const BorderSide(color: GingaColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      borderSide:
                          const BorderSide(color: GingaColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      borderSide: const BorderSide(
                          color: GingaColors.brandGreen, width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'Ingresa una contraseña';
                    if (val.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                const SizedBox(height: 14),



                // Error
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Botón Crear Perfil
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _crearPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Crear Perfil',
                                  style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text(
                    '¿Ya tienes cuenta? Inicia sesión',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: GingaColors.brandGreen,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: GingaColors.brandGreen,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text('GINGA APP • COMUNIDAD GLOBAL',
                    style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: GingaColors.borderLight,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600)),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
            color: GingaColors.textSecondary, fontSize: 14),
        prefixIcon:
            Icon(icon, color: GingaColors.textSecondary, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      ),
      validator: validator ??
          (val) => val == null || val.isEmpty ? 'Este campo es requerido' : null,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GingaRadius.md),
        border: Border.all(color: GingaColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: GoogleFonts.nunito(
                  color: GingaColors.textSecondary, fontSize: 14)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: GingaColors.textSecondary),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item,
                        style: GoogleFonts.nunito(
                            fontSize: 14, color: GingaColors.textPrimary)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}