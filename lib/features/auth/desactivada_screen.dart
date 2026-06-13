import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/ginga_theme.dart';

class DesactivadaScreen extends StatelessWidget {
  const DesactivadaScreen({super.key});

  Future<void> _contactarProfesor(BuildContext context) async {
    const String mensaje = 
        '🥋 *Hola Profesor. Mi cuenta en la App Ginga figura como dada de baja/inactiva.*\n\n'
        'Me comunico para coordinar la renovación de mi membresía o revisar mi estado de inscripción en la academia. ¡Muchas gracias!';
        
    const String telefonoProfesor = '51954642457'; // Teléfono oficial
    final String url = 'https://wa.me/$telefonoProfesor?text=${Uri.encodeComponent(mensaje)}';

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir WhatsApp de soporte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono premium de candado/archivo con glow sutil
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  color: Colors.redAccent,
                  size: 50,
                ),
              ),
              const SizedBox(height: 32),

              // Títulos
              Text(
                'Acceso Desactivado 🔒',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: GingaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu perfil de alumno ha sido dado de baja o archivado por la administración de la academia.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: GingaColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para volver a activar tu cuenta y continuar entrenando, comunícate con tu profesor encargado para coordinar la renovación de tu membresía.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: GingaColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Botón Coordinar por WhatsApp
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _contactarProfesor(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // Verde WhatsApp
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.chat, size: 20),
                  label: Text(
                    'Coordinar por WhatsApp',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón Volver al Login / Cambiar Cuenta
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GingaColors.brandGreen,
                    side: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GingaRadius.full),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(
                    'Cerrar Sesión / Cambiar Cuenta',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
