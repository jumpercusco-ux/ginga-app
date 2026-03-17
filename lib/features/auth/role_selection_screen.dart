import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ginga_theme.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedRole = 'alumno';

  final List<_RoleOption> _roles = [
    _RoleOption(
      id: 'alumno',
      title: 'Alumno',
      subtitle: 'Explora clases, entrena y sigue tu progreso en el juego.',
      icon: Icons.directions_run,
    ),
    _RoleOption(
      id: 'profesor',
      title: 'Profesor',
      subtitle: 'Gestiona tus clases, alumnos y comparte tus conocimientos.',
      icon: Icons.school_outlined,
    ),
    _RoleOption(
      id: 'administrador',
      title: 'Administrador',
      subtitle: 'Control total de la academia, pagos y analíticas globales.',
      icon: Icons.settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sports_martial_arts,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ginga App',
                    style: GoogleFonts.montserrat(
                      color: GingaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Título
              Text(
                '¿Quién eres?',
                style: GoogleFonts.montserrat(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: GingaColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Selecciona tu perfil para comenzar tu\nexperiencia en la comunidad.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: GingaColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Opciones de rol
              Expanded(
                child: ListView.separated(
                  itemCount: _roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final role = _roles[index];
                    final isSelected = _selectedRole == role.id;
                    return _RoleCard(
                      role: role,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedRole = role.id),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Botón Continuar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/profile-creation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GingaColors.brandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continuar',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Ya tienes cuenta
              GestureDetector(
 onTap: () => context.go('/login'),                child: RichText(
                  text: TextSpan(
                    text: '¿Ya tienes una cuenta? ',
                    style: GoogleFonts.nunito(
                      color: GingaColors.textSecondary,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: 'Iniciar sesión',
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card de rol ─────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final _RoleOption role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? GingaColors.cardLight : Colors.white,
          borderRadius: BorderRadius.circular(GingaRadius.lg),
          border: Border.all(
            color: isSelected ? GingaColors.brandGreen : GingaColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Ícono
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? GingaColors.brandGreen.withOpacity(0.12)
                    : GingaColors.borderLight,
                borderRadius: BorderRadius.circular(GingaRadius.md),
              ),
              child: Icon(
                role.icon,
                color: isSelected
                    ? GingaColors.brandGreen
                    : GingaColors.textSecondary,
                size: 22,
              ),
            ),

            const SizedBox(width: 14),

            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role.subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: GingaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Radio button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? GingaColors.brandGreen
                      : GingaColors.borderLight,
                  width: 2,
                ),
                color: isSelected ? GingaColors.brandGreen : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modelo ──────────────────────────────────────────
class _RoleOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  _RoleOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}