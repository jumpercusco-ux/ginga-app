import 'package:flutter/material.dart';

Widget buildPlatformEmbedView({
  required String viewId,
  required String embedUrl,
}) {
  return const Center(
    child: Text(
      'Reproducción incrustada solo disponible en navegador Web',
      style: TextStyle(color: Colors.white70),
    ),
  );
}
