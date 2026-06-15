import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TutorialesService {
  TutorialesService._();
  static final TutorialesService instance = TutorialesService._();

  /// Carga datos mockup a Firestore de forma automática si la colección /tutoriales está vacía
  Future<void> inicializarTutorialesMockupSiVacia() async {
    try {
      final query = await FirebaseFirestore.instance.collection('tutoriales').limit(30).get();
      // Si la colección está vacía o tiene menos de 10 tutoriales (los 5 antiguos),
      // limpiamos la colección y sembramos los 23 movimientos oficiales de la Apostila de FIU.
      if (query.docs.length < 10) {
        debugPrint('Inicializando colección /tutoriales con 23 movimientos oficiales de la Apostila de FIU...');
        final batch = FirebaseFirestore.instance.batch();

        for (var doc in query.docs) {
          batch.delete(doc.reference);
        }

        final mockTutorials = [
          {
            'titulo': 'Passape',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'corda': 'Crua',
            'duracion': '6 min',
            'imagen_url': 'assets/images/passape.jpg',
            'descripcion': 'El passape es un movimiento de ataque circular que utiliza la parte externa del pie. Es fundamental mantener la pierna de apoyo firme y la guardia alta en todo momento para evitar contraataques rápidos.',
            'tipMestre': 'No quites la vista del oponente durante el giro del pie y mantén la guardia firme.',
            'tipError': 'Inclinar el tronco demasiado hacia atrás te hace perder el equilibrio y la potencia del golpe.',
          },
          {
            'titulo': 'Cocorinha',
            'categoria': 'Esquivas',
            'nivel': 'Iniciante',
            'corda': 'Crua',
            'duracion': '4 min',
            'imagen_url': 'assets/images/cocorinha.jpg',
            'descripcion': 'Una esquiva baja esencial de protección. Se realiza agachándose completamente sobre ambos pies, manteniendo los talones abajo y protegiendo el lateral de la cabeza con el brazo de guardia levantado.',
            'tipMestre': 'Mantén la mano contraria al brazo de guardia firmemente plantada en el suelo para mayor resorte y velocidad de escape.',
            'tipError': 'Levantar los talones del suelo al agacharte reduce drásticamente tu estabilidad y velocidad de reacción.',
          },
          {
            'titulo': 'Benção',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'corda': 'Crua',
            'duracion': '5 min',
            'imagen_url': 'assets/images/bencao.jpg',
            'descripcion': 'Patada frontal de empuje ejecutada con la planta del pie. Es un ataque lineal básico pero contundente que sirve para mantener la distancia o desplazar al oponente.',
            'tipMestre': 'Usa la cadera para proyectar la patada hacia adelante, no solo extiendas la pierna.',
            'tipError': 'No bajar bien la base de apoyo ni cubrirse la cara durante la ejecución te deja desprotegido.',
          },
          {
            'titulo': 'Martelo',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'corda': 'Crua',
            'duracion': '6 min',
            'imagen_url': 'assets/images/martelo.jpg',
            'descripcion': 'Patada lateral rápida impactando con el empeine o espinilla. Se ejecuta pivotando sobre el pie de apoyo y extendiendo la pierna en un plano horizontal.',
            'tipMestre': 'Gira completamente el pie de apoyo hacia el lado opuesto de la patada para proteger tu rodilla.',
            'tipError': 'Girar el tronco sin rotar el pie de apoyo provoca lesiones de rodilla y resta potencia.',
          },
          {
            'titulo': 'Esquiva Lateral',
            'categoria': 'Esquivas',
            'nivel': 'Iniciante',
            'corda': 'Crua',
            'duracion': '4 min',
            'imagen_url': 'assets/images/esquiva_lateral.jpg',
            'descripcion': 'Desplazamiento defensivo hacia un lateral flexionando la pierna del lado de la esquiva y manteniendo el brazo de guardia protegiendo el rostro.',
            'tipMestre': 'Mantén los ojos fijos en el oponente desde abajo de tu guardia lateral.',
            'tipError': 'Bajar la guardia o flexionar el torso sin bajar la cadera te hace vulnerable.',
          },
          {
            'titulo': 'Au (Rueda)',
            'categoria': 'Floreos',
            'nivel': 'Iniciante',
            'corda': 'Crua',
            'duracion': '7 min',
            'imagen_url': 'assets/images/au.jpg',
            'descripcion': 'El giro básico de rueda de la capoeira. Sirve para desplazarse por la roda, esquivar patadas altas de forma dinámica o iniciar transiciones.',
            'tipMestre': 'Mira siempre al oponente entre tus brazos mientras estás de cabeza en el giro.',
            'tipError': 'Hacer el Au de espaldas al compañero de juego o cerrar los ojos durante el giro.',
          },
          {
            'titulo': 'Queixada',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'corda': 'Crua e Verde',
            'duracion': '6 min',
            'imagen_url': 'assets/images/queixada.jpg',
            'descripcion': 'Patada semicircular de adentro hacia afuera impactando con el borde externo del pie, cruzando el cuerpo en diagonal.',
            'tipMestre': 'Da el paso cruzado previo (adecuación) con fluidez para cargar el peso e impulsar el giro.',
            'tipError': 'Lanzar la patada sin cruzar adecuadamente la base, lo que resta inercia y equilibrio.',
          },
          {
            'titulo': 'Armada',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'corda': 'Crua e Verde',
            'duracion': '7 min',
            'imagen_url': 'assets/images/armada.jpg',
            'descripcion': 'Patada giratoria básica de capoeira utilizando el impulso del cuerpo. Se genera fuerza mediante la rotación previa del tronco.',
            'tipMestre': 'Completa la mirada sobre tu hombro antes de soltar la pierna para apuntar al objetivo.',
            'tipError': 'Soltar la patada antes de ver al oponente, lo que provoca desvío e inestabilidad.',
          },
          {
            'titulo': 'Meia Lua de Compasso',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'corda': 'Crua e Verde',
            'duracion': '8 min',
            'imagen_url': 'assets/images/meia_lua_compasso.jpg',
            'descripcion': 'El movimiento de ataque insigne de la capoeira. Una patada giratoria baja apoyando una o dos manos en el suelo y mirando entre las piernas.',
            'tipMestre': 'Usa el talón de la pierna extendida como el punto de impacto y mantén los brazos flexionados para empujar.',
            'tipError': 'Dejar la pierna de apoyo completamente rígida o levantarse antes de finalizar la trayectoria de retorno.',
          },
          {
            'titulo': 'Macaco',
            'categoria': 'Floreos',
            'nivel': 'Iniciante',
            'corda': 'Crua e Verde',
            'duracion': '8 min',
            'imagen_url': 'assets/images/macaco.jpg',
            'descripcion': 'Resorte hacia atrás desde cuclillas impulsado por una sola mano apoyada detrás del cuerpo y empujando fuertemente con la cadera.',
            'tipMestre': 'Proyecta tu brazo libre con fuerza hacia atrás y arriba siguiendo la mirada de tu cabeza.',
            'tipError': 'Girar de lado en lugar de ir directamente hacia atrás, lo que sobrecarga lateralmente el hombro.',
          },
          {
            'titulo': 'Rasteira no Chão',
            'categoria': 'Defensas',
            'nivel': 'Iniciante',
            'corda': 'Crua e Verde',
            'duracion': '6 min',
            'imagen_url': 'assets/images/rasteira_chao.jpg',
            'descripcion': 'Barrido de desequilibrio defensivo realizado a ras del suelo, enganchando el pie de apoyo del oponente para derribarlo.',
            'tipMestre': 'Baja completamente la cadera y utiliza la mano de apoyo en el suelo para jalar con torque.',
            'tipError': 'Intentar hacer el barrido estando de pie, lo que te expone a ser pateado o empujado.',
          },
          {
            'titulo': 'Benção Pulada',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'corda': 'Verde',
            'duracion': '7 min',
            'imagen_url': 'assets/images/bencao_pulada.jpg',
            'descripcion': 'Variación avanzada de la patada benção, ejecutando un salto explosivo con la pierna de apoyo antes del impacto.',
            'tipMestre': 'Usa la rodilla de la pierna que no patea para ganar altura en el despegue inicial.',
            'tipError': 'Lanzar la patada sin haber alcanzado el punto máximo del salto, cayendo sin balance.',
          },
          {
            'titulo': 'Tesoura numa perna só',
            'categoria': 'Defensas',
            'nivel': 'Iniciante',
            'corda': 'Verde',
            'duracion': '8 min',
            'imagen_url': 'assets/images/tesoura_perna.jpg',
            'descripcion': 'Técnica de tijera y derribo rodeando y bloqueando una sola pierna del oponente (generalmente detrás de la corva y el tobillo).',
            'tipMestre': 'Entra con decisión pegando tu cadera al pie de apoyo del rival antes de cerrar el agarre.',
            'tipError': 'Dejar mucho espacio entre tu cadera y el oponente, lo que anula la palanca física.',
          },
          {
            'titulo': 'Au de Costas',
            'categoria': 'Floreos',
            'nivel': 'Iniciante',
            'corda': 'Verde',
            'duracion': '7 min',
            'imagen_url': 'assets/images/au_costas.jpg',
            'descripcion': 'Rueda invertida realizada de espaldas. Es un movimiento fluido para salir de esquivas o cambiar la dirección de la roda.',
            'tipMestre': 'Empuja activamente el suelo y mantén las piernas juntas al pasar por la vertical.',
            'tipError': 'Arquear demasiado la columna o perder el control de la dirección en el retorno.',
          },
          {
            'titulo': 'Queda de Rim',
            'categoria': 'Floreos',
            'nivel': 'Iniciante',
            'corda': 'Verde',
            'duracion': '7 min',
            'imagen_url': 'assets/images/queda_rim.jpg',
            'descripcion': 'Equilibrio básico apoyando el codo del brazo fuerte en el lateral de la cadera o lumbares, sosteniendo el cuerpo de lado.',
            'tipMestre': 'Mantén el cuello relajado y la cabeza cerca del suelo sin apoyar el peso en ella.',
            'tipError': 'No encajar el codo firmemente en la cresta ilíaca, resbalando y perdiendo la postura.',
          },
          {
            'titulo': 'Ponteira',
            'categoria': 'Ataques',
            'nivel': 'Iniciante',
            'corda': 'Verde e Laranja',
            'duracion': '6 min',
            'imagen_url': 'assets/images/ponteira.jpg',
            'descripcion': 'Patada frontal de ataque veloz impactando con la punta de los dedos del pie o el metatarso. Es muy penetrante.',
            'tipMestre': 'Extiende el tobillo completamente al golpear para concentrar la fuerza de penetración.',
            'tipError': 'Lanzar el golpe con los dedos del pie rígidos hacia arriba, lo que causa fracturas al impactar.',
          },
          {
            'titulo': 'Tesoura de Lado',
            'categoria': 'Defensas',
            'nivel': 'Iniciante',
            'corda': 'Verde e Laranja',
            'duracion': '8 min',
            'imagen_url': 'assets/images/tesoura_lado.jpg',
            'descripcion': 'Derribo desequilibrante lateral rodeando las piernas del oponente con un movimiento de tijera horizontal rápida.',
            'tipMestre': 'Gira tu cuerpo de costado para que la pierna de arriba presione el pecho y la de abajo barra.',
            'tipError': 'Hacer la tijera de espaldas, reduciendo la efectividad del agarre y exponiendo la columna.',
          },
          {
            'titulo': 'Corta Capim',
            'categoria': 'Floreos',
            'nivel': 'Iniciante',
            'corda': 'Verde e Laranja',
            'duracion': '5 min',
            'imagen_url': 'assets/images/corta_capim.jpg',
            'descripcion': 'Giro circular continuo agachado, pasando una pierna extendida por debajo de la de apoyo saltando levemente.',
            'tipMestre': 'Mantén el centro de gravedad muy bajo apoyando las yemas de los dedos en el suelo.',
            'tipError': 'Levantar demasiado el cuerpo, lo que dificulta saltar la pierna extendida.',
          },
          {
            'titulo': 'Cabeçada',
            'categoria': 'Defensas',
            'nivel': 'Regular',
            'corda': 'Laranja',
            'duracion': '5 min',
            'imagen_url': 'assets/images/cabecada.jpg',
            'descripcion': 'Ataque de desequilibrio embistiendo con la zona superior de la frente al pecho o abdomen del rival al esquivar.',
            'tipMestre': 'Asegura la base de tus piernas al empujar con la cabeza y mantén los ojos abiertos.',
            'tipError': 'Impactar con la coronilla en lugar de la frente alta, lo que puede causar daño cervical.',
          },
          {
            'titulo': 'Au Chibata',
            'categoria': 'Floreos',
            'nivel': 'Regular',
            'corda': 'Laranja',
            'duracion': '8 min',
            'imagen_url': 'assets/images/au_chibata.jpg',
            'descripcion': 'Rueda acrobática interrumpiendo el giro de cabeza para lanzar una fuerte patada de látigo descendente.',
            'tipMestre': 'Frena la inercia del giro contrayendo el abdomen antes de soltar el azote de la pierna.',
            'tipError': 'Dejarse llevar por la inercia del Au completo sin lograr marcar el golpe de chibata.',
          },
          {
            'titulo': 'Au Batido',
            'categoria': 'Floreos',
            'nivel': 'Graduado',
            'corda': 'Amarela',
            'duracion': '8 min',
            'imagen_url': 'assets/images/au_batido.jpg',
            'descripcion': 'El Au Batido (o Au de Bico) es un giro de rueda bloqueado a mitad de camino sobre una mano, lanzando una patada defensiva.',
            'tipMestre': 'Fortalece tus muñecas y empuja activamente el suelo con el hombro del brazo de apoyo.',
            'tipError': 'Dejar caer la cadera antes de completar el bloqueo arruina la postura y puede sobrecargar tu hombro.',
          },
          {
            'titulo': 'Banda de Frente',
            'categoria': 'Defensas',
            'nivel': 'Graduado',
            'corda': 'Amarela',
            'duracion': '7 min',
            'imagen_url': 'assets/images/banda_frente.jpg',
            'descripcion': 'Derribo clásico por zancadilla barriendo con el pie interno del empeine del oponente cuando éste patea o avanza.',
            'tipMestre': 'Jala el hombro del oponente en sentido contrario al barrido para maximizar el desequilibrio.',
            'tipError': 'Intentar barrer sin desestabilizar la parte superior del cuerpo del rival.',
          },
          {
            'titulo': 'Vingativa',
            'categoria': 'Defensas',
            'nivel': 'Avanzado',
            'corda': 'Azul',
            'duracion': '7 min',
            'imagen_url': 'assets/images/vingativa.jpg',
            'descripcion': 'Proyección de desequilibrio entrando profundamente por detrás de la rodilla del oponente aplicando palanca contraria.',
            'tipMestre': 'Coloca tu cadera siempre más baja que la de tu oponente para lograr un centro de gravedad ideal.',
            'tipError': 'Intentar empujar con fuerza bruta en los hombros en lugar de pivotar y barrer con la técnica de palanca.',
          }
        ];

        for (var tutorial in mockTutorials) {
          final docRef = FirebaseFirestore.instance.collection('tutoriales').doc();
          batch.set(docRef, tutorial);
        }

        await batch.commit();
        debugPrint('Se crearon ${mockTutorials.length} tutoriales de prueba con éxito.');
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
    required String corda,
    required String duracion,
    required String descripcion,
    required String tipMestre,
    required String tipError,
    required String imagenUrl,
    String videoUrl = '',
    bool visible = true,
  }) async {
    final data = {
      'titulo': titulo,
      'categoria': categoria,
      'nivel': nivel,
      'corda': corda,
      'duracion': duracion,
      'descripcion': descripcion,
      'tipMestre': tipMestre,
      'tipError': tipError,
      'imagen_url': imagenUrl,
      'video_url': videoUrl,
      'visible': visible,
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
  Future<String> subirPortadaTutorial(XFile imageFile) async {
    final fileName = 'tutoriales_portadas/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    if (kIsWeb) {
      final bytes = await imageFile.readAsBytes();
      final uploadTask = await ref.putData(bytes);
      return await uploadTask.ref.getDownloadURL();
    } else {
      final uploadTask = await ref.putFile(File(imageFile.path));
      return await uploadTask.ref.getDownloadURL();
    }
  }

  /// Sube el video seleccionado a Firebase Storage y retorna la URL pública
  Future<String> subirVideoTutorial(XFile videoFile) async {
    final fileName = 'tutoriales_videos/${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    if (kIsWeb) {
      final bytes = await videoFile.readAsBytes();
      final uploadTask = await ref.putData(bytes);
      return await uploadTask.ref.getDownloadURL();
    } else {
      final uploadTask = await ref.putFile(File(videoFile.path));
      return await uploadTask.ref.getDownloadURL();
    }
  }
}
