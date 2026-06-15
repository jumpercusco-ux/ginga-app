import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/widgets/ginga_cached_image.dart';

class CrearClaseScreen extends StatefulWidget {
  final String? claseId;
  const CrearClaseScreen({super.key, this.claseId});

  @override
  State<CrearClaseScreen> createState() => _CrearClaseScreenState();
}

class _CrearClaseScreenState extends State<CrearClaseScreen> {
  String _nombreClase = 'Kids';
  String _nivelSeleccionado = 'Iniciantes';
  String _selectedSede = 'Cusco';
  final _descripcionController = TextEditingController();
  LatLng? _selectedLocation;
  String _tipoClase = 'regular';
  final _nombreCustomController = TextEditingController();
  String _fechaTexto = '';
  DateTime? _selectedDate;
  final _organizadorController = TextEditingController();
  final List<Map<String, String>> _cronograma = [
    {
      'hora': '09:00 AM',
      'actividad': 'Acreditación y Calentamiento',
    },
    {
      'hora': '10:00 AM',
      'actividad': 'Exhibición y Talleres Especiales',
    },
    {
      'hora': '11:00 AM',
      'actividad': 'Roda de Integración General',
    },
  ];

  XFile? _selectedImageFile;
  Uint8List? _webImageBytes;
  final ImagePicker _picker = ImagePicker();
  String _existingImageUrl = '';

  @override
  void initState() {
    super.initState();
    _initInstructorName();
    if (widget.claseId != null) {
      _cargarDatosClase();
    }
  }

