import 'package:flutter/material.dart';

class CordaFIU {
  final int index;
  final String nombre;
  final String rango;
  final String simbolismo;
  final String descripcion;
  final List<Color> colores; // Si es un color sólido o mezcla
  final bool esMixta;

  const CordaFIU({
    required this.index,
    required this.nombre,
    required this.rango,
    required this.simbolismo,
    required this.descripcion,
    required this.colores,
    required this.esMixta,
  });
}

class CuerdasFIU {
  static const List<CordaFIU> lista = [
    CordaFIU(
      index: 1,
      nombre: 'Crua',
      rango: 'Iniciante',
      simbolismo: 'El Universo 🌌',
      descripcion: 'Es la cuerda de todo ingresante a la capoeira. Simboliza el universo de aprendizaje que está por delante y el punto de partida.',
      colores: [Color(0xFFE0E0E0), Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
      esMixta: false,
    ),
    CordaFIU(
      index: 2,
      nombre: 'Crua e Verde',
      rango: 'Iniciante (Transición)',
      simbolismo: 'Transición al Oxígeno 🍃',
      descripcion: 'Cuerda mixta de transición. Representa los primeros cimientos firmes y el inicio del crecimiento técnico.',
      colores: [Color(0xFFE0E0E0), Color(0xFF388E3C)],
      esMixta: true,
    ),
    CordaFIU(
      index: 3,
      nombre: 'Verde',
      rango: 'Alumno Iniciante 🥋',
      simbolismo: 'El Oxígeno 💨',
      descripcion: 'Es cuando el alumno/a pasa a ganar más resistencia física y agilidad durante los entrenamientos. Transmite armonía, salud y equilibrio.',
      colores: [Color(0xFF2E7D32), Color(0xFF4CAF50), Color(0xFF2E7D32)],
      esMixta: false,
    ),
    CordaFIU(
      index: 4,
      nombre: 'Verde e Laranja',
      rango: 'Alumno Iniciante (Transición)',
      simbolismo: 'Transición al Despertar 🌅',
      descripcion: 'Cuerda mixta de transición que une la resistencia del verde con la agilidad y calor del naranja.',
      colores: [Color(0xFF388E3C), Color(0xFFFF9800)],
      esMixta: true,
    ),
    CordaFIU(
      index: 5,
      nombre: 'Laranja',
      rango: 'Alumno Regular ☀️',
      simbolismo: 'El Despertar del Sol ☀️',
      descripcion: 'Es cuando el alumno/a está despertando sus sentimientos por la Capoeira, sus reflejos y su fuerza de voluntad. Transmite agilidad mental y corporal, encorajamiento y dedicación.',
      colores: [Color(0xFFE65100), Color(0xFFFF9800), Color(0xFFE65100)],
      esMixta: false,
    ),
    CordaFIU(
      index: 6,
      nombre: 'Laranja e Amarelo',
      rango: 'Alumno Regular (Transición)',
      simbolismo: 'Transición al Ouro 🌟',
      descripcion: 'Cuerda mixta que prepara al practicante para valorar formalmente su trayectoria con madurez e intelecto.',
      colores: [Color(0xFFFF9800), Color(0xFFFBC02D)],
      esMixta: true,
    ),
    CordaFIU(
      index: 7,
      nombre: 'Amarela',
      rango: 'Alumno Graduado / Intermedio 🌟',
      simbolismo: 'El Oro 🏆',
      descripcion: 'Es cuando el alumno/a comienza a valorar profundamente su aprendizaje, a valorarse como capoeirista y a valorar a su mestre y a su grupo con otros ojos. Transmite luz, energía e intelecto.',
      colores: [Color(0xFFF57F17), Color(0xFFFBC02D), Color(0xFFF57F17)],
      esMixta: false,
    ),
    CordaFIU(
      index: 8,
      nombre: 'Amarelo e Azul',
      rango: 'Monitor/a 🎖️',
      simbolismo: 'Transición al Mar (Monitoría) 🌊',
      descripcion: 'Cuerda mixta que otorga el grado de Monitor. El estudiante asiste activamente en clases y representa al grupo en ceremonias.',
      colores: [Color(0xFFFBC02D), Color(0xFF1E88E5)],
      esMixta: true,
    ),
    CordaFIU(
      index: 9,
      nombre: 'Azul',
      rango: 'Instrutor/a de Capoeira 🌊',
      simbolismo: 'La Imensidad del Mar 🌊',
      descripcion: 'Es cuando el alumno/a mira para atrás y ve el gran camino que ya recorrió, y cuando mira hacia el frente ve el gran trecho que le falta por recorrer. Transmite tranquilidad, serenidad, sinceridad y absoluta confianza.',
      colores: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF1565C0)],
      esMixta: false,
    ),
    CordaFIU(
      index: 10,
      nombre: 'Azul e Roxa',
      rango: 'Instrutor/a de 2º Grau 🔮',
      simbolismo: 'Transición a Piedras Preciosas 💎',
      descripcion: 'Grado intermedio de instructor que demuestra liderazgo consolidado, técnica de juego veloz y musicalidad avanzada en el berimbau.',
      colores: [Color(0xFF1E88E5), Color(0xFF8E24AA)],
      esMixta: true,
    ),
    CordaFIU(
      index: 11,
      nombre: 'Roxa',
      rango: 'Professor/a de Capoeira 🔮',
      simbolismo: 'Piedras Preciosas 💎',
      descripcion: 'El capoeirista representa una piedra preciosa lapidada de inmenso valor. Deja de ser alumno para convertirse en Profesor oficial, acompañando el trabajo del grupo por 10 a 13 años. Transmite respeto, devoción y dignidad.',
      colores: [Color(0xFF4A148C), Color(0xFF8E24AA), Color(0xFF4A148C)],
      esMixta: false,
    ),
    CordaFIU(
      index: 12,
      nombre: 'Roxa e Marrom',
      rango: 'Professor/a de 2º Grau 🍂',
      simbolismo: 'Transición a la Tierra 🗺️',
      descripcion: 'Grado avanzado de Profesor que lidera clases complejas, profundiza en la teoría histórica y domina el canto lírico.',
      colores: [Color(0xFF8E24AA), Color(0xFF795548)],
      esMixta: true,
    ),
    CordaFIU(
      index: 13,
      nombre: 'Marrom',
      rango: 'Contra Mestre/a 🍂',
      simbolismo: 'La Tierra Firme 🌍',
      descripcion: 'Es cuando el capoeirista echa sus raíces más fuertes en la tierra donde todo nace y prospera. Comienza a cosechar todo lo cultivado en su trayectoria. Transmite madurez, conciencia y gran responsabilidad.',
      colores: [Color(0xFF4E342E), Color(0xFF795548), Color(0xFF4E342E)],
      esMixta: false,
    ),
    CordaFIU(
      index: 14,
      nombre: 'Marrom e Preto',
      rango: 'Contra Mestre 2º Grau 🕶️',
      simbolismo: 'Transición a los Creadores 🛡️',
      descripcion: 'Fase previa a la consagración de Mestre. El Contra Mestre demuestra total dominio de la roda y resguarda la doctrina del grupo.',
      colores: [Color(0xFF795548), Color(0xFF212121)],
      esMixta: true,
    ),
    CordaFIU(
      index: 15,
      nombre: 'Preta',
      rango: 'Mestre/a de Capoeira 🕶️',
      simbolismo: 'Los Minerales y los Creadores Negros ✊🏾',
      descripcion: 'Simboliza los minerales y rinde tributo a los negros esclavizados creadores de la Capoeira. Representa a quien superó incontables batallas y dolores con sabiduría. Transmite absoluto respeto, autoridad y madurez.',
      colores: [Color(0xFF000000), Color(0xFF424242), Color(0xFF000000)],
      esMixta: false,
    ),
    CordaFIU(
      index: 16,
      nombre: 'Preto e Branco',
      rango: 'Mestre de 2º Grau 🕯️',
      simbolismo: 'Transición a la Luz ⚖️',
      descripcion: 'Mestre consolidado que instruye a otros instructores y guías. Representa la sabiduría viva del linaje de FIU.',
      colores: [Color(0xFF212121), Color(0xFFFFFFFF)],
      esMixta: true,
    ),
    CordaFIU(
      index: 17,
      nombre: 'Branca',
      rango: 'Grão Mestre / Patriarca 🏳️',
      simbolismo: 'La Luz Absoluta 🕯️',
      descripcion: 'Es la última etapa y transformación de todos los caminos. Es la mezcla de todas las colores que da el blanco, el símbolo del conocimiento supremo. Transmite paz, calma, sabiduría profunda y equilibrio absoluto con el mundo.',
      colores: [Color(0xFFECEFF1), Color(0xFFFFFFFF), Color(0xFFECEFF1)],
      esMixta: false,
    ),
  ];
}
