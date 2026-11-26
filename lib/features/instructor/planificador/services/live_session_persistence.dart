import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_session_models.dart';

/// Persistencia local desacoplada para recuperar una sesión en vivo interrumpida.
abstract class LiveSessionStorage {
  Future<void> saveActiveSession(LiveSessionState state);
  Future<LiveSessionState?> loadActiveSession();
  Future<void> clearActiveSession();
}

/// Almacenamiento local mediante SharedPreferences (funciona en web, tablet y móvil sin Firestore).
class SharedPreferencesLiveSessionStorage implements LiveSessionStorage {
  static const String storageKey = 'ginga_active_live_session_v2';

  const SharedPreferencesLiveSessionStorage();

  @override
  Future<void> saveActiveSession(LiveSessionState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, state.toJsonString());
    } catch (_) {
      // Tolerante en entornos de prueba sin plataforma de preferencias configurada.
    }
  }

  @override
  Future<LiveSessionState?> loadActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return LiveSessionState.tryFromJsonString(prefs.getString(storageKey));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }
}

/// Implementación en memoria con serialización JSON real para pruebas deterministas.
class InMemoryLiveSessionStorage implements LiveSessionStorage {
  String? _rawJson;

  InMemoryLiveSessionStorage({LiveSessionState? initialSession})
      : _rawJson = initialSession?.toJsonString();

  String? get rawJson => _rawJson;

  @override
  Future<void> saveActiveSession(LiveSessionState state) async {
    _rawJson = state.toJsonString();
  }

  @override
  Future<LiveSessionState?> loadActiveSession() async {
    return LiveSessionState.tryFromJsonString(_rawJson);
  }

  @override
  Future<void> clearActiveSession() async {
    _rawJson = null;
  }
}