  Future<void> _initInstructorName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && widget.claseId == null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final name = userDoc.data()?['nombre'];
        if (name != null && mounted) {
          setState(() {
            _organizadorController.text = name;
          });
        }
      } catch (e) {
        debugPrint('Error inicializando nombre del instructor: $e');
      }
    }
  }

  Future<void> _cargarDatosClase() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clases')
          .doc(widget.claseId)
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _nombreClase = data['nombre'] ?? 'Kids';
          _nivelSeleccionado = data['nivel'] ?? 'Iniciantes';
          _selectedSede = data['sede'] ?? 'Cusco';
          _descripcionController.text = data['descripcion'] ?? '';
          _maxAlumnos = data['cupos_max'] ?? 12;
          _modalidad = data['modalidad'] ?? 'Presencial';
          _ubicacionController.text = data['ubicacion'] ?? '';
          _claseGratuita = data['clase_gratuita'] ?? true;
          _publicarInmediatamente = data['publicar_inmediatamente'] ?? true;
          _existingImageUrl = data['imagen_url'] ?? '';
          
          _tipoClase = data['tipo'] ?? 'regular';
          if (_tipoClase != 'regular') {
            _nombreCustomController.text = data['nombre'] ?? '';
            _fechaTexto = data['dias'] ?? '';
          }

          // Días recurrentes
          final String diasRaw = data['dias'] ?? '';
          if (diasRaw.isNotEmpty) {
            _diasSeleccionados.clear();
            if (_tipoClase == 'regular') {
              _diasSeleccionados.addAll(diasRaw.split(',').map((d) => d.trim()));
            }
          }

          // Horario
          final String horaInicioRaw = data['hora'] ?? '18:00';
          final String horaFinRaw = data['hora_fin'] ?? '19:00';
          
          final List<String> hi = horaInicioRaw.split(':');
          if (hi.length == 2) {
            _horaInicio = TimeOfDay(hour: int.parse(hi[0]), minute: int.parse(hi[1]));
          }
          final List<String> hf = horaFinRaw.split(':');
          if (hf.length == 2) {
            _horaFin = TimeOfDay(hour: int.parse(hf[0]), minute: int.parse(hf[1]));
          }

          // Coordenadas geográficas (con retrocompatibilidad)
          final double? lat = data['lat'] != null ? (data['lat'] as num).toDouble() : null;
          final double? lng = data['lng'] != null ? (data['lng'] as num).toDouble() : null;
          if (lat != null && lng != null) {
            _selectedLocation = LatLng(lat, lng);
          }
        });

        // Intentar obtener la fecha exacta del evento desde la colección /eventos (Same-ID)
        if (_tipoClase != 'regular') {
          try {
            final eventDoc = await FirebaseFirestore.instance
                .collection('eventos')
                .doc(widget.claseId)
                .get();
            if (eventDoc.exists) {
              final eventData = eventDoc.data() ?? {};
              final Timestamp? startTs = eventData['fecha_inicio'] as Timestamp?;
              if (startTs != null) {
                setState(() {
                  _selectedDate = startTs.toDate();
                });
              }
              // Cargar organizador y cronograma
              final String org = eventData['organizador'] ?? '';
              final List<dynamic>? cronogramaRaw = eventData['cronograma'];
              setState(() {
                if (org.isNotEmpty) {
                  _organizadorController.text = org;
                }
                if (cronogramaRaw != null && cronogramaRaw.isNotEmpty) {
                  _cronograma.clear();
                  for (var item in cronogramaRaw) {
                    if (item is Map) {
                      _cronograma.add({
                        'hora': (item['hora'] ?? '').toString(),
                        'actividad': (item['actividad'] ?? '').toString(),
                      });
                    }
                  }
                }
              });
            }
          } catch (e) {
            debugPrint('Error al cargar datos del evento complementario: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar datos de la clase: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarImagen() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = pickedFile;
        });
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e'), backgroundColor: Colors.red),
      );
    }
  }


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
  final List<String> _sedes = ['Cusco', 'Lima', 'Chimbote'];
  final List<String> _niveles = ['Iniciantes', 'Intermedio', 'Avanzado', 'Todos'];
  final List<String> _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  final List<String> _modalidades = ['Presencial', 'Online', 'Híbrido'];

  LatLng _getSedeLatLng(String sede) {
    switch (sede.toLowerCase()) {
      case 'lima':
        return const LatLng(-12.0464, -77.0428);
      case 'chimbote':
        return const LatLng(-9.0853, -78.5786);
      case 'cusco':
      default:
        return const LatLng(-13.5319, -71.9675);
    }
  }

  void _showMapPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        LatLng tempLocation = _selectedLocation ?? _getSedeLatLng(_selectedSede);
        final MapController pickerMapController = MapController();
        final searchController = TextEditingController();
        List<dynamic> searchResults = [];
        bool isSearching = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> buscarDireccion(String query) async {
              if (query.trim().isEmpty) return;
              setModalState(() {
                isSearching = true;
                searchResults = [];
              });

              try {
                final response = await http.get(
                  Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1'),
                  headers: {'User-Agent': 'GingaApp/1.0 (jumperstudio)'},
                );
                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  setModalState(() {
                    searchResults = data;
                  });
                }
              } catch (e) {
                debugPrint('Error en geocodificación Nominatim: $e');
              } finally {
                setModalState(() {
                  isSearching = false;
                });
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  // Cabecera
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Seleccionar ubicación 📍',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Buscador Nominatim
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                style: GoogleFonts.nunito(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Buscar calle, parque, plaza...',
                                  hintStyle: GoogleFonts.nunito(color: GingaColors.textSecondary, fontSize: 13),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F5F5),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: isSearching
                                      ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: GingaColors.brandGreen),
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            searchController.clear();
                                            setModalState(() {
                                              searchResults = [];
                                            });
                                          },
                                        ),
                                ),
                                onSubmitted: (val) => buscarDireccion(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => buscarDireccion(searchController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GingaColors.brandGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                elevation: 0,
                              ),
                              child: const Icon(Icons.search, size: 20),
                            ),
                          ],
                        ),

                        // Lista flotante de sugerencias
                        if (searchResults.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final res = searchResults[index];
                                final displayName = res['display_name'] ?? '';
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.location_on, color: GingaColors.brandGreen, size: 16),
                                  title: Text(
                                    displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(fontSize: 12, color: GingaColors.textPrimary),
                                  ),
                                  onTap: () {
                                    final lat = double.tryParse(res['lat'] ?? '');
                                    final lon = double.tryParse(res['lon'] ?? '');
                                    if (lat != null && lon != null) {
                                      final newPos = LatLng(lat, lon);
                                      setModalState(() {
                                        tempLocation = newPos;
                                        searchResults = [];
                                      });
                                      pickerMapController.move(newPos, 16.0);
                                      searchController.text = displayName;
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Mapa Interactivo
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FlutterMap(
                            mapController: pickerMapController,
                            options: MapOptions(
                              initialCenter: tempLocation,
                              initialZoom: 15.0,
                              onTap: (tapPosition, point) {
                                setModalState(() {
                                  tempLocation = point;
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.jumperstudio.ginga_app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: tempLocation,
                                    width: 45,
                                    height: 45,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: GingaColors.brandGreen,
                                      size: 45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '💡 Toca cualquier parte del mapa para mover el pin de ubicación exacta.',
                              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: GingaColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),

                  // Botón Confirmar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedLocation = tempLocation;
                            // Only populate the address text field if it was empty, to preserve custom text
                            if (_ubicacionController.text.trim().isEmpty && searchController.text.isNotEmpty) {
                              _ubicacionController.text = searchController.text.split(',')[0];
                            }
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Confirmar Ubicación 📍',
                          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _ubicacionController.dispose();
    _nombreCustomController.dispose();
    _organizadorController.dispose();
    super.dispose();
  }

  void _agregarItemCronograma() {
    setState(() {
      _cronograma.add({
        'hora': '10:00 AM',
        'actividad': 'Nueva Actividad',
      });
    });
  }

  Future<void> _pickTime(bool esInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: esInicio ? _horaInicio : _horaFin,
      builder: buildGingaTimePickerTheme,
    );
    if (picked != null) {
      setState(() => esInicio ? _horaInicio = picked : _horaFin = picked);
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _publicarClase() async {
    if (_tipoClase == 'regular' && _diasSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecciona al menos un día recurrente',
            style: GoogleFonts.nunito(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (_tipoClase != 'regular' && _fechaTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecciona la fecha del evento',
            style: GoogleFonts.nunito(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (_tipoClase != 'regular' && _nombreCustomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ingresa un título para el evento/roda',
            style: GoogleFonts.nunito(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final String finalNombre = _tipoClase == 'regular' 
          ? _nombreClase 
          : _nombreCustomController.text.trim();
      final String finalBadge = _tipoClase == 'regular'
          ? _nombreClase
          : (_tipoClase == 'roda' ? 'Roda Especial 🔥' : 'Evento Especial 🌟');

      // Calcular fechas para eventos/rodas especiales
      DateTime? startDateTime;
      DateTime? endDateTime;
      if (_tipoClase != 'regular') {
        if (_selectedDate != null) {
          startDateTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _horaInicio.hour,
            _horaInicio.minute,
          );
          endDateTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _horaFin.hour,
            _horaFin.minute,
          );
        } else {
          final now = DateTime.now();
          startDateTime = DateTime(now.year, now.month, now.day, _horaInicio.hour, _horaInicio.minute);
          endDateTime = DateTime(now.year, now.month, now.day, _horaFin.hour, _horaFin.minute);
        }
      }

      String finalImageUrl = _existingImageUrl;
      if (_selectedImageFile != null) {
        final fileName = 'clases_imagenes/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        if (kIsWeb && _webImageBytes != null) {
          await ref.putData(_webImageBytes!);
        } else {
          await ref.putFile(File(_selectedImageFile!.path));
        }
        finalImageUrl = await ref.getDownloadURL();
      } else if (finalImageUrl.isEmpty || finalImageUrl.startsWith('assets/')) {
        finalImageUrl = _tipoClase == 'roda'
            ? 'assets/images/fiu_banner.png'
            : 'assets/images/roda.jpg';
      }

      final claseData = {
        'nombre': finalNombre,
        'nivel': _nivelSeleccionado,
        'sede': _selectedSede,
        'badge': finalBadge,
        'descripcion': _descripcionController.text.trim(),
        'dias': _tipoClase == 'regular' ? _diasSeleccionados.join(', ') : _fechaTexto,
        'hora': _formatTime(_horaInicio),
        'hora_fin': _formatTime(_horaFin),
        'cupos_max': _maxAlumnos,
        'cupos_disponibles': _maxAlumnos,
        'modalidad': _modalidad,
        'ubicacion': _ubicacionController.text.trim(),
        'lat': _selectedLocation?.latitude,
        'lng': _selectedLocation?.longitude,
        'clase_gratuita': _claseGratuita,
        'publicar_inmediatamente': _publicarInmediatamente,
        'instructor_id': uid,
        'tipo': _tipoClase,
        'fecha_fin': endDateTime != null ? Timestamp.fromDate(endDateTime) : null,
        'imagen_url': finalImageUrl,
      };

      if (widget.claseId != null) {
        // 1. Actualizar en clases
        await FirebaseFirestore.instance
            .collection('clases')
            .doc(widget.claseId)
            .update(claseData);

        // 2. Si es especial o roda, actualizar también en 'eventos' con el mismo ID
        if (_tipoClase != 'regular') {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final instructorName = userDoc.data()?['nombre'] ?? 'Instructor / Mestre';

          final String finalLugar = _ubicacionController.text.trim().isNotEmpty
              ? _ubicacionController.text.trim()
              : 'Sede: $_selectedSede';

          final String bannerUrl = finalImageUrl;

          final String diaNombre = _fechaTexto.isNotEmpty ? _fechaTexto.split(' ').first : 'Evento';
          final List<Map<String, String>> finalCronograma = _cronograma.isNotEmpty
              ? _cronograma.map((item) => {
                  'dia': diaNombre,
                  'hora': item['hora'] ?? '',
                  'actividad': item['actividad'] ?? '',
                }).toList()
              : [
                  {
                    'dia': diaNombre,
                    'hora': _formatTime(_horaInicio),
                    'actividad': 'Inicio del evento y acreditación: $finalNombre',
                  },
                  {
                    'dia': diaNombre,
                    'hora': _formatTime(_horaFin),
                    'actividad': 'Cierre y Roda de integración general.',
                  }
                ];

          final Map<String, dynamic> eventData = {
            'titulo': finalNombre,
            'organizador': _organizadorController.text.trim().isNotEmpty 
                ? _organizadorController.text.trim() 
                : instructorName,
            'fecha_inicio': startDateTime != null ? Timestamp.fromDate(startDateTime) : null,
            'fecha_fin': endDateTime != null ? Timestamp.fromDate(endDateTime) : null,
            'fecha_texto': '$_fechaTexto, ${_formatTime(_horaInicio)} - ${_formatTime(_horaFin)}',
            'lugar': finalLugar,
            'descripcion': _descripcionController.text.trim(),
            'imagen_url': finalImageUrl,
            'cronograma': finalCronograma,
            'publicar_inmediatamente': _publicarInmediatamente,
          };

          await FirebaseFirestore.instance
              .collection('eventos')
              .doc(widget.claseId)
              .set(eventData, SetOptions(merge: true));
        } else {
          // Si cambió a regular, limpiamos el evento correspondiente si existía
          await FirebaseFirestore.instance
              .collection('eventos')
              .doc(widget.claseId)
              .delete();
        }
      } else {
        claseData['created_at'] = FieldValue.serverTimestamp();
        
        if (_tipoClase != 'regular') {
          // 1. Generar un nuevo ID de clase primero para usar el mismo ID
          final newClassRef = FirebaseFirestore.instance.collection('clases').doc();
          final String newDocId = newClassRef.id;

          // 2. Guardar en 'clases' con ese ID
          await newClassRef.set(claseData);

          // 3. Crear el evento en 'eventos' con el mismo ID
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final instructorName = userDoc.data()?['nombre'] ?? 'Instructor / Mestre';

          final String finalLugar = _ubicacionController.text.trim().isNotEmpty
              ? _ubicacionController.text.trim()
              : 'Sede: $_selectedSede';

          final String bannerUrl = finalImageUrl;

          final String diaNombre = _fechaTexto.isNotEmpty ? _fechaTexto.split(' ').first : 'Evento';
          final List<Map<String, String>> finalCronograma = _cronograma.isNotEmpty
              ? _cronograma.map((item) => {
                  'dia': diaNombre,
                  'hora': item['hora'] ?? '',
                  'actividad': item['actividad'] ?? '',
                }).toList()
              : [
                  {
                    'dia': diaNombre,
                    'hora': _formatTime(_horaInicio),
                    'actividad': 'Inicio del evento y acreditación: $finalNombre',
                  },
                  {
                    'dia': diaNombre,
                    'hora': _formatTime(_horaFin),
                    'actividad': 'Cierre y Roda de integración general.',
                  }
                ];

          final Map<String, dynamic> eventData = {
            'titulo': finalNombre,
            'organizador': _organizadorController.text.trim().isNotEmpty 
                ? _organizadorController.text.trim() 
                : instructorName,
            'fecha_inicio': startDateTime != null ? Timestamp.fromDate(startDateTime) : null,
            'fecha_fin': endDateTime != null ? Timestamp.fromDate(endDateTime) : null,
            'fecha_texto': '$_fechaTexto, ${_formatTime(_horaInicio)} - ${_formatTime(_horaFin)}',
            'lugar': finalLugar,
            'descripcion': _descripcionController.text.trim(),
            'imagen_url': finalImageUrl,
            'cronograma': finalCronograma,
            'publicar_inmediatamente': _publicarInmediatamente,
          };

          await FirebaseFirestore.instance
              .collection('eventos')
              .doc(newDocId)
              .set(eventData);

          if (_publicarInmediatamente) {
            await _notificarAlumnosNuevaClase(newDocId, finalNombre, _tipoClase, _selectedSede);
          }
        } else {
          // Clase regular estándar
          await FirebaseFirestore.instance.collection('clases').add(claseData);
        }
      }

      if (mounted) {
        context.go('/instructor-clase');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              widget.claseId != null
                  ? '¡Clase actualizada exitosamente!'
                  : '¡Clase publicada exitosamente!',
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
          icon: Icon(Icons.arrow_back, color: GingaColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.claseId != null ? 'Editar clase' : 'Crear clase',
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
                  : Icon(widget.claseId != null ? Icons.save : Icons.add, size: 20),
              label: Text(widget.claseId != null ? 'Guardar cambios' : 'Publicar clase',
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
                  _label('Tipo de Sesión'),
                  const SizedBox(height: 8),
                  _tipoSelector(),
                  const SizedBox(height: 16),
                  _label(_tipoClase == 'regular' ? 'Nombre de la clase' : 'Título del Evento / Roda'),
                  const SizedBox(height: 8),
                  _tipoClase == 'regular' ? _dropdown() : _customNameField(),
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

            if (_tipoClase != 'regular') ...[
              const SizedBox(height: 16),
              _buildCard(
                title: 'Detalles del Evento (Opcional)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Organizador / Mestre Invitado'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _organizadorController,
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: GingaColors.textPrimary),
                      decoration: _inputDecoration(
                          'Ej: Mestre Sidney, Instructor Enrique...'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _label('Cronograma de Actividades'),
                        TextButton.icon(
                          onPressed: _agregarItemCronograma,
                          icon: const Icon(Icons.add, size: 16, color: GingaColors.brandGreen),
                          label: Text(
                            'Añadir bloque',
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
                    if (_cronograma.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No hay actividades programadas',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: GingaColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cronograma.length,
                        itemBuilder: (context, index) {
                          final item = _cronograma[index];
                          return Card(
                            key: ValueKey(item),
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                              side: BorderSide(color: GingaColors.borderLight),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  // Hora input
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      initialValue: item['hora'],
                                      onChanged: (val) {
                                        _cronograma[index]['hora'] = val;
                                      },
                                      style: GoogleFonts.nunito(
                                          fontSize: 12, color: GingaColors.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: '09:00 AM',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(GingaRadius.sm),
                                          borderSide: BorderSide(color: GingaColors.borderLight),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Actividad input
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item['actividad'],
                                      onChanged: (val) {
                                        _cronograma[index]['actividad'] = val;
                                      },
                                      style: GoogleFonts.nunito(
                                          fontSize: 12, color: GingaColors.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'Actividad...',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(GingaRadius.sm),
                                          borderSide: BorderSide(color: GingaColors.borderLight),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _cronograma.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Imagen de Portada (Opcional) ──────────────
            _buildCard(
              title: 'Imagen de Portada / Banner (Opcional)',
              child: GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(GingaRadius.md),
                    border: Border.all(color: GingaColors.borderLight),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _selectedImageFile != null
                      ? (kIsWeb
                          ? (_webImageBytes != null ? Image.memory(_webImageBytes!, fit: BoxFit.cover) : Container())
                          : Image.file(File(_selectedImageFile!.path), fit: BoxFit.cover))
                      : (_existingImageUrl.isNotEmpty
                          ? (_existingImageUrl.startsWith('assets/')
                              ? Image.asset(_existingImageUrl, fit: BoxFit.cover)
                              : GingaCachedImage(
                                  imageUrl: _existingImageUrl,
                                  fit: BoxFit.cover,
                                  category: 'evento',
                                  errorWidget: const Center(
                                    child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                                  ),
                                ))
                          : Container(
                              color: const Color(0xFFF8F8F8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 40,
                                    color: GingaColors.brandGreen,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Subir una foto de portada personalizada 📸',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: GingaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ideal para eventos y clases especiales',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: GingaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Horario recurrente ────────────────────────
            _buildCard(
              title: _tipoClase == 'regular' ? 'Horario recurrente' : 'Fecha y Horario',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(_tipoClase == 'regular' ? 'Días de la clase' : 'Fecha del Evento / Roda'),
                  const SizedBox(height: 12),
                  _tipoClase == 'regular'
                      ? Row(
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
                        )
                      : _datePickerButton(),
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
                  _label('Ubicación'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ubicacionController,
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: GingaColors.textPrimary),
                    decoration: _inputDecoration('Parque de la roda').copyWith(
                      suffixIcon: Icon(Icons.location_on_outlined,
                          color: GingaColors.textSecondary, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedLocation != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(GingaRadius.md),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => _showMapPicker(context),
                                child: AbsorbPointer(
                                  child: FlutterMap(
                                    options: MapOptions(
                                      initialCenter: _selectedLocation!,
                                      initialZoom: 15.0,
                                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName: 'com.jumperstudio.ginga_app',
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: _selectedLocation!,
                                            width: 35,
                                            height: 35,
                                            child: const Icon(
                                              Icons.location_on,
                                              color: GingaColors.brandGreen,
                                              size: 35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: ElevatedButton.icon(
                                onPressed: () => _showMapPicker(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.9),
                                  foregroundColor: GingaColors.textPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.edit, size: 14, color: GingaColors.brandGreen),
                                label: Text(
                                  'Cambiar',
                                  style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showMapPicker(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GingaRadius.md)),
                        ),
                        icon: const Icon(Icons.map_outlined, color: GingaColors.brandGreen, size: 18),
                        label: Text(
                          'Marcar ubicación exacta en el mapa 🗺️',
                          style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: GingaColors.brandGreen),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _toggleRow(
                    title: 'Clase de prueba gratuita',
                    subtitle: 'Primera clase gratis para alumnos nuevos',
                    value: _claseGratuita,
                    onChanged: (v) => setState(() => _claseGratuita = v),
                  ),
                  Divider(height: 24, color: GingaColors.borderLight),
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
                  Divider(height: 24, color: GingaColors.borderLight),
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
          borderSide: BorderSide(color: GingaColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide: BorderSide(color: GingaColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GingaRadius.md),
          borderSide:
              const BorderSide(color: GingaColors.brandGreen, width: 2),
        ),
      );

  Widget _tipoSelector() => Row(
        children: [
          Expanded(
            child: _tipoCard(
              label: 'Clase Regular',
              value: 'regular',
              icon: Icons.sports_martial_arts_rounded,
              selectedColor: GingaColors.brandGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _tipoCard(
              label: 'Evento',
              value: 'especial',
              icon: Icons.star_rounded,
              selectedColor: GingaColors.accentAmber,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _tipoCard(
              label: 'Roda',
              value: 'roda',
              icon: Icons.local_fire_department_rounded,
              selectedColor: Colors.deepOrange,
            ),
          ),
        ],
      );

  Widget _tipoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color selectedColor,
  }) {
    final isSelected = _tipoClase == value;
    return GestureDetector(
      onTap: () => setState(() => _tipoClase = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(GingaRadius.md),
          border: Border.all(
            color: isSelected ? selectedColor : GingaColors.borderLight,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : GingaColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? selectedColor : GingaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customNameField() => TextFormField(
        controller: _nombreCustomController,
        style: GoogleFonts.nunito(fontSize: 14, color: GingaColors.textPrimary),
        decoration: InputDecoration(
          hintText: _tipoClase == 'roda'
              ? 'ej. Roda de Integración, Roda de Fin de Año'
              : 'ej. Taller de Acrobacias, Masterclass Mestre Sidney',
          hintStyle: GoogleFonts.nunito(color: GingaColors.textSecondary, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF8F8F8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GingaRadius.md),
            borderSide: BorderSide(color: GingaColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GingaRadius.md),
            borderSide: BorderSide(color: GingaColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GingaRadius.md),
            borderSide: const BorderSide(color: GingaColors.brandGreen, width: 2),
          ),
        ),
      );

  Widget _datePickerButton() => InkWell(
        onTap: _seleccionarFechaEvento,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(GingaRadius.md),
            border: Border.all(color: GingaColors.borderLight),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: GingaColors.brandGreen, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _fechaTexto.isEmpty ? 'Seleccionar fecha del evento' : _fechaTexto,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: _fechaTexto.isEmpty ? FontWeight.w500 : FontWeight.w700,
                    color: _fechaTexto.isEmpty ? GingaColors.textSecondary : GingaColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_right_rounded,
                  color: GingaColors.textSecondary, size: 18),
            ],
          ),
        ),
      );

  Future<void> _seleccionarFechaEvento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: buildGingaDatePickerTheme,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _fechaTexto = _formatSpanishDate(picked);
      });
    }
  }

  String _formatSpanishDate(DateTime dt) {
    final List<String> weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final List<String> months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    final String weekday = weekdays[dt.weekday - 1];
    final String month = months[dt.month - 1];
    return '$weekday ${dt.day} de $month';
  }

  Widget _dropdown() {
    final List<String> itemsNombre = List.from(_nombresClase);
    if (!itemsNombre.contains(_nombreClase)) {
      itemsNombre.add(_nombreClase);
    }

    return Container(
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
          icon: Icon(Icons.keyboard_arrow_down,
              color: GingaColors.textSecondary),
          style: GoogleFonts.nunito(
              fontSize: 14, color: GingaColors.textPrimary),
          items: itemsNombre
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (val) => setState(() => _nombreClase = val!),
        ),
      ),
    );
  }

  Widget _sedeDropdown() {
    final List<String> itemsSede = List.from(_sedes);
    if (!itemsSede.contains(_selectedSede)) {
      itemsSede.add(_selectedSede);
    }

    return Container(
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
          icon: Icon(Icons.keyboard_arrow_down,
              color: GingaColors.textSecondary),
          style: GoogleFonts.nunito(
              fontSize: 14, color: GingaColors.textPrimary),
          items: itemsSede
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (val) => setState(() => _selectedSede = val!),
        ),
      ),
    );
  }

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
              Icon(Icons.access_time,
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

  Future<void> _notificarAlumnosNuevaClase(
      String claseId, String nombreClase, String tipo, String sede) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('sede', isEqualTo: sede)
          .where('rol', isEqualTo: 'alumno')
          .get();

      if (querySnapshot.docs.isEmpty) return;

      String titulo = '¡Nueva Clase Disponible! 🥋';
      String tipoNoti = 'clase';
      if (tipo == 'roda') {
        titulo = '¡Nueva Roda Especial! 🔥';
        tipoNoti = 'evento';
      } else if (tipo == 'especial') {
        titulo = '¡Nuevo Evento Especial! 🌟';
        tipoNoti = 'evento';
      }

      final String msg = tipo == 'regular'
          ? 'Se ha programado una nueva clase de "$nombreClase" para el grupo de tu sede. ¡Revisa los horarios!'
          : 'Se ha publicado el evento "$nombreClase" en tu sede. ¡Reserva tu cupo antes de que se agote!';

      int count = 0;
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in querySnapshot.docs) {
        final notifRef = FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .collection('notificaciones')
            .doc();

        batch.set(notifRef, {
          'titulo': titulo,
          'mensaje': msg,
          'fecha': FieldValue.serverTimestamp(),
          'leido': false,
          'tipo': tipoNoti,
          'clase_id': claseId,
        });

        count++;
        if (count % 400 == 0) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
        }
      }

      if (count % 400 != 0) {
        await batch.commit();
      }
      debugPrint('Notificaciones de nueva clase enviadas a $count alumnos.');
    } catch (e) {
      debugPrint('Error enviando notificaciones de nueva clase: $e');
    }
  }
}
