import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/models/cuerdas_fiu.dart';

// Paleta oscura fija — mismo tratamiento que el resto del flujo de profesor.
const Color _kFondoOscuro = Colors.black;
const Color _kTarjetaOscura = Color(0xFF161616);
const Color _kBordeOscuro = Color(0x33FFFFFF);
const Color _kTextoSecundarioOscuro = Colors.white70;

/// Tema oscuro para el contenido de diálogos/formularios de esta pantalla —
/// evita que TextField/Dropdown por defecto hereden colores claros del tema
/// ambiente sobre el fondo oscuro fijo.
ThemeData _darkDialogTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    canvasColor: _kTarjetaOscura,
    textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    colorScheme: base.colorScheme.copyWith(onSurface: Colors.white, onSurfaceVariant: _kTextoSecundarioOscuro),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
      floatingLabelStyle: GoogleFonts.montserrat(color: GingaColors.brandGreen),
      hintStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
      border: const OutlineInputBorder(borderSide: BorderSide(color: _kBordeOscuro)),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: _kBordeOscuro)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: GingaColors.brandGreen, width: 1.5)),
    ),
  );
}

class InstructorAlumnosScreen extends StatefulWidget {
  const InstructorAlumnosScreen({super.key});

  @override
  State<InstructorAlumnosScreen> createState() => _InstructorAlumnosScreenState();
}

class _InstructorAlumnosScreenState extends State<InstructorAlumnosScreen> {
  String _searchQuery = '';
  String _selectedSedeFilter = 'Todos';
  final List<String> _sedes = ['Todos', 'Virtual / A Distancia', 'Lima', 'Cusco', 'U. Continental', 'Chimbote'];
  String _selectedStatusFilter = 'Todos';
  final List<String> _statuses = ['Todos', 'Activo', 'Nuevo', 'Prueba', 'Inactivo'];
  bool _showArchived = false;

