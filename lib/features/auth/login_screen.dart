import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ginga_theme.dart';
import 'dart:ui' as ui;

// Colores fijos (no los tokens adaptativos de GingaColors) — esta pantalla
// es parte del flujo público y debe verse igual al Hero de la landing
// (fondo negro, texto blanco, acento verde), sin importar el modo de
// sistema del visitante.
const Color _kTarjetaOscura = Color(0xFF161616);
const Color _kBordeOscuro = Color(0x33FFFFFF);
const Color _kCampoFondoOscuro = Color(0x14FFFFFF);

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

  // Decoración fija (no depende de Theme.of(context) ni de GingaColors
  // adaptativos) — campos oscuros con buen contraste sobre fondo negro.
  InputDecoration _decoracionCampo({required String hintText, required Widget prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _kCampoFondoOscuro,
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
    );
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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    Widget bodyContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: isDesktop ? 24 : 40),

          // Volver al inicio — arriba a la izquierda de la tarjeta.
          SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/landing'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text('Ir al inicio',
                          style: GoogleFonts.montserrat(
                              fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: isDesktop ? 24 : 32),

          // Logo — versión blanca, la misma que usa el Hero/Footer de la landing.
          // Tocable también: otra forma de volver al inicio desde esta pantalla.
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.go('/landing'),
              child: Image.asset('assets/images/logofull.png', width: 140, height: 140),
            ),
          ),
          const SizedBox(height: 20),

          Text('Inicia sesión para continuar',
              style: GoogleFonts.montserrat(
                  fontSize: 14, color: Colors.white70)),

          const SizedBox(height: 48),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: GoogleFonts.montserrat(
                fontSize: 14, color: Colors.white),
            decoration: _decoracionCampo(
              hintText: 'Correo electrónico',
              prefixIcon: const Icon(Icons.email_outlined,
                  color: Colors.white54, size: 20),
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
            style: GoogleFonts.montserrat(
                fontSize: 14, color: Colors.white),
            decoration: _decoracionCampo(
              hintText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline,
                  color: Colors.white54, size: 20),
              suffixIcon: GestureDetector(
                onTap: () => setState(
                    () => _obscurePassword = !_obscurePassword),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white54,
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
                  style: GoogleFonts.montserrat(
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
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(GingaRadius.md),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade300, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: Colors.red.shade300)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Botón Login — blanco sobre negro, mismo contraste que el botón
          // secundario del Hero ("¿Ya eres alumno? Inicia sesión").
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
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
                          color: Colors.black, strokeWidth: 2),
                    )
                  : Text('Iniciar Sesión',
                      style: GoogleFonts.montserrat(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );

    if (isDesktop) {
      bodyContent = Container(
        margin: const EdgeInsets.symmetric(vertical: 40),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        decoration: BoxDecoration(
          color: _kTarjetaOscura,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(
            color: _kBordeOscuro,
            width: 1,
          ),
        ),
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 28),
              child: bodyContent,
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
                backgroundColor: _kTarjetaOscura,
                elevation: 6,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GingaRadius.lg),
                  side: const BorderSide(color: _kBordeOscuro),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
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
            color: GingaColors.brandGreen.withValues(alpha: 0.15),
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Hemos enviado un correo de recuperación. Revisa tu bandeja de entrada o carpeta de spam.',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 13.5,
            color: Colors.white70,
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
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
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
                  color: GingaColors.brandGreen.withValues(alpha: 0.15),
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
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ingresa tu correo electrónico registrado y te enviaremos un enlace seguro para restablecer tu contraseña.',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white),
            decoration: _decoracionCampo(
              hintText: 'Correo electrónico',
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: Colors.white54,
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
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(GingaRadius.sm),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade300, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: GoogleFonts.montserrat(fontSize: 12, color: Colors.red.shade300),
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
                      side: const BorderSide(color: _kBordeOscuro),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
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
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
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
                              color: Colors.black,
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
