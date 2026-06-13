import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import 'dart:ui' as ui;

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
      // 1 — Login con Firebase Auth
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2 — Leer rol del usuario en Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!mounted) return;

      // 3 — Navegar según el rol
      if (doc.exists) {
        final rol = doc.data()?['rol'] ?? 'alumno';
        switch (rol) {
          case 'profesor':
            context.go('/instructor-clase');
            break;
          case 'administrador':
            context.go('/home'); // TODO: ruta admin
            break;
          default:
            context.go('/home');
        }
      } else {
        // Usuario sin perfil → crear perfil
        context.go('/profile-creation');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'No existe una cuenta con este email.';
            break;
          case 'wrong-password':
            _errorMessage = 'Contraseña incorrecta.';
            break;
          case 'invalid-credential':
            _errorMessage = 'Email o contraseña incorrectos.';
            break;
          case 'invalid-email':
            _errorMessage = 'Email inválido.';
            break;
          case 'too-many-requests':
            _errorMessage = 'Demasiados intentos. Intenta más tarde.';
            break;
          default:
            _errorMessage = 'Error al iniciar sesión. Intenta de nuevo.';
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

                // Logo
                Image.asset('assets/images/logo_ginga.png', width: 140, height: 140),
                const SizedBox(height: 20),

                Text('Inicia sesión para continuar',
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: GingaColors.textSecondary)),

                const SizedBox(height: 48),

                // Email
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
                    if (val == null || val.isEmpty) return 'Ingresa tu correo';
                    if (!val.contains('@')) return 'Correo inválido';
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
                    if (val == null || val.isEmpty)
                      return 'Ingresa tu contraseña';
                    if (val.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // Olvidé contraseña
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _forgotPassword,
                    child: Text('¿Olvidaste tu contraseña?',
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: GingaColors.brandGreen,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

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

                // Botón Login
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
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Iniciar Sesión',
                            style: GoogleFonts.montserrat(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),

                const SizedBox(height: 24),

                // Registro
                GestureDetector(
                  onTap: () => context.go('/profile-creation'),
                  child: RichText(
                    text: TextSpan(
                      text: '¿No tienes cuenta? ',
                      style: GoogleFonts.nunito(
                          color: GingaColors.textSecondary, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Regístrate',
                          style: GoogleFonts.nunito(
                              color: GingaColors.brandGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
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
    _mostrarModalRecuperarPass(context);
  }

  void _mostrarModalRecuperarPass(BuildContext context) {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();
    bool isDialogLoading = false;
    bool isSent = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Dialog(
                backgroundColor: GingaColors.cardLight,
                elevation: 6,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  side: BorderSide(color: GingaColors.brandGreen.withOpacity(0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: isSent
                        ? _buildSuccessView(dialogContext)
                        : _buildFormView(
                            dialogContext,
                            formKey,
                            emailController,
                            isDialogLoading,
                            dialogError,
                            (fn) => setDialogState(fn),
                            (sentVal) => setDialogState(() => isSent = sentVal),
                            (loadingVal) => setDialogState(() => isDialogLoading = loadingVal),
                            (errorVal) => setDialogState(() => dialogError = errorVal),
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSuccessView(BuildContext dialogContext) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: GingaColors.brandGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: GingaColors.brandGreen,
            size: 36,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '¡Enlace Enviado!',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: GingaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Hemos enviado un correo de recuperación. Revisa tu bandeja de entrada o carpeta de spam.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13.5,
            color: GingaColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: GingaColors.brandGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GingaRadius.full),
              ),
              elevation: 0,
            ),
            child: Text(
              'Entendido',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView(
    BuildContext dialogContext,
    GlobalKey<FormState> formKey,
    TextEditingController emailController,
    bool isLoading,
    String? error,
    void Function(void Function()) setDialogState,
    void Function(bool) setSent,
    void Function(bool) setLoading,
    void Function(String?) setError,
  ) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                child: const Icon(
                  Icons.mail_lock_outlined,
                  color: GingaColors.brandGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recuperar Contraseña',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ingresa tu correo electrónico registrado y te enviaremos un enlace seguro para restablecer tu contraseña.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: GingaColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Correo electrónico',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: GingaColors.textSecondary,
                size: 20,
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Ingresa tu correo';
              if (!val.contains('@')) return 'Correo inválido';
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(GingaRadius.sm),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: GoogleFonts.nunito(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GingaColors.borderLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setLoading(true);
                            setError(null);

                            try {
                              await FirebaseAuth.instance.sendPasswordResetEmail(
                                email: emailController.text.trim(),
                              );
                              setSent(true);
                            } on FirebaseAuthException catch (e) {
                              switch (e.code) {
                                case 'user-not-found':
                                  setError('No existe una cuenta con este email.');
                                  break;
                                case 'invalid-email':
                                  setError('El email es inválido.');
                                  break;
                                default:
                                  setError('Error al enviar email. Intenta de nuevo.');
                              }
                            } catch (_) {
                              setError('Ocurrió un error inesperado.');
                            } finally {
                              setLoading(false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Enviar Enlace',
                            style: GoogleFonts.montserrat(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}