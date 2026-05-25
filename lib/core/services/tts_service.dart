import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  String _currentSpeakingText = '';

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Configuraciones del narrador en español de forma predeterminada
      await _flutterTts.setLanguage("es-ES");
      await _flutterTts.setSpeechRate(0.48); // Velocidad moderada para clara enseñanza
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setCompletionHandler(() {
        _currentSpeakingText = '';
      });
      _flutterTts.setErrorHandler((msg) {
        debugPrint('Error en narrador de voz TTS: $msg');
        _currentSpeakingText = '';
      });
      
      _initialized = true;
    } catch (e) {
      debugPrint('No se pudo inicializar servicio TTS: $e');
    }
  }

  /// Lee en voz alta el texto indicado. Si ya se estaba leyendo el mismo texto, lo detiene.
  Future<void> speak(String text) async {
    await init();
    try {
      if (_currentSpeakingText == text) {
        // Si el usuario toca de nuevo el mismo botón, actúa como toggle y lo apaga
        await stop();
      } else {
        await _flutterTts.stop();
        if (text.isNotEmpty) {
          _currentSpeakingText = text;
          await _flutterTts.speak(text);
        }
      }
    } catch (e) {
      debugPrint('Error al intentar reproducir TTS: $e');
    }
  }

  /// Detiene cualquier reproducción de voz activa
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _currentSpeakingText = '';
    } catch (e) {
      debugPrint('Error al detener TTS: $e');
    }
  }

  /// Retorna si el motor está hablando actualmente el texto provisto
  bool isSpeaking(String text) {
    return _currentSpeakingText == text;
  }
}
