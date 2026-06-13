import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/ginga_theme.dart';

class CrearCantigaScreen extends StatefulWidget {
  const CrearCantigaScreen({super.key});

  @override
  State<CrearCantigaScreen> createState() => _CrearCantigaScreenState();
}

class _CrearCantigaScreenState extends State<CrearCantigaScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores de Texto
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _autorController = TextEditingController(text: 'Tradicional');
  final TextEditingController _interpreteController = TextEditingController(text: 'Tradicional');
  final TextEditingController _duracionController = TextEditingController(text: '2:00');
  final TextEditingController _contextoController = TextEditingController();
  final TextEditingController _letraPtController = TextEditingController();
  final TextEditingController _letraEsController = TextEditingController();
  final TextEditingController _audioUrlController = TextEditingController();

  String _ritmoSeleccionado = 'Corrido';
  final List<String> _ritmos = ['Corrido', 'Ladainha', 'Samba de Roda', 'Quadra', 'Chula'];

  bool _isLoading = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _interpreteController.dispose();
    _duracionController.dispose();
    _contextoController.dispose();
    _letraPtController.dispose();
    _letraEsController.dispose();
    _audioUrlController.dispose();
    super.dispose();
  }

  Future<void> _publicarCantiga() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String registradoPor = user?.uid ?? 'anonimo';

      final docRef = FirebaseFirestore.instance.collection('cantigas').doc();
      
      await docRef.set({
        'titulo': _tituloController.text.trim(),
        'ritmo': _ritmoSeleccionado,
        'autor': _autorController.text.trim().isEmpty ? 'Tradicional' : _autorController.text.trim(),
        'interprete': _interpreteController.text.trim().isEmpty ? 'Tradicional' : _interpreteController.text.trim(),
        'duracion': _duracionController.text.trim().isEmpty ? '2:00' : _duracionController.text.trim(),
        'contexto': _contextoController.text.trim(),
        'letraPt': _letraPtController.text.trim(),
        'letraEs': _letraEsController.text.trim(),
        'audio_url': _audioUrlController.text.trim(),
        'letraPtSincronizada': [], // Inicialmente vacío para ser sincronizado con el Karaoke de Ginga
        'fecha_creacion': FieldValue.serverTimestamp(),
        'registrado_por': registradoPor,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Cantiga "${_tituloController.text.trim()}" agregada con éxito! 🎤',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: GingaColors.brandGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GingaRadius.md),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la cantiga: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra Superior Personalizada (App Bar) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: GingaColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Nueva Cantiga 🎤',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GingaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Formulario
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instrucción
                      Text(
                        'Completa los detalles de la nueva canción de capoeira. Una vez guardada, estará disponible de inmediato en la biblioteca y podrás sincronizar sus letras.',
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          color: GingaColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Título
                      _buildLabel('Título de la Cantiga *'),
                      TextFormField(
                        controller: _tituloController,
                        style: GoogleFonts.nunito(fontSize: 14.5, color: GingaColors.textPrimary, fontWeight: FontWeight.w600),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Por favor ingresa el título de la canción';
                          }
                          return null;
                        },
                        decoration: _buildInputDecoration(
                          hintText: 'Ej. Dona Maria Como Vai Você',
                          prefixIcon: Icons.title_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Fila de Ritmo y Autor
                      Row(
                        children: [
                          // Ritmo
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Ritmo *'),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(GingaRadius.md),
                                    border: Border.all(color: GingaColors.borderLight),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _ritmoSeleccionado,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: GingaColors.textSecondary),
                                      style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary, fontWeight: FontWeight.w700),
                                      items: _ritmos.map((ritmo) {
                                        return DropdownMenuItem<String>(
                                          value: ritmo,
                                          child: Text(ritmo),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _ritmoSeleccionado = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Duración
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Duración'),
                                TextFormField(
                                  controller: _duracionController,
                                  style: GoogleFonts.nunito(fontSize: 14.5, color: GingaColors.textPrimary, fontWeight: FontWeight.w600),
                                  decoration: _buildInputDecoration(
                                    hintText: 'Ej. 2:30',
                                    prefixIcon: Icons.timer_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Autor
                      _buildLabel('Autor / Mestre'),
                      TextFormField(
                        controller: _autorController,
                        style: GoogleFonts.nunito(fontSize: 14.5, color: GingaColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(
                          hintText: 'Ej. Tradicional o Mestre Pastinha',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Intérprete / Cantor
                      _buildLabel('Intérprete / Cantor'),
                      TextFormField(
                        controller: _interpreteController,
                        style: GoogleFonts.nunito(fontSize: 14.5, color: GingaColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(
                          hintText: 'Ej. Mestre Barrão o Mestre Toni Vargas',
                          prefixIcon: Icons.record_voice_over_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Contexto / Historia
                      _buildLabel('Contexto / Historia de la Cantiga'),
                      TextFormField(
                        controller: _contextoController,
                        style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                        maxLines: 3,
                        decoration: _buildInputDecoration(
                          hintText: '¿Cuándo se canta en la roda? ¿Cuál es su trasfondo histórico?',
                          prefixIcon: Icons.history_edu_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // URL Audio
                      _buildLabel('Enlace de Audio (.mp3) (Opcional)'),
                      TextFormField(
                        controller: _audioUrlController,
                        style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
                        decoration: _buildInputDecoration(
                          hintText: 'https://ejemplo.com/cancion.mp3',
                          prefixIcon: Icons.link_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Letra Portugués
                      _buildLabel('Letra en Portugués *'),
                      TextFormField(
                        controller: _letraPtController,
                        style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary, height: 1.4),
                        maxLines: 8,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Por favor ingresa la letra en portugués';
                          }
                          return null;
                        },
                        decoration: _buildInputDecoration(
                          hintText: 'Letra original (una línea por renglón para poder sincronizar el karaoke después).\n\nEj:\nDona Maria como vai você?\nEu vou bem, eu vou bem...',
                          prefixIcon: Icons.lyrics_outlined,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Letra Español
                      _buildLabel('Letra en Español (Traducción)'),
                      TextFormField(
                        controller: _letraEsController,
                        style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary, height: 1.4),
                        maxLines: 8,
                        decoration: _buildInputDecoration(
                          hintText: 'Traducción o adaptación en español de la letra para el aprendizaje de los alumnos.',
                          prefixIcon: Icons.translate_rounded,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Botón de Publicar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _publicarCantiga,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GingaColors.brandGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  'Publicar Cantiga 🚀',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: GingaColors.textPrimary,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hintText, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.nunito(fontSize: 13.5, color: GingaColors.textSecondary.withOpacity(0.55)),
      prefixIcon: Icon(prefixIcon, color: GingaColors.textSecondary.withOpacity(0.8), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
        borderSide: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GingaRadius.md),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      errorStyle: GoogleFonts.nunito(fontSize: 11, color: Colors.red.shade700),
    );
  }
}
