import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class TutorialesService {
  TutorialesService._();
  static final TutorialesService instance = TutorialesService._();

  /// Carga datos mockup a Firestore de forma automática si la colección /tutoriales está vacía
  Future<void> inicializarTutorialesMockupSiVacia() async {
    try {
      final query = await FirebaseFirestore.instance.collection('tutoriales').limit(1).get();
      if (query.docs.isEmpty) {
        debugPrint('Inicializando colección /tutoriales con tutoriales de prueba...');
        final batch = FirebaseFirestore.instance.batch();

        final mockTutorials = [
          {
            'titulo': 'Passape',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'duracion': '6 min',
            'imagen_url': 'assets/images/passape.jpg',
            'descripcion': 'El passape es un movimiento de ataque circular que utiliza la parte externa del pie. Es fundamental mantener la pierna de apoyo firme y la guardia alta en todo momento para evitar contraataques rápidos.',
            'tipMestre': 'No quites la vista del oponente durante el giro del pie y mantén la guardia firme.',
            'tipError': 'Inclinar el tronco demasiado hacia atrás te hace perder el equilibrio y la potencia del golpe.',
          },
          {
            'titulo': 'Au Batido',
            'category': 'Floreos', // wait, let's keep it 'categoria' in firestore just to be standard!
            'categoria': 'Floreos',
            'nivel': 'Graduado',
            'duracion': '8 min',
            'imagen_url': 'assets/images/au_batido.jpg',
            'descripcion': 'El Au Batido (también conocido como Au de Bico) es una de las acrobacias más icónicas y funcionales de la capoeira. Combina un giro de Au (rueda) bloqueado a mitad de camino sobre una sola mano, lanzando una patada defensiva/ofensiva con la pierna libre mientras proteges el rostro.',
            'tipMestre': 'Fortalece tus muñecas y empuja activamente el suelo con el hombro del brazo de apoyo para ganar altura.',
            'tipError': 'Dejar caer la cadera antes de completar el bloqueo arruina la postura y puede sobrecargar tu hombro.',
          },
          {
            'titulo': 'Meia Lua de Frente',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'duracion': '6 min',
            'imagen_url': 'assets/images/meia_lua.jpg',
            'descripcion': 'Un movimiento semicircular básico de ataque de afuera hacia adentro. La pierna describe un semicírculo amplio y extendido frente al cuerpo cruzando la línea de guardia del oponente.',
            'tipMestre': 'Mantén el talón de la pierna de apoyo completamente plantado en el suelo para no perder estabilidad.',
            'tipError': 'Bajar los brazos durante el recorrido de la patada expone tu cabeza a una contrapatada directa.',
          },
          {
            'titulo': 'Cocorinha',
            'categoria': 'Esquivas',
            'nivel': 'Iniciante',
            'duracion': '4 min',
            'imagen_url': 'assets/images/cocorinha.jpg',
            'descripcion': 'Una esquiva baja esencial de protección. Se realiza agachándose completamente sobre ambos pies, manteniendo los talones abajo y protegiendo el lateral de la cabeza con el brazo de guardia levantado.',
            'tipMestre': 'Mantén la mano contraria al brazo de guardia firmemente plantada en el suelo para mayor resorte y velocidad de escape.',
            'tipError': 'Levantar los talones del suelo al agacharte reduce drásicamente tu estabilidad y velocidad de reacción.',
          },
          {
            'titulo': 'Vingativa',
            'categoria': 'Defensas',
            'nivel': 'Avanzado',
            'duracion': '7 min',
            'imagen_url': 'assets/images/vingativa.jpg',
            'descripcion': 'Una proyección de desequilibrio clásica y muy efectiva. Consiste en entrar profundamente detrás de la pierna de apoyo de tu oponente, bloqueando su retirada mientras aplicas fuerza en dirección opuesta con tu tronco/codo.',
            'tipMestre': 'Coloca tu cadera siempre más baja que la de tu oponente para lograr un centro de gravedad y apalancamiento ideales.',
            'tipError': 'Intentar empujar con fuerza bruta en los hombros en lugar de pivotar y barrer con la técnica de palanca.',
          }
        ];

        for (var tutorial in mockTutorials) {
          final docRef = FirebaseFirestore.instance.collection('tutoriales').doc();
          batch.set(docRef, tutorial);
        }

        await batch.commit();
        debugPrint('Se crearon 5 tutoriales de prueba con éxito.');
      }
    } catch (e) {
      debugPrint('Error al inicializar tutoriales mockup: $e');
    }
  }

  /// Crea o actualiza un tutorial en Firestore
  Future<void> crearOActualizarTutorial({
    String? id,
    required String titulo,
    required String categoria,
    required String nivel,
    required String duracion,
    required String descripcion,
    required String tipMestre,
    required String tipError,
    required String imagenUrl,
    String videoUrl = '',
  }) async {
    final data = {
      'titulo': titulo,
      'categoria': categoria,
      'nivel': nivel,
      'duracion': duracion,
      'descripcion': descripcion,
      'tipMestre': tipMestre,
      'tipError': tipError,
      'imagen_url': imagenUrl,
      'video_url': videoUrl,
    };

    if (id != null && id.isNotEmpty) {
      await FirebaseFirestore.instance.collection('tutoriales').doc(id).update(data);
    } else {
      await FirebaseFirestore.instance.collection('tutoriales').add(data);
    }
  }

  /// Elimina un tutorial de Firestore
  Future<void> eliminarTutorial(String id) async {
    await FirebaseFirestore.instance.collection('tutoriales').doc(id).delete();
  }

  /// Sube la imagen seleccionada a Firebase Storage y retorna la URL pública
  Future<String> subirPortadaTutorial(File imageFile) async {
    final fileName = 'tutoriales_portadas/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    final uploadTask = await ref.putFile(imageFile);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Sube el video seleccionado a Firebase Storage y retorna la URL pública
  Future<String> subirVideoTutorial(File videoFile) async {
    final fileName = 'tutoriales_videos/${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    final uploadTask = await ref.putFile(videoFile);
    return await uploadTask.ref.getDownloadURL();
  }
}
