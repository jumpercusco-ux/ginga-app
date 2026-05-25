import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventosService {
  EventosService._();
  static final EventosService instance = EventosService._();

  /// Inicializa un evento de prueba en Firestore si la colección /eventos está vacía
  Future<void> inicializarEventosMockupSiVacia() async {
    try {
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
