import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      setState(() {
       switch (e.code) {
  case 'user-not-found':
    _errorMessage = 'No existe una cuenta con este email.';
    break;
  case 'wrong-password':
    _errorMessage = 'Contraseña incorrecta.';
    break;
  case 'invalid-credential':          // ← AGREGA ESTE
    _errorMessage = 'Email o contraseña incorrectos.';
    break;
  case 'invalid-email':
    _errorMessage = 'Email inválido.';
    break;
  case 'too-many-requests':
    _errorMessage = 'Demasiados intentos. Intenta más tarde.';
    break;
  default:
    _errorMessage = e.code; // ← cambia esto temporalmente para ver el error real
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // ── Logo ────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: GingaColors.brandGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.sports_martial_arts,
                      color: Colors.white, size: 40),
                ),

                const SizedBox(height: 20),

                Text(
                  'Ginga App',
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Inicia sesión para continuar',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: GingaColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 48),

                // ── Email ────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: GingaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: GingaColors.textSecondary, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Ingresa tu correo';
                    }
                    if (!val.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // ── Password ─────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: GingaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
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
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Ingresa tu contraseña';
                    }
                    if (val.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // ── Olvidé contraseña ────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _forgotPassword(),
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: GingaColors.brandGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // ── Error message ────────────────────
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
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Botón Login ──────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Iniciar Sesión',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Registro ─────────────────────────
                GestureDetector(
                  onTap: () => context.go('/role-selection'),
                  child: RichText(
                    text: TextSpan(
                      text: '¿No tienes cuenta? ',
                      style: GoogleFonts.nunito(
                        color: GingaColors.textSecondary,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: 'Regístrate',
                          style: GoogleFonts.nunito(
                            color: GingaColors.brandGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ingresa tu email primero',
              style: GoogleFonts.nunito(color: Colors.white)),
          backgroundColor: GingaColors.brandGreen,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email de recuperación enviado',
                style: GoogleFonts.nunito(color: Colors.white)),
            backgroundColor: GingaColors.brandGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar email',
                style: GoogleFonts.nunito(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}