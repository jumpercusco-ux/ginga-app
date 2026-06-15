import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventosService {
  EventosService._();
  static final EventosService instance = EventosService._();

  /// Inicializa un evento de prueba en Firestore si la colección /eventos está vacía
  Future<void> inicializarEventosMockupSiVacia() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Se pospone la inicialización de eventos mockup (sin sesión activa).');
        return;
      }

      // Validar rol del usuario en Firestore para evitar escrituras no autorizadas
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        debugPrint('Sembrado omitido: El documento de usuario no existe.');
        return;
      }
      final userData = userDoc.data();
      final rol = userData != null ? userData['rol'] : 'alumno';
      if (rol != 'profesor') {
        debugPrint('Sembrado de eventos mockup omitido: El usuario actual no tiene rol de profesor ($rol).');
        return;
      }
      
      final query = await FirebaseFirestore.instance.collection('eventos').limit(1).get();
      if (query.docs.isEmpty) {
        debugPrint('Inicializando colección /eventos con evento de prueba...');
        
        // Creamos un evento programado para el futuro cercano (Junio de 2026)
        final DateTime eventDateStart = DateTime(2026, 6, 12, 19, 0);
        final DateTime eventDateEnd = DateTime(2026, 6, 14, 13, 0);

        final mockEvent = {
          'titulo': 'Taller de Floreos, Acrobacias & Roda',
          'organizador': 'Mestre Enrique (Brasil)',
          'fecha_inicio': Timestamp.fromDate(eventDateStart),
          'fecha_fin': Timestamp.fromDate(eventDateEnd),
          'fecha_texto': '12 al 14 de Junio, 2026',
          'lugar': 'Academia Ginga Principal',
          'descripcion': 'Un taller intensivo de tres días enfocado en el dominio del movimiento corporal, transiciones acrobáticas en la roda y los fundamentos de los toques tradicionales.',
          'imagen_url': 'assets/images/roda.jpg',
          'cronograma': [
            {
              'dia': 'Viernes 12',
              'hora': '7:00 PM',
              'actividad': 'Acondicionamiento físico y floreos de base.'
            },
            {
              'dia': 'Sábado 13',
              'hora': '4:00 PM',
              'actividad': 'Combinaciones complejas, saltos y patadas aéreas.'
            },
            {
              'dia': 'Domingo 14',
              'hora': '10:00 AM',
              'actividad': 'Gran Roda de integración, entrega de diplomas y cierre.'
            }
          ]
        };

        await FirebaseFirestore.instance.collection('eventos').add(mockEvent);
        debugPrint('Se inicializó el evento de prueba con éxito.');
      }
    } catch (e) {
      debugPrint('Error al inicializar eventos mockup: $e');
    }
  }

  /// Inicializa el entreno y roda del Sábado 30 de Mayo si no existe
  Future<void> inicializarEntreno30Mayo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Validar rol del usuario en Firestore para evitar escrituras no autorizadas
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data();
      final rol = userData != null ? userData['rol'] : 'alumno';
      if (rol != 'profesor') {
        debugPrint('Sembrado de entreno 30 de Mayo omitido: El usuario actual no tiene rol de profesor ($rol).');
        return;
      }

      // 1. Sembrar en la colección /clases
      final queryClase = await FirebaseFirestore.instance
          .collection('clases')
          .where('dias', isEqualTo: 'Sábado 30 de Mayo')
          .where('hora', isEqualTo: '2:30 PM - 4:00 PM')
          .get();

      if (queryClase.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('clases').add({
          'hora': '2:30 PM - 4:00 PM',
          'nivel': 'Geral / Todos los niveles',
          'badge': 'Entreno y Roda ☀️',
          'dias': 'Sábado 30 de Mayo',
          'instructor': 'Mestre Sidney',
          'cupos_disponibles': 25,
          'tipo': 'especial',
          'sede': 'Cusco',
          'lugar': 'Parque AMAUTA, Urb. Magisterio (El Mapa)',
        });
      } else {
        // Garantizar que todos los registros de este evento tengan la Sede 'Cusco' para retrocompatibilidad
        for (var doc in queryClase.docs) {
          final data = doc.data();
          if (data['sede'] == null || data['sede'] != 'Cusco') {
            await doc.reference.update({'sede': 'Cusco'});
          }
        }
      }

      // 2. Sembrar en la colección /eventos
      final queryEvento = await FirebaseFirestore.instance
          .collection('eventos')
          .where('fecha_texto', isEqualTo: 'Sábado 30 de Mayo, 2:30 PM - 4:00 PM')
          .get();

      if (queryEvento.docs.isEmpty) {
        final start = DateTime(2026, 5, 30, 14, 30);
        final end = DateTime(2026, 5, 30, 16, 0);

        await FirebaseFirestore.instance.collection('eventos').add({
          'titulo': 'Entreno y Roda al Aire Libre',
          'organizador': 'Mestre Sidney',
          'fecha_inicio': Timestamp.fromDate(start),
          'fecha_fin': Timestamp.fromDate(end),
          'fecha_texto': 'Sábado 30 de Mayo, 2:30 PM - 4:00 PM',
          'lugar': 'Parque AMAUTA, Urb. Magisterio (El Mapa)',
          'descripcion': 'Entrenamiento al aire libre y Roda de integración para toda la Familia FIU. Ven a entrenar, tocar berimbau y jugar en la roda en el tradicional Parque Amauta (Magisterio), también conocido como "El Mapa". ¡Todos los niveles son bienvenidos!',
          'imagen_url': 'assets/images/fiu_banner.png',
          'cronograma': [
            {
              'dia': 'Sábado 30',
              'hora': '2:30 PM',
              'actividad': 'Calentamiento y entrenamiento de técnica física básica/avanzada.'
            },
            {
              'dia': 'Sábado 30',
              'hora': '3:15 PM',
              'actividad': 'Roda de integración, cantos y toques de berimbau.'
            }
          ]
        });
      }
    } catch (e) {
      debugPrint('Error al inicializar entreno 30 de Mayo: $e');
    }
  }

  /// Registra la asistencia de un alumno al evento especificado
  Future<void> registrarAsistencia(String eventId, String userNombre) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final ref = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventId)
        .collection('registros')
        .doc(user.uid);

    await ref.set({
      'user_id': user.uid,
      'nombre': userNombre,
      'fecha_registro': Timestamp.now(),
      'confirmado': true,
    });
  }

  /// Verifica si el usuario ya está registrado en el evento
  Stream<bool> estaRegistrado(String eventId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventId)
        .collection('registros')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }
}
