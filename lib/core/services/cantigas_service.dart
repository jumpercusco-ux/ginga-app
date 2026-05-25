import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CantigasService {
  CantigasService._();
  static final CantigasService instance = CantigasService._();

  /// Inicializa la colección /cantigas con cantigas mockup de capoeira si está vacía
  Future<void> inicializarCantigasSiVacia() async {
    try {
      final query = await FirebaseFirestore.instance.collection('cantigas').limit(1).get();
      if (query.docs.isEmpty) {
        debugPrint('Inicializando colección /cantigas en Firestore...');
        final batch = FirebaseFirestore.instance.batch();

        final mockCantigas = [
          {
            'titulo': 'Quem Quiser Saber de Mim',
            'ritmo': 'Corrido',
            'autor': 'Tradicional',
            'duracion': '2:15',
            'contexto': 'Este canto tradicional es un corrido de auto-afirmación y respeto por la ancestría nagô. Invita a los jugadores a reconocer su linaje, trayendo una vibra profunda y enérgica al juego.',
            'letraPt': '''Quem quiser saber de mim
Quem quiser saber de mim
Vai na ladeira do pelô
Minha coroa é de ouro
Minha coroa é de ouro
Sou neto de rei nagô

Quem quiser saber de mim
Quem quiser saber de mim
Vai na ladeira do pelô
Minha coroa é de ouro
Minha coroa é de ouro
Sou neto de rei nagô''',
            'letraEs': '''Quien quiera saber de mí
Quien quiera saber de mí
Vaya a la cuesta del pelourinho
Mi corona es de oro
Mi corona es de oro
Soy nieto de rey nagô

Quien quiera saber de mí
Quien quiera saber de mí
Vaya a la cuesta del pelourinho
Mi corona es de oro
Mi corona es de oro
Soy nieto de rey nagô''',
            'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          },
          {
            'titulo': 'Paraná Ê',
            'ritmo': 'Corrido',
            'autor': 'Tradicional',
            'duracion': '3:05',
            'contexto': 'Uno de los cantos más célebres y representativos de la capoeira. Su trasfondo histórico evoca nostalgia, añoranza de la libertad y resistencia durante la Guerra del Paraguay, marcando el retorno triunfante a Bahía.',
            'letraPt': '''Paraná ê, Paraná ê, Paraná.
Paraná ê, Paraná ê, Paraná.

Vou me embora pra Bahia,
Terra de São Salvador.

Paraná ê, Paraná ê, Paraná.
Paraná ê, Paraná ê, Paraná.

Berimbau bateu com força,
Meu peito até chorou.

Paraná ê, Paraná ê, Paraná.
Paraná ê, Paraná ê, Paraná.

Quem não sabe andar de gunga,
Não se mete a capoeira.

Paraná ê, Paraná ê, Paraná.
Paraná ê, Paraná ê, Paraná.''',
            'letraEs': '''Paraná eh, Paraná eh, Paraná.
Paraná eh, Paraná eh, Paraná.

Me voy a ir para Bahía,
Tierra de San Salvador (capital).

Paraná eh, Paraná eh, Paraná.
Paraná eh, Paraná eh, Paraná.

El berimbau sonó con fuerza,
Mi pecho hasta lloró.

Paraná eh, Paraná eh, Paraná.
Paraná eh, Paraná eh, Paraná.

Quien no sabe tocar el gunga,
No se mete a la capoeira.

Paraná eh, Paraná eh, Paraná.
Paraná eh, Paraná eh, Paraná.''',
            'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
          },
          {
            'titulo': 'Vem no Navio de Aruanda',
            'ritmo': 'Samba de Roda',
            'autor': 'Tradicional',
            'duracion': '2:40',
            'contexto': 'Un canto rítmico que celebra los viajes, la libertad espiritual y la conexión con Aruanda, el lugar sagrado de la paz y el reencuentro de los ancestros.',
            'letraPt': '''Vem no navio de Aruanda, vem
Vem no navio de Aruanda, vem
Aruanda ê, Aruanda ê, camará

Vem no navio de Aruanda, vem
Vem no navio de Aruanda, vem
O vento que sopra na mata
Traz o canto de fé e axé

Vem no navio de Aruanda, vem
Vem no navio de Aruanda, vem''',
            'letraEs': '''Viene en el barco de Aruanda, viene
Viene en el barco de Aruanda, viene
Aruanda eh, Aruanda eh, camarada

Viene en el barco de Aruanda, viene
Viene en el barco de Aruanda, viene
El viento que sopla en la selva
Trae el canto de fe y axé (energía)

Viene en el barco de Aruanda, viene
Viene en el barco de Aruanda, viene''',
            'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
          },
          {
            'titulo': 'Ô Nanã Deixa Eu Ir',
            'ritmo': 'Ladainha',
            'autor': 'Tradicional',
            'duracion': '3:12',
            'contexto': 'Una hermosa ladainha en la que el capoeirista pide protección espiritual e iniciación antes de entrar en el juego rítmico del berimbau.',
            'letraPt': '''Ô Nanã, deixa eu ir
Deixa eu ir na roda jogar
Ô Nanã, deixa eu ir
Deixa eu ir capoeirar

Eu sou filho de aruanda
Minha vida é o berimbau
Peço a benção do meu mestre
Pra livrar de todo mal

Ô Nanã, deixa eu ir
Deixa eu ir na roda jogar
Ô Nanã, deixa eu ir
Deixa eu ir capoeirar''',
            'letraEs': '''Oh Nanã, déjame ir
Déjame ir a jugar a la roda
Oh Nanã, déjame ir
Déjame ir a capoeirar

Yo soy hijo de aruanda
Mi vida es el berimbau
Pido la bendición de mi maestro
Para librarme de todo mal

Oh Nanã, déjame ir
Déjame ir a jugar a la roda
Oh Nanã, déjame ir
Déjame ir a capoeirar''',
            'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
          },
          {
            'titulo': 'Tamos Juntos e Misturados',
            'ritmo': 'Corrido',
            'autor': 'Moderno',
            'duracion': '2:30',
            'contexto': 'Un corrido moderno muy alegre que exalta la hermandad, el trabajo en equipo y la unión inquebrantable de la comunidad capoeirista de Ginga App en cada roda.',
            'letraPt': '''Tamos juntos e misturados
Na roda de capoeira
Joga bonito, joga de gunga
De segunda a sexta-feira

Tamos juntos e misturados
Ninguém joga sozinho aqui
Suda o corpo, alegra a alma
Na escola que eu escolhi

Tamos juntos e misturados
Na roda de capoeira
Joga bonito, joga de gunga
De segunda a sexta-feira''',
            'letraEs': '''Estamos juntos y mezclados
En la roda de capoeira
Juega bonito, juega de gunga
De lunes a viernes

Estamos juntos y mezclados
Nadie juega solo aquí
Suda el cuerpo, alegra el alma
En la escuela que yo elegí

Estamos juntos y mezclados
En la roda de capoeira
Juega bonito, juega de gunga
De lunes a viernes''',
            'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
          }
        ];

        for (var cantiga in mockCantigas) {
          final docRef = FirebaseFirestore.instance.collection('cantigas').doc();
          batch.set(docRef, cantiga);
        }

        await batch.commit();
        debugPrint('Se crearon las 5 cantigas en Firestore con éxito.');
      }
    } catch (e) {
      debugPrint('Error al inicializar cantigas mockup: $e');
    }
  }
}