  // Función para construir cada fila informativa de la Ficha
  Widget _buildFichaRow(IconData icon, String label, String value, {bool isAlert = false, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isAlert ? Colors.red : GingaColors.brandGreen),
          const SizedBox(width: 10),
          Text('$label: ', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextoSecundarioOscuro)),
          Expanded(
            child: Text(
              value, 
              style: GoogleFonts.montserrat(
                fontSize: 13, 
                fontWeight: FontWeight.w700, 
                color: isAlert ? Colors.red : Colors.white
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            suffix,
          ],
        ],
      ),
    );
  }

  // Modal para ver la Ficha Detallada del Alumno (disponible en todos los estados) - Con Scroll para evitar Overflows
  void _mostrarFichaAlumno(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] ?? 'nuevo';
    final userSede = data['sede'] ?? 'Sin sede';
    final corda = data['corda'] ?? 'Crua';
    final email = data['email'] ?? 'Sin correo';
    final String? fotoUrl = data['foto_url'];
    final created = data['created_at'] != null 
        ? (data['created_at'] as Timestamp).toDate()
        : null;
    final inicio = data['membresia_inicio'] != null
        ? (data['membresia_inicio'] as Timestamp).toDate()
        : null;
    final fin = data['membresia_fin'] != null
        ? (data['membresia_fin'] as Timestamp).toDate()
        : null;
    final meses = data['membresia_meses_pagados'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Habilita crecimiento dinámico de la hoja
      backgroundColor: _kTarjetaOscura,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85, // Límite de alto para no comerse la pantalla
          ),
          child: SingleChildScrollView( // Scroll de seguridad para pantallas pequeñas
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con avatar y estado
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: status == 'activo'
                          ? GingaColors.brandGreen.withOpacity(0.15)
                          : status == 'prueba'
                              ? GingaColors.accentAmber.withOpacity(0.15)
                              : status == 'nuevo'
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                      backgroundImage: fotoUrl != null && fotoUrl!.isNotEmpty
                          ? NetworkImage(fotoUrl!)
                          : null,
                      child: fotoUrl != null && fotoUrl!.isNotEmpty
                          ? null
                          : Icon(
                              Icons.person,
                              size: 32,
                              color: status == 'activo'
                                  ? GingaColors.brandGreen
                                  : status == 'prueba'
                                      ? GingaColors.accentAmber
                                      : status == 'nuevo'
                                          ? Colors.blue
                                          : Colors.red,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['nombre'] ?? 'Sin nombre',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: status == 'activo'
                                  ? GingaColors.brandGreen.withOpacity(0.15)
                                  : status == 'prueba'
                                      ? GingaColors.accentAmber.withOpacity(0.15)
                                      : status == 'nuevo'
                                          ? Colors.blue.withOpacity(0.15)
                                          : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: status == 'activo'
                                    ? GingaColors.brandGreen
                                    : status == 'prueba'
                                        ? GingaColors.accentAmber
                                        : status == 'nuevo'
                                            ? Colors.blue
                                            : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 32, color: _kBordeOscuro),

                // Datos Personales
                Text('Información Académica y de Contacto',
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextoSecundarioOscuro)),
                const SizedBox(height: 12),
                
                _buildFichaRow(Icons.email_outlined, 'Correo electrónico', email),
                _buildFichaRow(Icons.location_on_outlined, 'Sede asignada', userSede),
                _buildFichaRow(
                  Icons.sports_kabaddi_outlined, 
                  'Corda / Nivel', 
                  corda,
                  suffix: GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Cierra la ficha actual
                      _mostrarModalPromocionCorda(context, data, data['uid'] ?? '');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: GingaColors.brandGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: GingaColors.brandGreen,
                      ),
                    ),
                  ),
                ),
                if (created != null)
                  _buildFichaRow(Icons.calendar_today_outlined, 'Fecha de registro', '${created.day}/${created.month}/${created.year}'),

                Divider(height: 32, color: _kBordeOscuro),

                // Notas del Instructor
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Notas del Instructor 📝',
                        style: GoogleFonts.montserrat(
                            fontSize: 13, 
                            fontWeight: FontWeight.w700, 
                            color: _kTextoSecundarioOscuro)),
                    GestureDetector(
                      onTap: () {
                        _editarNotasAlumno(context, ctx, data);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: GingaColors.brandGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: GingaColors.brandGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kTarjetaOscura,
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    border: Border.all(color: _kBordeOscuro),
                  ),
                  child: Text(
                    data['notas']?.toString().trim().isNotEmpty == true
                        ? data['notas']
                        : 'Sin notas u observaciones para este alumno.',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: data['notas']?.toString().trim().isNotEmpty == true
                          ? Colors.white
                          : _kTextoSecundarioOscuro,
                      fontStyle: data['notas']?.toString().trim().isNotEmpty == true
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                ),

                Divider(height: 32, color: _kBordeOscuro),

                // Detalles de Membresía
                Text('Detalles de Membresía',
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextoSecundarioOscuro)),
                const SizedBox(height: 12),

                if (status == 'activo' || status == 'inactivo') ...[
                  if (inicio != null && fin != null) ...[
                    _buildFichaRow(Icons.play_circle_outline, 'Inicio de membresía', '${inicio.day}/${inicio.month}/${inicio.year}'),
                    _buildFichaRow(Icons.error_outline, 'Vencimiento de membresía', '${fin.day}/${fin.month}/${fin.year}', isAlert: status == 'inactivo'),
                    _buildFichaRow(Icons.payment_outlined, 'Meses contratados', '$meses ${meses == 1 ? 'mes' : 'meses'}'),
                  ] else
                    Text('No hay registros de fechas de membresía.', style: GoogleFonts.montserrat(fontSize: 13, color: _kTextoSecundarioOscuro)),
                ] else
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: _kTextoSecundarioOscuro),
                      const SizedBox(width: 8),
                      Text(
                        status == 'nuevo' 
                            ? 'Alumno recién registrado sin membresía.' 
                            : 'Alumno en periodo de prueba gratuita.',
                        style: GoogleFonts.montserrat(fontSize: 13, color: _kTextoSecundarioOscuro),
                      ),
                    ],
                  ),

                Divider(height: 32, color: _kBordeOscuro),

                _FichaProgresoCard(uid: data['uid'] ?? '', corda: corda),

                Divider(height: 32, color: _kBordeOscuro),

                _FichaAsistenciasCalendar(uid: data['uid'] ?? ''),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar ficha primero
                      _mostrarModalComunicado(context, targetStudentUid: data['uid'], targetStudentName: data['nombre']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GingaColors.brandGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.campaign, size: 18),
                    label: Text(
                      'Enviar Comunicado Push 📢',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _registrarAsistenciaRetroactiva(context, data);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GingaColors.brandGreen,
                      side: const BorderSide(color: GingaColors.brandGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      'Registrar Asistencia Manual',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar ficha antes de abrir el modal de compensación
                      _mostrarModalCompensacion(context, data);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GingaColors.accentAmber,
                      side: const BorderSide(color: GingaColors.accentAmber),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                    label: Text(
                      'Compensar por Feriado / Suspensión 📅',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (status == 'eliminado')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _reactivarAlumno(context, data['uid'] ?? '', data['nombre'] ?? '');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: Text(
                        'Reactivar Alumno ⚡',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _confirmarArchivarAlumno(context, data['uid'] ?? '', data['nombre'] ?? '');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.archive_outlined, size: 16),
                      label: Text(
                        'Dar de Baja / Archivar Alumno 📂',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmarArchivarAlumno(BuildContext context, String uid, String nombre) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: _kTarjetaOscura,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            side: const BorderSide(color: _kBordeOscuro),
          ),
          title: Text(
            '¿Dar de Baja Alumno? ⚠️',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: Colors.redAccent),
          ),
          content: Text(
            '¿Estás seguro de que deseas dar de baja a "$nombre"? Perderá acceso a la aplicación y no aparecerá en tus listas activas, pero se conservará su historial de pagos, pedidos y asistencias.',
            style: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _kTextoSecundarioOscuro),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _archivarAlumno(context, uid, nombre);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.md)),
              ),
              child: Text(
                'Dar de Baja',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _archivarAlumno(BuildContext context, String uid, String nombre) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: GingaColors.brandGreen),
      ),
    );

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'eliminado',
      });

      if (context.mounted) {
        Navigator.pop(context); // Quitar loader
        Navigator.pop(context); // Cerrar ficha de alumno

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alumno "$nombre" dado de baja con éxito 📂'),
            backgroundColor: GingaColors.brandGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Quitar loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al dar de baja: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reactivarAlumno(BuildContext context, String uid, String nombre) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: GingaColors.brandGreen),
      ),
    );

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'activo',
      });

      if (context.mounted) {
        Navigator.pop(context); // Quitar loader
        Navigator.pop(context); // Cerrar ficha de alumno

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alumno "$nombre" reactivado con éxito ⚡'),
            backgroundColor: GingaColors.brandGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Quitar loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reactivar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Modal interactivo de creación de comunicados y envío masivo/individual
  void _mostrarModalComunicado(BuildContext context, {String? targetStudentUid, String? targetStudentName}) {
    final bool isIndividual = targetStudentUid != null;
    
    // Controladores
    final TextEditingController tituloController = TextEditingController(text: isIndividual ? 'Aviso del Profesor 📢' : 'Anuncio General 📢');
    final TextEditingController mensajeController = TextEditingController();
    
    // Variables de Estado de Filtros
    String scopeSeleccionado = isIndividual ? 'Individual' : 'Todos';
    
    String sedeSeleccionada = 'Cusco';
    String? claseSeleccionadaId;
    String screenSeleccionado = 'home';
    String? claseRedireccionId;
    String? tutorialRedireccionId;
    String? cantigaRedireccionId;
    String? productoRedireccionId;
    bool isDataLoaded = false;
    List<QueryDocumentSnapshot> clasesList = [];
    List<QueryDocumentSnapshot> tutorialesList = [];
    List<QueryDocumentSnapshot> cantigasList = [];
    List<QueryDocumentSnapshot> productosList = [];
    bool enviando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kTarjetaOscura,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext contextModal, setStateModal) {
            return FutureBuilder<List<QuerySnapshot>>(
              future: Future.wait([
                FirebaseFirestore.instance.collection('clases').get(),
                FirebaseFirestore.instance.collection('tutoriales').get(),
                FirebaseFirestore.instance.collection('cantigas').get(),
                FirebaseFirestore.instance.collection('productos').get(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.hasData && !isDataLoaded) {
                  clasesList = snapshot.data![0].docs;
                  tutorialesList = snapshot.data![1].docs;
                  cantigasList = snapshot.data![2].docs;
                  productosList = snapshot.data![3].docs;
                  isDataLoaded = true;
                  if (clasesList.isNotEmpty) {
                    claseSeleccionadaId = clasesList.first.id;
                    claseRedireccionId = clasesList.first.id;
                  }
                  if (tutorialesList.isNotEmpty) {
                    tutorialRedireccionId = tutorialesList.first.id;
                  }
                  if (cantigasList.isNotEmpty) {
                    cantigaRedireccionId = cantigasList.first.id;
                  }
                  if (productosList.isNotEmpty) {
                    productoRedireccionId = productosList.first.id;
                  }
                }

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(contextModal).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(contextModal).viewInsets.bottom +
                          (MediaQuery.of(contextModal).padding.bottom > 0
                              ? MediaQuery.of(contextModal).padding.bottom + 12
                              : 20),
                      left: 20,
                      right: 20,
                      top: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.campaign, color: GingaColors.brandGreen, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isIndividual ? 'Enviar Comunicado Individual' : 'Enviar Comunicado / Anuncio',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isIndividual 
                              ? 'Enviar un mensaje push y buzón a: $targetStudentName' 
                              : 'Envía un mensaje push masivo y regístralo en la campana de los alumnos.',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: _kTextoSecundarioOscuro,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Selector de Destinatarios (Si no es individual)
                        if (!isIndividual) ...[
                          Text(
                            'Enviar a:',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: scopeSeleccionado,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                borderSide: BorderSide(color: _kBordeOscuro),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                borderSide: BorderSide(color: _kBordeOscuro),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                borderSide: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                              ),
                            ),
                            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                            items: ['Todos', 'Por Sede', 'Por Clase'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value == 'Todos' ? 'Todos los Alumnos 🥋' : value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setStateModal(() {
                                  scopeSeleccionado = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Filtros Condicionales
                        if (scopeSeleccionado == 'Por Sede' && !isIndividual) ...[
                          Text(
                            'Seleccionar Sede:',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: sedeSeleccionada,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                borderSide: BorderSide(color: _kBordeOscuro),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                borderSide: BorderSide(color: _kBordeOscuro),
                              ),
                            ),
                            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                            items: ['Cusco', 'Lima', 'Chimbote', 'Virtual / A Distancia'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setStateModal(() {
                                  sedeSeleccionada = val;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (scopeSeleccionado == 'Por Clase' && !isIndividual) ...[
                          Text(
                            'Seleccionar Clase:',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
                          else if (clasesList.isEmpty)
                            Text('No hay clases creadas en el sistema.', style: GoogleFonts.montserrat(color: Colors.red))
                          else
                            DropdownButtonFormField<String>(
                              value: claseSeleccionadaId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                              ),
                              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                              items: clasesList.map((doc) {
                                final cdata = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text('${cdata['nombre'] ?? 'Sin nombre'} (${cdata['sede'] ?? 'Sin sede'})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateModal(() {
                                    claseSeleccionadaId = val;
                                  });
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                        ],

                        // Título del Mensaje
                        Text(
                          'Título de la Notificación:',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: tituloController,
                          decoration: InputDecoration(
                            hintText: 'Ingresa un título llamativo...',
                            hintStyle: GoogleFonts.montserrat(fontSize: 13, color: _kTextoSecundarioOscuro),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                          ),
                          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),

                        // Mensaje / Comunicado
                        Text(
                          'Mensaje del Comunicado:',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: mensajeController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Escribe tu anuncio aquí...',
                            hintStyle: GoogleFonts.montserrat(fontSize: 13, color: _kTextoSecundarioOscuro),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                          ),
                          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),

                        // Redirección del Comunicado
                        Text(
                          'Pantalla de Destino (Redirección):',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: screenSeleccionado,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                            ),
                          ),
                          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(value: 'home', child: Text('Inicio 🏠')),
                            DropdownMenuItem(value: 'tienda', child: Text('Tienda Virtual 📦')),
                            DropdownMenuItem(value: 'membresia', child: Text('Mi Membresía / Perfil 👤')),
                            DropdownMenuItem(value: 'clase_detalle', child: Text('Clase o Evento Específico 🗓️')),
                            DropdownMenuItem(value: 'tutorial', child: Text('Tutorial Específico 📖')),
                            DropdownMenuItem(value: 'cantiga', child: Text('Canción Específica 🎵')),
                            DropdownMenuItem(value: 'producto', child: Text('Producto Específico 🛍️')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setStateModal(() {
                                screenSeleccionado = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        if (screenSeleccionado == 'clase_detalle') ...[
                          Text(
                            'Seleccionar Clase o Evento Destino:',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
                          else if (clasesList.isEmpty)
                            Text('No hay clases/eventos creados en el sistema.', style: GoogleFonts.montserrat(color: Colors.red))
                          else
                            DropdownButtonFormField<String>(
                              value: claseRedireccionId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                              ),
                              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                              items: clasesList.map((doc) {
                                final cdata = doc.data() as Map<String, dynamic>;
                                final String nombre = cdata['nombre'] ?? 'Sin nombre';
                                final String sede = cdata['sede'] ?? 'Sin sede';
                                final String tipo = cdata['tipo'] ?? 'regular';
                                final String tipoTag = tipo == 'regular' ? '🥋' : '🌟';
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text('$tipoTag $nombre ($sede)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateModal(() {
                                    claseRedireccionId = val;
                                  });
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                        ],

                        if (screenSeleccionado == 'tutorial') ...[
                          Text(
                            'Seleccionar Tutorial Destino:',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
                          else if (tutorialesList.isEmpty)
                            Text('No hay tutoriales creados en el sistema.', style: GoogleFonts.montserrat(color: Colors.red))
                          else
                            DropdownButtonFormField<String>(
                              value: tutorialRedireccionId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                              ),
                              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                              items: tutorialesList.map((doc) {
                                final tdata = doc.data() as Map<String, dynamic>;
                                final String titulo = tdata['titulo'] ?? 'Sin título';
                                final String categoria = tdata['categoria'] ?? 'General';
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text('📖 $titulo ($categoria)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateModal(() {
                                    tutorialRedireccionId = val;
                                  });
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                        ],

                        if (screenSeleccionado == 'cantiga') ...[
                          Text(
                            'Seleccionar Canción Destino:',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
                          else if (cantigasList.isEmpty)
                            Text('No hay canciones creadas en el sistema.', style: GoogleFonts.montserrat(color: Colors.red))
                          else
                            DropdownButtonFormField<String>(
                              value: cantigaRedireccionId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                              ),
                              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                              items: cantigasList.map((doc) {
                                final sdata = doc.data() as Map<String, dynamic>;
                                final String titulo = sdata['titulo'] ?? 'Sin título';
                                final String ritmo = sdata['ritmo'] ?? 'General';
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text('🎵 $titulo ($ritmo)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateModal(() {
                                    cantigaRedireccionId = val;
                                  });
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                        ],

                        if (screenSeleccionado == 'producto') ...[
                          Text(
                            'Seleccionar Producto Destino:',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
                          else if (productosList.isEmpty)
                            Text('No hay productos creados en el sistema.', style: GoogleFonts.montserrat(color: Colors.red))
                          else
                            DropdownButtonFormField<String>(
                              value: productoRedireccionId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  borderSide: BorderSide(color: _kBordeOscuro),
                                ),
                              ),
                              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                              items: productosList.map((doc) {
                                final pdata = doc.data() as Map<String, dynamic>;
                                final String nombre = pdata['nombre'] ?? 'Sin nombre';
                                final num precio = pdata['precio'] ?? 0;
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text('🛍️ $nombre (S/ $precio)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateModal(() {
                                    productoRedireccionId = val;
                                  });
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                        ],

                        const SizedBox(height: 12),

                        // Botones Acción
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: enviando ? null : () => Navigator.pop(contextModal),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kTextoSecundarioOscuro,
                                  side: BorderSide(color: _kBordeOscuro),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(GingaRadius.md),
                                  ),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: enviando 
                                    ? null 
                                    : () async {
                                        final titulo = tituloController.text.trim();
                                        final mensaje = mensajeController.text.trim();
                                        if (titulo.isEmpty || mensaje.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Por favor completa todos los campos')),
                                          );
                                          return;
                                        }

                                        setStateModal(() {
                                          enviando = true;
                                        });

                                        try {
                                          int count = 0;
                                          final batch = FirebaseFirestore.instance.batch();

                                          if (isIndividual) {
                                            // Enviar a un solo estudiante
                                            final newDoc = FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(targetStudentUid)
                                                .collection('notificaciones')
                                                .doc();
                                            
                                            batch.set(newDoc, {
                                              'titulo': titulo,
                                              'mensaje': mensaje,
                                              'fecha': Timestamp.now(),
                                              'leido': false,
                                              'tipo': screenSeleccionado,
                                              'screen': screenSeleccionado,
                                              if (screenSeleccionado == 'clase_detalle')
                                                'clase_id': claseRedireccionId,
                                              if (screenSeleccionado == 'tutorial')
                                                'tutorial_id': tutorialRedireccionId,
                                              if (screenSeleccionado == 'cantiga')
                                                'song_id': cantigaRedireccionId,
                                              if (screenSeleccionado == 'producto')
                                                'producto_id': productoRedireccionId,
                                            });
                                            count = 1;
                                          } else {
                                            // Enviar de forma masiva / grupal
                                            Query query = FirebaseFirestore.instance
                                                .collection('users')
                                                .where('rol', isEqualTo: 'alumno');

                                            if (scopeSeleccionado == 'Por Sede') {
                                              if (sedeSeleccionada == 'Cusco') {
                                                query = query.where('sede', whereIn: ['Cusco', 'U. Continental']);
                                              } else {
                                                query = query.where('sede', isEqualTo: sedeSeleccionada);
                                              }
                                            } else if (scopeSeleccionado == 'Por Clase') {
                                              query = query.where('clase_id', isEqualTo: claseSeleccionadaId);
                                            }

                                            final snapshot = await query.get();
                                            final docs = snapshot.docs;

                                            for (var doc in docs) {
                                              final newDoc = FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(doc.id)
                                                  .collection('notificaciones')
                                                  .doc();
                                              
                                              batch.set(newDoc, {
                                                'titulo': titulo,
                                                'mensaje': mensaje,
                                                'fecha': Timestamp.now(),
                                                'leido': false,
                                                'tipo': screenSeleccionado,
                                                'screen': screenSeleccionado,
                                                if (screenSeleccionado == 'clase_detalle')
                                                  'clase_id': claseRedireccionId,
                                                if (screenSeleccionado == 'tutorial')
                                                  'tutorial_id': tutorialRedireccionId,
                                                if (screenSeleccionado == 'cantiga')
                                                  'song_id': cantigaRedireccionId,
                                                if (screenSeleccionado == 'producto')
                                                  'producto_id': productoRedireccionId,
                                              });
                                              count++;
                                            }
                                          }

                                          if (count > 0) {
                                            await batch.commit();
                                            if (contextModal.mounted) {
                                              Navigator.pop(contextModal);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('¡Comunicado enviado con éxito! 📢 Impactó a $count ' + (count == 1 ? 'alumno.' : 'alumnos.')),
                                                  backgroundColor: GingaColors.brandGreen,
                                                ),
                                              );
                                            }
                                          } else {
                                            setStateModal(() {
                                              enviando = false;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('No se encontraron alumnos que coincidan con la selección.')),
                                            );
                                          }
                                        } catch (e) {
                                          debugPrint("Error al enviar comunicado masivo: $e");
                                          setStateModal(() {
                                            enviando = false;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error al enviar: $e')),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GingaColors.brandGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(GingaRadius.md),
                                  ),
                                ),
                                child: enviando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        'Enviar 🚀',
                                        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Carga datos para la compensación
  Future<Map<String, dynamic>> _cargarDatosCompensacion(String uid, String? claseId) async {
    final Future<DocumentSnapshot?> fetchClase = (claseId != null && claseId.isNotEmpty)
        ? FirebaseFirestore.instance.collection('clases').doc(claseId).get()
        : Future.value(null);

    final Future<QuerySnapshot> fetchCompensaciones = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('compensaciones')
        .orderBy('fecha_compensacion', descending: true)
        .limit(3)
        .get();

    // Consultamos únicamente por user_id para evitar requerir índices compuestos en Firebase
    final Future<QuerySnapshot> fetchUltimoPago = FirebaseFirestore.instance
        .collection('pagos')
        .where('user_id', isEqualTo: uid)
        .get();

    final results = await Future.wait([fetchClase, fetchCompensaciones, fetchUltimoPago]);
    
    // Filtrado y ordenamiento en memoria para evitar colisiones de índices de Firebase
    final pagosDocs = (results[2] as QuerySnapshot).docs;
    final pagosCompletados = pagosDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['estado'] == 'completado';
    }).toList();

    pagosCompletados.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final Timestamp? aTime = aData['fecha_pago'] as Timestamp?;
      final Timestamp? bTime = bData['fecha_pago'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime); // Orden descendente
    });

    final Map<String, dynamic>? ultimoPagoData = pagosCompletados.isNotEmpty
        ? pagosCompletados.first.data() as Map<String, dynamic>?
        : null;

    return {
      'clase': results[0] as DocumentSnapshot?,
      'compensaciones': (results[1] as QuerySnapshot).docs,
      'ultimoPago': ultimoPagoData,
    };
  }

  // Calcula la siguiente sesión de clase saltando días según el horario
  DateTime calcularSiguienteSesion(DateTime fechaBase, List<String> diasClase, int sesionesAAgregar) {
    final Map<String, int> mapDias = {
      'L': DateTime.monday,
      'M': DateTime.tuesday,
      'X': DateTime.wednesday,
      'J': DateTime.thursday,
      'V': DateTime.friday,
      'S': DateTime.saturday,
      'D': DateTime.sunday,
    };
    
    final List<int> diasSemanaInt = diasClase
        .map((d) => mapDias[d.trim().toUpperCase()])
        .whereType<int>()
        .toList();
        
    if (diasSemanaInt.isEmpty) {
      return fechaBase.add(Duration(days: sesionesAAgregar));
    }
    
    diasSemanaInt.sort();
    
    DateTime fechaCalculada = fechaBase;
    int sesionesEncontradas = 0;
    DateTime ultimaClaseEncontrada = fechaBase;
    
    while (sesionesEncontradas < sesionesAAgregar) {
      if (diasSemanaInt.contains(fechaCalculada.weekday)) {
        sesionesEncontradas++;
        ultimaClaseEncontrada = fechaCalculada;
      }
      if (sesionesEncontradas < sesionesAAgregar) {
        fechaCalculada = fechaCalculada.add(const Duration(days: 1));
      }
    }
    
    return ultimaClaseEncontrada.add(const Duration(days: 1));
  }

  // Modal para compensar membresía por feriado / suspensión (sin cobros contables)
  void _mostrarModalCompensacion(BuildContext context, Map<String, dynamic> data) {
    final uid = data['uid'] ?? '';
    final String alumnoNombre = data['nombre'] ?? 'Sin nombre';
    final DateTime? finActual = data['membresia_fin'] != null
        ? (data['membresia_fin'] as Timestamp).toDate()
        : null;
    final String? claseId = data['clase_id'];

    // Variables locales de estado del modal
    String motivoSeleccionado = 'feriado'; // feriado, inasistencia_justificada, suspension_profesor, congelar, otro
    String detalleMotivoText = 'Feriado';
    DateTime fechaReferencia = DateTime.now(); // fecha del feriado o de la inasistencia
    int sesionesAAgregar = 1; // para feriados e inasistencias
    int diasACongelar = 7; // para congelamientos
    bool isLoading = false;
    
    DateTime baseVencimiento = finActual != null && finActual.isAfter(DateTime.now())
        ? finActual
        : DateTime.now();
        
    DateTime nuevaFechaVencimiento = baseVencimiento.add(const Duration(days: 1));
    bool isCustomDate = false;
    bool isConfirmEnabled = true;
    String? warningMessage;
    
    List<String> listDiasClase = [];
    List<DocumentSnapshot> lastCompensaciones = [];
    Map<String, dynamic>? ultimoPagoData;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kTarjetaOscura,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _cargarDatosCompensacion(uid, claseId),
          builder: (contextFuture, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 250,
                child: const Center(
                  child: CircularProgressIndicator(color: GingaColors.brandGreen),
                ),
              );
            }
            
            if (snapshot.hasError) {
              return Container(
                height: 200,
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('Error al cargar datos del alumno: ${snapshot.error}', style: GoogleFonts.montserrat(color: Colors.red)),
                ),
              );
            }

            final datMap = snapshot.data!;
            final DocumentSnapshot? claseDoc = datMap['clase'];
            lastCompensaciones = datMap['compensaciones'] as List<DocumentSnapshot>;
            ultimoPagoData = datMap['ultimoPago'] as Map<String, dynamic>?;

            if (claseDoc != null && claseDoc.exists) {
              final String rawDias = (claseDoc.data() as Map<String, dynamic>)['dias'] ?? '';
              listDiasClase = rawDias.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
            }

            return StatefulBuilder(
              builder: (contextModal, setStateModal) {
                // Función interna para recalcular la nueva fecha de vencimiento basándose en los inputs
                void recalcularNuevaFecha() {
                  if (isCustomDate) return; // Si es fecha personalizada, no sobreescribir la elegida a mano
                  
                  if (motivoSeleccionado == 'feriado' || motivoSeleccionado == 'inasistencia_justificada' || motivoSeleccionado == 'suspension_profesor') {
                    nuevaFechaVencimiento = calcularSiguienteSesion(baseVencimiento, listDiasClase, sesionesAAgregar);
                  } else if (motivoSeleccionado == 'congelar') {
                    nuevaFechaVencimiento = baseVencimiento.add(Duration(days: diasACongelar));
                  } else {
                    nuevaFechaVencimiento = baseVencimiento.add(Duration(days: sesionesAAgregar));
                  }
                }

                // Función interna para realizar validaciones en tiempo real
                void realizarValidaciones() {
                  warningMessage = null;
                  isConfirmEnabled = true;

                  if (motivoSeleccionado == 'feriado') {
                    // Validar si ya existe un feriado compensado para la fecha seleccionada
                    final String idFeriadoTarget = "${fechaReferencia.year}-${fechaReferencia.month.toString().padLeft(2, '0')}-${fechaReferencia.day.toString().padLeft(2, '0')}";
                    bool feriadoYaExiste = false;
                    for (var doc in lastCompensaciones) {
                      final c = doc.data() as Map<String, dynamic>;
                      if (c['motivo'] == 'feriado' && c['id_feriado'] == idFeriadoTarget) {
                        feriadoYaExiste = true;
                        break;
                      }
                    }
                    if (feriadoYaExiste) {
                      warningMessage = '⚠️ El alumno ya fue compensado por el feriado del ${fechaReferencia.day}/${fechaReferencia.month}/${fechaReferencia.year}. Evita duplicaciones.';
                      isConfirmEnabled = false;
                    }
                  } else if (motivoSeleccionado == 'inasistencia_justificada') {
                    // Validar límite de inasistencias en este ciclo
                    if (ultimoPagoData != null) {
                      final DateTime? fechaPago = ultimoPagoData!['fecha_pago'] != null
                          ? (ultimoPagoData!['fecha_pago'] as Timestamp).toDate()
                          : null;

                      if (fechaPago != null) {
                        int count = 0;
                        for (var doc in lastCompensaciones) {
                          final c = doc.data() as Map<String, dynamic>;
                          if (c['motivo'] == 'inasistencia_justificada') {
                            final DateTime? fc = c['fecha_compensacion'] != null
                                ? (c['fecha_compensacion'] as Timestamp).toDate()
                                : null;
                            if (fc != null && fc.isAfter(fechaPago)) {
                              count++;
                            }
                          }
                        }
                        if (count >= 2) {
                          warningMessage = '❌ Límite alcanzado: El alumno ya compensó las 2 inasistencias permitidas en este ciclo de pago (iniciado el ' + fechaPago.day.toString() + '/' + fechaPago.month.toString() + '/' + fechaPago.year.toString() + ').';
                          isConfirmEnabled = false;
                        } else {
                          warningMessage = 'ℹ️ Inasistencias justificadas compensadas en este ciclo: ' + count.toString() + ' / 2.';
                        }
                      }
                    } else {
                      warningMessage = '⚠️ No se encontró un pago registrado en el sistema. Límite de inasistencias deshabilitado.';
                    }
                  }
                }

                // Ejecutamos cálculo inicial en primer render si no ha sido editado
                recalcularNuevaFecha();
                realizarValidaciones();

                final String currentFinText = finActual != null
                    ? "${finActual.day}/${finActual.month}/${finActual.year}"
                    : "No tiene membresía activa";

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(contextModal).size.height * 0.9,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(contextModal).viewInsets.bottom +
                          (MediaQuery.of(contextModal).padding.bottom > 0
                              ? MediaQuery.of(contextModal).padding.bottom + 12
                              : 20),
                      left: 20,
                      right: 20,
                      top: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_outlined, color: GingaColors.accentAmber, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Compensar Membresía',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Alumno: ' + alumnoNombre,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: _kTextoSecundarioOscuro,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (listDiasClase.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Horario del Alumno: ' + listDiasClase.join(", "),
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: GingaColors.brandGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Vencimiento Actual
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _kTarjetaOscura,
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(color: _kBordeOscuro),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: _kTextoSecundarioOscuro, size: 18),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vencimiento actual:',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: _kTextoSecundarioOscuro,
                                    ),
                                  ),
                                  Text(
                                    currentFinText,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Seleccionar Motivo
                        Text(
                          'Motivo de la Compensación:',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: motivoSeleccionado,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: const BorderSide(color: GingaColors.brandGreen),
                            ),
                            filled: true,
                            fillColor: _kTarjetaOscura,
                          ),
                          style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(value: 'feriado', child: Text('Feriado / Festivo 📅')),
                            DropdownMenuItem(value: 'inasistencia_justificada', child: Text('Inasistencia Justificada (Límite 2) 🤒')),
                            DropdownMenuItem(value: 'suspension_profesor', child: Text('Suspensión por el Profesor 🥋')),
                            DropdownMenuItem(value: 'congelar', child: Text('Congelar por Viaje / Salud ❄️')),
                            DropdownMenuItem(value: 'otro', child: Text('Otro motivo especial 📝')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setStateModal(() {
                                motivoSeleccionado = val;
                                isCustomDate = false;
                                if (val == 'feriado') {
                                  detalleMotivoText = 'Feriado';
                                  sesionesAAgregar = 1;
                                } else if (val == 'inasistencia_justificada') {
                                  detalleMotivoText = 'Inasistencia justificada';
                                  sesionesAAgregar = 1;
                                } else if (val == 'suspension_profesor') {
                                  detalleMotivoText = 'Clase suspendida por el profesor';
                                  sesionesAAgregar = 1;
                                } else if (val == 'congelar') {
                                  detalleMotivoText = 'Congelamiento temporal';
                                  diasACongelar = 7;
                                } else {
                                  detalleMotivoText = 'Otros motivos';
                                  sesionesAAgregar = 1;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Formulario Dinámico según Motivo
                        if (motivoSeleccionado == 'feriado') ...[
                          Text(
                            'Fecha del Feriado:',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final selected = await showDatePicker(
                                context: contextModal,
                                initialDate: fechaReferencia,
                                firstDate: DateTime.now().subtract(const Duration(days: 60)),
                                lastDate: DateTime.now().add(const Duration(days: 60)),
                                builder: buildGingaDatePickerTheme,
                              );
                              if (selected != null) {
                                setStateModal(() {
                                  fechaReferencia = selected;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _kTarjetaOscura,
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                border: Border.all(color: _kBordeOscuro),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    fechaReferencia.day.toString() + '/' + fechaReferencia.month.toString() + '/' + fechaReferencia.year.toString(),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_month_rounded, size: 18, color: GingaColors.brandGreen),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nombre del Feriado:',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            onChanged: (val) => setStateModal(() { detalleMotivoText = val.trim(); }),
                            decoration: InputDecoration(
                              hintText: 'Ej: San Pedro y San Pablo',
                              hintStyle: GoogleFonts.montserrat(fontSize: 13, color: _kTextoSecundarioOscuro),
                              filled: true,
                              fillColor: _kTarjetaOscura,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                borderSide: BorderSide(color: _kBordeOscuro),
                              ),
                            ),
                            style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                        ] else if (motivoSeleccionado == 'inasistencia_justificada') ...[
                          Text(
                            'Fecha de la Inasistencia:',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final selected = await showDatePicker(
                                context: contextModal,
                                initialDate: fechaReferencia,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now(),
                                builder: buildGingaDatePickerTheme,
                              );
                              if (selected != null) {
                                setStateModal(() {
                                  fechaReferencia = selected;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _kTarjetaOscura,
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                                border: Border.all(color: _kBordeOscuro),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    fechaReferencia.day.toString() + '/' + fechaReferencia.month.toString() + '/' + fechaReferencia.year.toString(),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_month_rounded, size: 18, color: GingaColors.brandGreen),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Alerta/Advertencia de Validación en Tiempo Real
                        if (warningMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: warningMessage!.contains('❌') 
                                  ? Colors.red.shade50 
                                  : warningMessage!.contains('⚠️') 
                                      ? GingaColors.accentAmber.withOpacity(0.08) 
                                      : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              border: Border.all(
                                color: warningMessage!.contains('❌') 
                                    ? Colors.red.shade200 
                                    : warningMessage!.contains('⚠️') 
                                        ? GingaColors.accentAmber.withOpacity(0.2) 
                                        : Colors.blue.shade200,
                              ),
                            ),
                            child: Text(
                              warningMessage!,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: warningMessage!.contains('❌') 
                                    ? Colors.red.shade900 
                                    : warningMessage!.contains('⚠️') 
                                        ? const Color(0xFF856404) 
                                        : Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Opciones de Compensación Rápida (Chips)
                        Text(
                          motivoSeleccionado == 'congelar' 
                              ? 'Tiempo de Congelamiento:' 
                              : 'Compensación a Aplicar:',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (motivoSeleccionado == 'congelar') ...[
                              ChoiceChip(
                                label: const Text('1 semana'),
                                selected: diasACongelar == 7 && !isCustomDate,
                                onSelected: (val) {
                                  setStateModal(() {
                                    diasACongelar = 7;
                                    isCustomDate = false;
                                  });
                                },
                                selectedColor: GingaColors.brandGreen,
                                labelStyle: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: (diasACongelar == 7 && !isCustomDate) ? Colors.white : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('2 semanas'),
                                selected: diasACongelar == 14 && !isCustomDate,
                                onSelected: (val) {
                                  setStateModal(() {
                                    diasACongelar = 14;
                                    isCustomDate = false;
                                  });
                                },
                                selectedColor: GingaColors.brandGreen,
                                labelStyle: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: (diasACongelar == 14 && !isCustomDate) ? Colors.white : Colors.white,
                                ),
                              ),
                            ] else ...[
                              ChoiceChip(
                                label: const Text('+1 Sesión'),
                                selected: sesionesAAgregar == 1 && !isCustomDate,
                                onSelected: (val) {
                                  setStateModal(() {
                                    sesionesAAgregar = 1;
                                    isCustomDate = false;
                                  });
                                },
                                selectedColor: GingaColors.brandGreen,
                                labelStyle: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: (sesionesAAgregar == 1 && !isCustomDate) ? Colors.white : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (motivoSeleccionado != 'inasistencia_justificada') ...[
                                ChoiceChip(
                                  label: const Text('+2 Sesiones'),
                                  selected: sesionesAAgregar == 2 && !isCustomDate,
                                  onSelected: (val) {
                                    setStateModal(() {
                                      sesionesAAgregar = 2;
                                      isCustomDate = false;
                                    });
                                  },
                                  selectedColor: GingaColors.brandGreen,
                                  labelStyle: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: (sesionesAAgregar == 2 && !isCustomDate) ? Colors.white : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                            ChoiceChip(
                              label: const Text('Fecha Libre 📅'),
                              selected: isCustomDate,
                              onSelected: (val) async {
                                  final selected = await showDatePicker(
                                    context: contextModal,
                                    initialDate: nuevaFechaVencimiento,
                                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                    builder: buildGingaDatePickerTheme,
                                  );
                                if (selected != null) {
                                  setStateModal(() {
                                    nuevaFechaVencimiento = selected;
                                    isCustomDate = true;
                                  });
                                }
                              },
                              selectedColor: GingaColors.brandGreen,
                              labelStyle: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCustomDate ? Colors.white : Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Fecha de Vencimiento Calculada
                        Text(
                          'Nuevo Vencimiento de Membresía:',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: _kTarjetaOscura,
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(color: GingaColors.brandGreen, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                nuevaFechaVencimiento.day.toString() + '/' + nuevaFechaVencimiento.month.toString() + '/' + nuevaFechaVencimiento.year.toString(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                isCustomDate ? 'Fecha Libre' : (motivoSeleccionado == 'congelar' ? 'congelamiento' : 'proyección de clase'),
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: GingaColors.brandGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Historial de Compensaciones
                        if (lastCompensaciones.isNotEmpty) ...[
                          Text(
                            'Historial de Compensaciones Recientes:',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: lastCompensaciones.length,
                            itemBuilder: (context, index) {
                              final comp = lastCompensaciones[index].data() as Map<String, dynamic>;
                              final String mot = comp['motivo'] ?? 'otro';
                              final String det = comp['detalle'] ?? '';
                              final int dias = comp['dias_compensados'] ?? 0;
                              final DateTime? fechaC = comp['fecha_compensacion'] != null
                                  ? (comp['fecha_compensacion'] as Timestamp).toDate()
                                  : null;

                              String motivoLabel = 'Otro';
                              IconData icon = Icons.info_outline;
                              if (mot == 'feriado') {
                                motivoLabel = 'Feriado';
                                icon = Icons.calendar_month_outlined;
                              } else if (mot == 'inasistencia_justificada') {
                                motivoLabel = 'Inasistencia';
                                icon = Icons.sick_outlined;
                              } else if (mot == 'congelar') {
                                motivoLabel = 'Congelamiento';
                                icon = Icons.ac_unit_outlined;
                              } else if (mot == 'suspension_profesor') {
                                motivoLabel = 'Suspensión';
                                icon = Icons.cancel_presentation_outlined;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _kTarjetaOscura,
                                  borderRadius: BorderRadius.circular(GingaRadius.sm),
                                  border: Border.all(color: _kBordeOscuro),
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, size: 16, color: _kTextoSecundarioOscuro),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            motivoLabel + ' - ' + det,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (fechaC != null)
                                            Text(
                                              'Otorgado: ' + fechaC.day.toString() + '/' + fechaC.month.toString() + '/' + fechaC.year.toString(),
                                              style: GoogleFonts.montserrat(
                                                fontSize: 10,
                                                color: _kTextoSecundarioOscuro,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: GingaColors.brandGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '+' + dias.toString() + ' d',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: GingaColors.brandGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Botones de Confirmar/Cancelar
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(contextModal),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kTextoSecundarioOscuro,
                                  side: BorderSide(color: _kBordeOscuro),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(GingaRadius.md),
                                  ),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (!isConfirmEnabled)
                                    ? null
                                    : () async {
                                        setStateModal(() { isConfirmEnabled = false; });
                                        try {
                                          final int diasComp = nuevaFechaVencimiento.difference(baseVencimiento).inDays;
                                          final String registeredBy = FirebaseAuth.instance.currentUser?.uid ?? '';

                                          // 1. Guardar registro en la subcolección compensaciones del alumno
                                          final String idFeriadoValue = motivoSeleccionado == 'feriado' 
                                              ? "${fechaReferencia.year}-${fechaReferencia.month.toString().padLeft(2, '0')}-${fechaReferencia.day.toString().padLeft(2, '0')}"
                                              : '';
                                          
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(uid)
                                              .collection('compensaciones')
                                              .add({
                                            'motivo': motivoSeleccionado,
                                            'detalle': detalleMotivoText,
                                            'fecha_compensacion': FieldValue.serverTimestamp(),
                                            'dias_compensados': diasComp > 0 ? diasComp : 1,
                                            'vencimiento_anterior': finActual != null ? Timestamp.fromDate(finActual) : null,
                                            'vencimiento_nuevo': Timestamp.fromDate(nuevaFechaVencimiento),
                                            'registrado_por': registeredBy,
                                            'id_feriado': idFeriadoValue,
                                            'fecha_inasistencia': motivoSeleccionado == 'inasistencia_justificada' ? Timestamp.fromDate(fechaReferencia) : null,
                                          });

                                          // 2. Actualizar el vencimiento y estado del alumno
                                          await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                            'status': 'activo',
                                            'membresia_fin': Timestamp.fromDate(nuevaFechaVencimiento),
                                          });

                                          // 3. Crear notificación personalizada
                                          final nuevoVencimientoTexto = nuevaFechaVencimiento.day.toString() + '/' + nuevaFechaVencimiento.month.toString() + '/' + nuevaFechaVencimiento.year.toString();
                                          String msg = '';
                                          if (motivoSeleccionado == 'feriado') {
                                            msg = 'Tu membresía ha sido extendida por ' + (sesionesAAgregar == 1 ? "1 sesión" : sesionesAAgregar.toString() + " sesiones") + ' debido al feriado de "' + detalleMotivoText + '". Tu nuevo vencimiento es el ' + nuevoVencimientoTexto + '.';
                                          } else if (motivoSeleccionado == 'inasistencia_justificada') {
                                            msg = 'Se ha reincorporado 1 sesión a tu membresía por inasistencia justificada. Tu nuevo vencimiento es el ' + nuevoVencimientoTexto + '.';
                                          } else if (motivoSeleccionado == 'congelar') {
                                            msg = 'Tu membresía ha sido congelada por ' + (diasACongelar == 7 ? "1 semana" : "2 semanas") + '. Tu nuevo vencimiento se pospone al ' + nuevoVencimientoTexto + '.';
                                          } else {
                                            msg = 'Tu membresía ha sido extendida por el motivo "' + detalleMotivoText + '". Tu nuevo vencimiento es el ' + nuevoVencimientoTexto + '.';
                                          }

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(uid)
                                              .collection('notificaciones')
                                              .add({
                                            'titulo': 'Membresía Compensada 🎁',
                                            'mensaje': msg,
                                            'fecha': FieldValue.serverTimestamp(),
                                            'leido': false,
                                            'tipo': 'membresia',
                                          });

                                          if (contextModal.mounted) {
                                            Navigator.pop(contextModal);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Compensación registrada 🎉. Vence: ' + nuevoVencimientoTexto),
                                                backgroundColor: GingaColors.brandGreen,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (contextModal.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error al guardar compensación: ' + e.toString()),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } finally {
                                          setStateModal(() { isConfirmEnabled = true; });
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GingaColors.brandGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(GingaRadius.md),
                                  ),
                                ),
                                child: (!isConfirmEnabled)
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        'Confirmar 🚀',
                                        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Modal para Activar/Gestionar/Renovar la Membresía - Con Scroll y resguardo de teclado para evitar Overflows
  void _mostrarModalActivacion(BuildContext context, Map<String, dynamic> data, String uid) {
    int mesesSeleccionados = 1;
    String? claseSeleccionadaId;
    bool isClassesLoaded = false;
    List<QueryDocumentSnapshot> clasesList = [];
    
    // Variables para el control de pago unificado
    String metodoPagoSeleccionado = 'Yape';
    final List<String> metodosPago = ['Yape', 'Plin', 'Efectivo', 'Transferencia'];
    double montoCobrado = 120.0;
    
    // Si el alumno ya está activo y tiene vencimiento en el futuro, sugerimos encadenar la fecha de inicio desde su vencimiento actual para evitar pérdida de días
    DateTime fechaInicioMembresia = DateTime.now();
    if (data['status'] == 'activo' && data['membresia_fin'] != null) {
      final DateTime finActual = (data['membresia_fin'] as Timestamp).toDate();
      if (finActual.isAfter(DateTime.now())) {
        fechaInicioMembresia = finActual;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kTarjetaOscura,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('clases').get(),
              builder: (context, classesSnapshot) {
                if (classesSnapshot.hasData && !isClassesLoaded) {
                  clasesList = classesSnapshot.data!.docs;
                  isClassesLoaded = true;
                  
                  // Intentar pre-seleccionar si el usuario ya tiene una clase asignada
                  claseSeleccionadaId = data['clase_id'];
                }

                final isRenewing = data['status'] == 'activo';

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85, // Resguardo contra overflows
                  ),
                  child: SingleChildScrollView( // Scrollable para soportar teclados y pantallas pequeñas
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom +
                          (MediaQuery.of(context).padding.bottom > 0
                              ? MediaQuery.of(context).padding.bottom + 12
                              : 20),
                      left: 20,
                      right: 20,
                      top: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isRenewing ? 'Gestionar / Renovar Membresía' : 'Activar Membresía',
                            style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('Alumno: ${data['nombre'] ?? 'Sin nombre'}',
                            style: GoogleFonts.montserrat(
                                fontSize: 16, color: _kTextoSecundarioOscuro)),
                        
                        const SizedBox(height: 20),
                        Text('Asignar Clase regular:',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        
                        if (classesSnapshot.connectionState == ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator(color: GingaColors.brandGreen))
                        else if (clasesList.isEmpty)
                          Text('No hay clases creadas en la base de datos.',
                              style: GoogleFonts.montserrat(fontSize: 13, color: Colors.red))
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _kTarjetaOscura,
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              border: Border.all(color: _kBordeOscuro),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                dropdownColor: _kTarjetaOscura,
                                value: claseSeleccionadaId,
                                hint: Text('Selecciona una clase regular', style: GoogleFonts.montserrat(fontSize: 13)),
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down, color: _kTextoSecundarioOscuro),
                                style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white),
                                items: clasesList.map((doc) {
                                  final cData = doc.data() as Map<String, dynamic>;
                                  final nombre = cData['nombre'] ?? 'Sin nombre';
                                  final nivel = cData['nivel'] ?? '';
                                  final dias = cData['dias'] ?? '';
                                  final hora = cData['hora'] ?? '';
                                  return DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text('$nombre - $nivel ($dias $hora)'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setStateModal(() {
                                    claseSeleccionadaId = val;
                                  });
                                },
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),
                        Text('Fecha de Inicio:',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: fechaInicioMembresia,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)), // hasta 1 año en el pasado
                              lastDate: DateTime.now().add(const Duration(days: 365)), // hasta 1 año en el futuro
                              builder: buildGingaDatePickerTheme,
                            );
                            if (selected != null) {
                              setStateModal(() {
                                fechaInicioMembresia = selected;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _kTarjetaOscura,
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              border: Border.all(color: _kBordeOscuro),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${fechaInicioMembresia.day}/${fechaInicioMembresia.month}/${fechaInicioMembresia.year}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const Icon(Icons.calendar_today_rounded, size: 18, color: GingaColors.brandGreen),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Text('Meses a contratar:',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [1, 2, 3, 6, 12].map((mes) {
                            final isSelected = mesesSeleccionados == mes;
                            return GestureDetector(
                              onTap: () {
                                setStateModal(() {
                                  mesesSeleccionados = mes;
                                  montoCobrado = mes * 120.0;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? GingaColors.brandGreen : _kTarjetaOscura,
                                  borderRadius: BorderRadius.circular(GingaRadius.md),
                                  border: Border.all(
                                      color: isSelected
                                          ? GingaColors.brandGreen
                                          : _kBordeOscuro),
                                ),
                                child: Text('$mes',
                                    style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            );
                          }).toList(),
                        ),
                        
                        const SizedBox(height: 20),
                        Text('Monto Cobrado (Soles S/):',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(height: 8),
                        TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                          decoration: InputDecoration(
                            prefixText: 'S/ ',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: _kTarjetaOscura,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: BorderSide(color: _kBordeOscuro),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              borderSide: const BorderSide(color: GingaColors.brandGreen),
                            ),
                          ),
                          controller: TextEditingController(text: montoCobrado.toStringAsFixed(2))
                            ..selection = TextSelection.fromPosition(
                              TextPosition(offset: montoCobrado.toStringAsFixed(2).length),
                            ),
                          onChanged: (value) {
                            final parsed = double.tryParse(value);
                            if (parsed != null) {
                              montoCobrado = parsed;
                            }
                          },
                        ),

                        const SizedBox(height: 20),
                        Text('Método de Pago:',
                            style: GoogleFonts.montserrat(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _kTarjetaOscura,
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(color: _kBordeOscuro),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: _kTarjetaOscura,
                              value: metodoPagoSeleccionado,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down, color: _kTextoSecundarioOscuro),
                              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700),
                              items: metodosPago.map((metodo) {
                                return DropdownMenuItem<String>(
                                  value: metodo,
                                  child: Text(metodo),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateModal(() {
                                    metodoPagoSeleccionado = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final fechaFin = DateTime(
                                fechaInicioMembresia.year,
                                fechaInicioMembresia.month + mesesSeleccionados,
                                fechaInicioMembresia.day,
                              );

                              try {
                                // Buscar si el alumno tiene alguna reservación si no seleccionó clase manual
                                String? finalClaseId = claseSeleccionadaId;
                                if (finalClaseId == null) {
                                  final reservasQuery = await FirebaseFirestore.instance
                                      .collection('reservas')
                                      .where('user_id', isEqualTo: uid)
                                      .get();
                                  if (reservasQuery.docs.isNotEmpty) {
                                    finalClaseId = reservasQuery.docs.first['clase_id'];
                                  }
                                }

                                final Map<String, dynamic> updateData = {
                                  'status': 'activo',
                                  'membresia_inicio': Timestamp.fromDate(fechaInicioMembresia),
                                  'membresia_fin': Timestamp.fromDate(fechaFin),
                                  'membresia_meses_pagados': mesesSeleccionados,
                                };

                                if (finalClaseId != null) {
                                  updateData['clase_id'] = finalClaseId;
                                  
                                  // Auto-sincronizar la sede del alumno con la sede/nombre de la clase asignada
                                  try {
                                    final claseDoc = await FirebaseFirestore.instance
                                        .collection('clases')
                                        .doc(finalClaseId)
                                        .get();
                                    if (claseDoc.exists) {
                                      final claseData = claseDoc.data() ?? {};
                                      final claseSede = claseData['sede']; // ej: "Cusco", "Lima"
                                      final claseNombre = claseData['nombre']; // ej: "Kids", "Adultos"
                                      if (claseSede != null && claseSede.toString().isNotEmpty) {
                                        updateData['sede'] = claseSede.toString();
                                      } else if (claseNombre != null && claseNombre.toString().isNotEmpty) {
                                        updateData['sede'] = claseNombre.toString();
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint('Error al auto-obtener la sede de la clase: $e');
                                  }
                                }

                                await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .update(updateData);

                                 // Registrar la transacción contable en la colección /pagos
                                 await FirebaseFirestore.instance.collection('pagos').add({
                                   'user_id': uid,
                                   'user_name': data['nombre'] ?? 'Sin nombre',
                                   'user_sede': data['sede'] ?? 'Sin sede',
                                   'monto': montoCobrado,
                                   'moneda': 'PEN',
                                   'meses_pagados': mesesSeleccionados,
                                   'metodo_pago': metodoPagoSeleccionado,
                                   'fecha_pago': FieldValue.serverTimestamp(),
                                   'fecha_vencimiento': Timestamp.fromDate(fechaFin),
                                   'estado': 'completado',
                                   'registrado_por': FirebaseAuth.instance.currentUser?.uid,
                                 });

                                // Generar notificación en el buzón del alumno
                                try {
                                  final fechaFinTexto = "${fechaFin.day}/${fechaFin.month}/${fechaFin.year}";
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(uid)
                                      .collection('notificaciones')
                                      .add({
                                    'titulo': isRenewing ? '¡Membresía Renovada! 🥋' : '¡Membresía Activa! 🥋',
                                    'mensaje': isRenewing 
                                        ? '¡Tu membresía ha sido renovada con éxito! Tu nuevo vencimiento es el $fechaFinTexto.'
                                        : '¡Tu acceso regular a la sede ha sido activado! Vence el $fechaFinTexto. ¡Nos vemos en la Roda!',
                                    'fecha': FieldValue.serverTimestamp(),
                                    'leido': false,
                                    'tipo': 'membresia',
                                  });
                                } catch (notiError) {
                                  debugPrint('Error al guardar notificación de membresía: $notiError');
                                }
                                
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(isRenewing 
                                          ? 'Membresía renovada con éxito 🎉'
                                          : 'Alumno activado y clase asociada con éxito 🎉'),
                                      backgroundColor: GingaColors.brandGreen,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al procesar membresía: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GingaColors.brandGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(GingaRadius.md),
                              ),
                              elevation: 2,
                            ),
                            child: Text(isRenewing ? 'Confirmar Renovación' : 'Confirmar Activación',
                                style: GoogleFonts.montserrat(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Modal para actualizar y promover la cuerda/rango del Alumno
  void _mostrarModalPromocionCorda(BuildContext context, Map<String, dynamic> data, String uid) {
    final String currentCorda = data['corda'] ?? 'Sin cuerda';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kTarjetaOscura,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                (MediaQuery.of(ctx).padding.bottom > 0
                    ? MediaQuery.of(ctx).padding.bottom + 12
                    : 20),
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Promover Graduación 🎓',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Alumno: ${data['nombre'] ?? 'Sin nombre'}',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: _kTextoSecundarioOscuro,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: GingaColors.brandGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(GingaRadius.md),
                ),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: GingaColors.brandGreen,
                    ),
                    children: [
                      const TextSpan(text: 'Cuerda Actual: '),
                      TextSpan(
                        text: currentCorda.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: GingaColors.brandGreen),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona el nuevo nivel o cuerda:',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kTextoSecundarioOscuro,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: CuerdasFIU.lista.length,
                  itemBuilder: (context, index) {
                    final corda = CuerdasFIU.lista[index];
                    
                    final isCurrent = currentCorda.toLowerCase().contains(corda.nombre.toLowerCase()) || 
                                     currentCorda.toLowerCase().contains(corda.rango.toLowerCase()) ||
                                     (currentCorda.toLowerCase() == 'iniciante' && corda.nombre.toLowerCase() == 'crua');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({'corda': corda.nombre});

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('¡${data['nombre'] ?? 'Alumno'} promovido a Cuerda ${corda.nombre}! 🌟'),
                                  backgroundColor: GingaColors.brandGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error al actualizar graduación: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(GingaRadius.md),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent ? GingaColors.brandGreen.withOpacity(0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            border: Border.all(
                              color: isCurrent ? GingaColors.brandGreen : _kBordeOscuro,
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Mini Cuerda Visual
                              Container(
                                width: 44,
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 1.5,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: corda.esMixta
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                color: corda.colores[0],
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                color: corda.colores[1],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: corda.colores,
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cuerda ${corda.nombre}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      corda.rango,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: _kTextoSecundarioOscuro,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: GingaColors.brandGreen,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestión de Alumnos',
                          style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Administra el perfil, fichas y membresías de tus alumnos',
                          style: GoogleFonts.montserrat(
                              fontSize: 14, color: _kTextoSecundarioOscuro)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _mostrarModalAgregarAlumno(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.brandGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: Text(
                        'Agregar Alumno 👤',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: () => _mostrarModalComunicado(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.brandGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.campaign, size: 16),
                      label: Text(
                        'Comunicado 📢',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Controles de Búsqueda y Filtros de Sede/Estado Premium
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                // 1. Buscador por nombre (Ancho completo)
                Container(
                  decoration: BoxDecoration(
                    color: _kTarjetaOscura,
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre...',
                      hintStyle: GoogleFonts.montserrat(fontSize: 13, color: _kTextoSecundarioOscuro),
                      prefixIcon: Icon(Icons.search, color: _kTextoSecundarioOscuro, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                
                // 2. Filtros de Sede y Estado (Lado a lado)
                Row(
                  children: [
                    // Filtro Sede
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _kTarjetaOscura,
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: _kBordeOscuro),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: _kTarjetaOscura,
                            value: _selectedSedeFilter,
                            icon: const Icon(Icons.location_on_outlined, size: 16, color: GingaColors.brandGreen),
                            isExpanded: true,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            items: _sedes.map((sede) {
                              return DropdownMenuItem<String>(
                                value: sede,
                                child: Text(sede),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSedeFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Filtro Estado
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _kTarjetaOscura,
                          borderRadius: BorderRadius.circular(GingaRadius.md),
                          border: Border.all(color: _kBordeOscuro),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: _kTarjetaOscura,
                            value: _selectedStatusFilter,
                            icon: const Icon(Icons.tune, size: 16, color: GingaColors.brandGreen),
                            isExpanded: true,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            items: _statuses.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStatusFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Ver Alumnos de Baja',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextoSecundarioOscuro,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _showArchived,
                      activeColor: GingaColors.brandGreen,
                      onChanged: (val) {
                        setState(() {
                          _showArchived = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('rol', isEqualTo: 'alumno')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: GingaColors.brandGreen),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No hay alumnos registrados',
                        style: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro)),
                  );
                }

                // Filtrar alumnos client-side por nombre, sede y estado
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombreRaw = (data['nombre'] ?? '').toString().trim();
                  final sedeRaw = (data['sede'] ?? '').toString().trim();
                  if (nombreRaw.isEmpty || sedeRaw.isEmpty) {
                    return false;
                  }

                  final nombre = nombreRaw.toLowerCase();
                  final sede = (data['sede'] ?? '').toString();
                  final status = (data['status'] ?? '').toString();

                  if (status == 'eliminado' && !_showArchived) {
                    return false;
                  }

                  final matchesSearch = nombre.contains(_searchQuery.toLowerCase());
                  final matchesSede = _selectedSedeFilter == 'Todos' || sede == _selectedSedeFilter;
                  final matchesStatus = _selectedStatusFilter == 'Todos' || status.toLowerCase() == _selectedStatusFilter.toLowerCase();

                  return matchesSearch && matchesSede && matchesStatus;
                }).toList();

                // Ordenar alumnos por fecha de creación (los más nuevos arriba)
                filteredDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  final aTime = aData['created_at'] as Timestamp?;
                  final bTime = bData['created_at'] as Timestamp?;
                  
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1; // Nulos abajo
                  if (bTime == null) return -1;
                  
                  return bTime.compareTo(aTime);
                });

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('No se encontraron alumnos con los filtros seleccionados',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro)),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'desconocido';
                    final userSede = data['sede'] ?? 'Sin sede';
                    final String? fotoUrl = data['foto_url'];
                    final String corda = data['corda'] ?? 'Crua';
                    final finTime = data['membresia_fin'] as Timestamp?;
                    final DateTime? finDate = finTime?.toDate();
                    final Color statusColor = status == 'activo'
                        ? GingaColors.brandGreen
                        : status == 'prueba'
                            ? GingaColors.accentAmber
                            : status == 'nuevo'
                                ? Colors.blue
                                : Colors.red;

                    return GestureDetector(
                      onTap: () {
                        final Map<String, dynamic> dataWithUid = Map.from(data);
                        dataWithUid['uid'] = doc.id;
                        _mostrarFichaAlumno(context, dataWithUid);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kTarjetaOscura,
                          borderRadius: BorderRadius.circular(GingaRadius.lg),
                          border: Border.all(color: _kBordeOscuro),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: statusColor.withOpacity(0.2),
                              backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                                  ? NetworkImage(fotoUrl)
                                  : null,
                              child: fotoUrl != null && fotoUrl.isNotEmpty
                                  ? null
                                  : Icon(Icons.person, color: statusColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['nombre'] ?? 'Sin nombre',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(status.toUpperCase(),
                                      style: GoogleFonts.montserrat(
                                          fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
                                ),
                                if (data['is_offline'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'SIN APP 📴',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$userSede • $corda',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                  fontSize: 10, fontWeight: FontWeight.w600, color: _kTextoSecundarioOscuro),
                            ),
                            const SizedBox(height: 2),
                            _StudentProgressText(uid: doc.id, corda: corda),
                            if (finDate != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Vence: ${finDate.day}/${finDate.month}/${finDate.year}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: finDate.isBefore(DateTime.now()) ? Colors.redAccent : _kTextoSecundarioOscuro,
                                ),
                              ),
                            ],
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _mostrarModalActivacion(context, data, doc.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: status == 'activo'
                                      ? Colors.blueGrey
                                      : GingaColors.brandGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(GingaRadius.md),
                                  ),
                                ),
                                child: Text(
                                  status == 'activo' ? 'Gestionar' : (status == 'inactivo' ? 'Renovar' : 'Activar'),
                                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarAsistenciaRetroactiva(BuildContext context, Map<String, dynamic> userData) async {
    final String userUid = userData['uid'] ?? '';
    if (userUid.isEmpty) return;

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: buildGingaDatePickerTheme,
    );

    if (fechaSeleccionada == null) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: GingaColors.brandGreen),
      ),
    );

    try {
      final String fechaStr = '${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}';

      // Verificar si ya existe asistencia para esa fecha
      final checkQuery = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('user_id', isEqualTo: userUid)
          .where('fecha', isEqualTo: fechaStr)
          .get();

      if (checkQuery.docs.isNotEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // Cierra loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El alumno ya tiene asistencia registrada para el $fechaStr',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final String userName = userData['nombre'] ?? 'Sin nombre';
      final String userEmail = userData['email'] ?? 'Sin correo';
      final String claseId = userData['clase_id'] ?? '';
      final String corda = userData['corda'] ?? 'Crua';

      // Insertar ticket
      await FirebaseFirestore.instance.collection('asistencias').add({
        'sesion_id': 'manual_instructor',
        'user_id': userUid,
        'user_name': userName,
        'user_email': userEmail,
        'clase_id': claseId,
        'nivel': corda,
        'hora': '19:00',
        'fecha': fechaStr,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context); // Cierra loader
        Navigator.pop(context); // Cierra la ficha del alumno de forma segura
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Asistencia registrada con éxito para el $fechaStr! 🎉',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            backgroundColor: GingaColors.brandGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Cierra loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al registrar la asistencia. Intenta de nuevo.',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarModalAgregarAlumno(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    final emailController = TextEditingController();
    final telefonoController = TextEditingController();

    final List<String> sedesDisponibles = _sedes.where((s) => s != 'Todos').toList();
    String selectedSede = sedesDisponibles.first;
    
    String selectedCorda = 'Crua';
    String selectedStatus = 'activo';
    bool isOffline = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kTarjetaOscura,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GingaRadius.xl)),
      ),
      builder: (BuildContext sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext modalCtx, StateSetter modalSetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom +
                    (MediaQuery.of(modalCtx).padding.bottom > 0
                        ? MediaQuery.of(modalCtx).padding.bottom + 12
                        : 20),
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Agregar Alumno Manual 👤',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            icon: const Icon(Icons.close, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Crea un nuevo alumno para monitorear sus mensualidades, asistencias y notas.',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: _kTextoSecundarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nombre
                      Text(
                        'Nombre Completo *',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nombreController,
                        decoration: InputDecoration(
                          hintText: 'Ej. Amaru Valenzuela',
                          hintStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            borderSide: BorderSide(color: _kBordeOscuro),
                          ),
                        ),
                        style: GoogleFonts.montserrat(color: Colors.white),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Sede Dropdown
                      Text(
                        'Sede Asignada *',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedSede,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            borderSide: BorderSide(color: _kBordeOscuro),
                          ),
                        ),
                        style: GoogleFonts.montserrat(color: Colors.white),
                        items: sedesDisponibles.map((s) {
                          return DropdownMenuItem<String>(
                            value: s,
                            child: Text(s, style: GoogleFonts.montserrat(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            modalSetState(() {
                              selectedSede = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Corda Dropdown
                      Text(
                        'Cuerda / Graduación Inicial *',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedCorda,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            borderSide: BorderSide(color: _kBordeOscuro),
                          ),
                        ),
                        style: GoogleFonts.montserrat(color: Colors.white),
                        items: CuerdasFIU.lista.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.nombre,
                            child: Text(c.nombre, style: GoogleFonts.montserrat(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            modalSetState(() {
                              selectedCorda = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Estado Dropdown
                      Text(
                        'Estado *',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            borderSide: BorderSide(color: _kBordeOscuro),
                          ),
                        ),
                        style: GoogleFonts.montserrat(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'activo', child: Text('Activo')),
                          DropdownMenuItem(value: 'prueba', child: Text('Periodo de Prueba')),
                          DropdownMenuItem(value: 'nuevo', child: Text('Nuevo')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            modalSetState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Correo
                      Text(
                        'Correo Electrónico (Opcional)',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: isOffline ? 'Ficticio (Ej. amaru_offline@ginga.app)' : 'Ej. amaru@gmail.com',
                          hintStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            borderSide: BorderSide(color: _kBordeOscuro),
                          ),
                        ),
                        style: GoogleFonts.montserrat(color: Colors.white),
                        enabled: !isOffline,
                      ),
                      const SizedBox(height: 14),

                      // Teléfono / WhatsApp
                      Text(
                        'Teléfono / WhatsApp (Opcional)',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kTextoSecundarioOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: telefonoController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: 'Ej. 51987654321 (con código de país)',
                          hintStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.md),
                            borderSide: BorderSide(color: _kBordeOscuro),
                          ),
                        ),
                        style: GoogleFonts.montserrat(color: Colors.white),
                      ),
                      const SizedBox(height: 10),

                      // Switch Alumno sin aplicación (Offline)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alumno sin Aplicación (Offline)',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Activa esta opción si el alumno no usará la app. Se generará un correo único de respaldo.',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: _kTextoSecundarioOscuro,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isOffline,
                            activeColor: GingaColors.brandGreen,
                            onChanged: (val) {
                              modalSetState(() {
                                isOffline = val;
                                if (isOffline) {
                                  emailController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Guardar Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            
                            final name = nombreController.text.trim();
                            String email = emailController.text.trim();
                            
                            if (isOffline) {
                              email = 'sin_app_${DateTime.now().millisecondsSinceEpoch}@ginga.app';
                            } else if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Por favor, ingresa un correo o activa el modo sin aplicación.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            // Mostrar cargando usando el contexto de la pantalla
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext loaderCtx) => const Center(
                                child: CircularProgressIndicator(color: GingaColors.brandGreen),
                              ),
                            );

                            try {
                              final telefono = telefonoController.text.trim();

                              final newUserRef = FirebaseFirestore.instance.collection('users').doc();
                              final Map<String, dynamic> userData = {
                                'uid': newUserRef.id,
                                'nombre': name,
                                'email': email,
                                'sede': selectedSede,
                                'corda': selectedCorda,
                                'rol': 'alumno',
                                'status': selectedStatus,
                                'is_offline': isOffline,
                                'created_at': FieldValue.serverTimestamp(),
                                'notas': '',
                                if (telefono.isNotEmpty) 'whatsapp_id': telefono,
                                if (telefono.isNotEmpty) 'whatsapp_id_es_telefono': true,
                              };

                              await newUserRef.set(userData);

                              if (mounted) {
                                Navigator.pop(context); // Cierra cargando
                                Navigator.pop(sheetCtx); // Cierra la hoja inferior de registro
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Alumno "$name" registrado con éxito 🎉'),
                                    backgroundColor: GingaColors.brandGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.pop(context); // Cierra cargando
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al registrar alumno: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GingaColors.brandGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            'Registrar Alumno',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editarNotasAlumno(BuildContext context, BuildContext sheetCtx, Map<String, dynamic> userData) async {
    final String userUid = userData['uid'] ?? '';
    if (userUid.isEmpty) return;

    final controller = TextEditingController(text: userData['notas'] ?? '');

    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          backgroundColor: _kTarjetaOscura,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GingaRadius.lg),
            side: const BorderSide(color: _kBordeOscuro),
          ),
          title: Text(
            'Notas del Instructor 📝',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Escribe aquí observaciones, lesiones, comportamiento...',
              hintStyle: GoogleFonts.montserrat(color: _kTextoSecundarioOscuro),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GingaRadius.md),
                borderSide: BorderSide(color: _kBordeOscuro),
              ),
            ),
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: _kTextoSecundarioOscuro),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newNotas = controller.text.trim();
                Navigator.of(dialogCtx).pop();

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext loaderCtx) => const Center(
                    child: CircularProgressIndicator(color: GingaColors.brandGreen),
                  ),
                );

                try {
                  await FirebaseFirestore.instance.collection('users').doc(userUid).update({
                    'notas': newNotas,
                  });

                  if (mounted) {
                    Navigator.pop(context); // Cierra cargando
                    Navigator.pop(sheetCtx); // Cierra la ficha del alumno para recargar los datos
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Notas actualizadas correctamente 📝'),
                        backgroundColor: GingaColors.brandGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Cierra cargando
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al guardar notas: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GingaColors.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.md)),
              ),
              child: Text(
                'Guardar',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  WIDGET DE CALENDARIO DE ASISTENCIAS EN LA FICHA
// ─────────────────────────────────────────

class _FichaAsistenciasCalendar extends StatefulWidget {
  final String uid;
  const _FichaAsistenciasCalendar({required this.uid});

  @override
  State<_FichaAsistenciasCalendar> createState() => _FichaAsistenciasCalendarState();
}

class _FichaAsistenciasCalendarState extends State<_FichaAsistenciasCalendar> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('asistencias')
          .where('user_id', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(color: GingaColors.brandGreen),
            ),
          );
        }

        final Set<String> asistenciasFechas = snapshot.hasData
            ? snapshot.data!.docs
                .map((doc) => (doc.data() as Map<String, dynamic>)['fecha'] as String)
                .toSet()
            : {};

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kTarjetaOscura,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBordeOscuro.withOpacity(0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Historial de Asistencia del Mes',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: GingaColors.brandGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${asistenciasFechas.length} clases',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: GingaColors.brandGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                rowHeight: 38,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mes',
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  headerPadding: const EdgeInsets.symmetric(vertical: 4),
                  titleTextStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  leftChevronIcon: const Icon(Icons.chevron_left, color: GingaColors.brandGreen, size: 20),
                  rightChevronIcon: const Icon(Icons.chevron_right, color: GingaColors.brandGreen, size: 20),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _kTextoSecundarioOscuro),
                  weekendStyle: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: GingaColors.brandGreen),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.white),
                  weekendTextStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.white),
                  outsideDaysVisible: false,
                ),
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final fechaStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final bool asistio = asistenciasFechas.contains(fechaStr);
                    if (asistio) {
                      return Container(
                        margin: const EdgeInsets.all(3),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: GingaColors.brandGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final fechaStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final bool asistio = asistenciasFechas.contains(fechaStr);
                    return Container(
                      margin: const EdgeInsets.all(3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: asistio ? GingaColors.brandGreen : Colors.transparent,
                        border: Border.all(color: GingaColors.brandGreen, width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: asistio ? Colors.white : GingaColors.brandGreen,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  SECCIÓN DE PROGRESO DE GRADUACIÓN (OPCIÓN C)
// ─────────────────────────────────────────

String _obtenerSiguienteCorda(String cordaUsuario) {
  final cordaObj = CuerdasFIU.encontrarCordaFIU(cordaUsuario);
  if (cordaObj != null) {
    final nextIndex = cordaObj.index; 
    if (nextIndex < CuerdasFIU.lista.length) {
      return CuerdasFIU.lista[nextIndex].nombre;
    }
    return 'Graduado';
  }
  return 'Crua e Verde';
}

class _StudentProgressText extends StatelessWidget {
  final String uid;
  final String corda;

  const _StudentProgressText({required this.uid, required this.corda});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('asistencias')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            ' • 🎯 ...%',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kTextoSecundarioOscuro,
            ),
          );
        }
        final int totalAsistencias = snapshot.data!.docs.length;
        final cordaObj = CuerdasFIU.encontrarCordaFIU(corda);
        final int objetivo = cordaObj != null
            ? CuerdasFIU.obtenerClasesObjetivo(cordaObj.index)
            : 100;
        final double porcentaje = (totalAsistencias / objetivo).clamp(0.0, 1.0);
        final int porcentajeInt = (porcentaje * 100).toInt();

        return Text(
          ' • 🎯 $porcentajeInt%',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: GingaColors.brandGreen,
          ),
        );
      },
    );
  }
}

class _FichaProgresoCard extends StatelessWidget {
  final String uid;
  final String corda;

  const _FichaProgresoCard({required this.uid, required this.corda});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('asistencias')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(color: GingaColors.brandGreen, strokeWidth: 2),
            ),
          );
        }

        final int totalAsistencias = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final cordaObj = CuerdasFIU.encontrarCordaFIU(corda);
        final int objetivo = cordaObj != null
            ? CuerdasFIU.obtenerClasesObjetivo(cordaObj.index)
            : 100;
        final double porcentaje = (totalAsistencias / objetivo).clamp(0.0, 1.0);
        final int porcentajeInt = (porcentaje * 100).toInt();

        final String siguienteCorda = _obtenerSiguienteCorda(corda);
        
        // Objetivo de cuerda texto
        String descCorda = totalAsistencias >= objetivo
            ? '¡Clases completadas! ($totalAsistencias/$objetivo)'
            : 'Faltan ${objetivo - totalAsistencias} clases para graduarse ($totalAsistencias de $objetivo)';
        if (siguienteCorda == 'Graduado') {
          descCorda = '¡Has alcanzado el rango máximo en Ginga!';
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kTarjetaOscura,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBordeOscuro.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              // Círculo de progreso
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: porcentaje,
                      backgroundColor: _kBordeOscuro,
                      color: GingaColors.brandGreen,
                      strokeWidth: 6,
                    ),
                  ),
                  Text(
                    '$porcentajeInt%',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Detalles del objetivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siguienteCorda == 'Graduado' ? 'Camino Completado 🏆' : 'Siguiente Cuerda: $siguienteCorda',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descCorda,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: _kTextoSecundarioOscuro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
