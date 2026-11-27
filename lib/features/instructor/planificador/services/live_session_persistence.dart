import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_session_models.dart';

enum LiveSessionSyncStatus {
  synced('synced', 'Sincronizado'),
  pendingOffline('pending_offline', 'Pendiente (respaldo local)'),
  error('error', 'Error de sincronización');

  final String id;
  final String label;
  const LiveSessionSyncStatus(this.id, this.label);
}

/// Persistencia desacoplada para recuperar una sesión en vivo interrumpida o entre dispositivos.
abstract class LiveSessionStorage {
  Future<void> saveActiveSession(LiveSessionState state);
  Future<LiveSessionState?> loadActiveSession();
  Future<void> clearActiveSession();
}

/// Persistencia multidispositivo en Firestore (`instructor_sesiones_activas`) + respaldo local automático.
/// Nunca promete sincronización mientras está sin conexión: expone [lastSyncStatus] y [lastSyncError].
class FirestoreLiveSessionStorage implements LiveSessionStorage {
  final FirebaseFirestore _firestore;
  final String instructorUid;
  final String? deviceId;
  final LiveSessionStorage _localFallback;
  LiveSessionSyncStatus _lastSyncStatus = LiveSessionSyncStatus.synced;
  String? _lastSyncError;

  FirestoreLiveSessionStorage({
    required this.instructorUid,
    FirebaseFirestore? firestore,
    this.deviceId,
    LiveSessionStorage? localFallback,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _localFallback =
            localFallback ?? const SharedPreferencesLiveSessionStorage();

  String get docId => 'active_${instructorUid.trim()}';
  LiveSessionSyncStatus get lastSyncStatus => _lastSyncStatus;
  String? get lastSyncError => _lastSyncError;

  @override
  Future<void> saveActiveSession(LiveSessionState state) async {
    final now = DateTime.now();
    final updatedState = state.copyWithSyncMeta(
      revision: state.revision + 1,
      deviceId: deviceId ?? state.deviceId,
      updatedAt: now,
    );
    await _localFallback.saveActiveSession(updatedState);
    try {
      await _firestore
          .collection('instructor_sesiones_activas')
          .doc(docId)
          .set(
            updatedState.toFirestoreMap(
              instructorUid: instructorUid,
              deviceId: deviceId,
              now: now,
            ),
            SetOptions(merge: true),
          );
      _lastSyncStatus = LiveSessionSyncStatus.synced;
      _lastSyncError = null;
    } catch (e) {
      _lastSyncStatus = LiveSessionSyncStatus.pendingOffline;
      _lastSyncError = e.toString();
    }
  }

  @override
  Future<LiveSessionState?> loadActiveSession() async {
    final local = await _localFallback.loadActiveSession();
    try {
      final doc = await _firestore
          .collection('instructor_sesiones_activas')
          .doc(docId)
          .get();
      _lastSyncStatus = LiveSessionSyncStatus.synced;
      _lastSyncError = null;
      if (!doc.exists || doc.data() == null) {
        return local;
      }
      final remote = LiveSessionState.fromJsonMap(doc.data()!);
      if (remote.exercises.isEmpty) return local;
      if (local == null) {
        await _localFallback.saveActiveSession(remote);
        return remote;
      }
      final remoteTs = remote.updatedAt ?? remote.lastResumedAt ?? remote.startedAt;
      final localTs = local.updatedAt ?? local.lastResumedAt ?? local.startedAt;
      if (remote.sessionId == local.sessionId &&
          localTs.isAfter(remoteTs) &&
          local.revision > remote.revision) {
        return local;
      }
      await _localFallback.saveActiveSession(remote);
      return remote;
    } catch (e) {
      _lastSyncStatus = LiveSessionSyncStatus.pendingOffline;
      _lastSyncError = e.toString();
      return local;
    }
  }

  @override
  Future<void> clearActiveSession() async {
    await _localFallback.clearActiveSession();
    try {
      await _firestore
          .collection('instructor_sesiones_activas')
          .doc(docId)
          .delete();
      _lastSyncStatus = LiveSessionSyncStatus.synced;
      _lastSyncError = null;
    } catch (e) {
      _lastSyncStatus = LiveSessionSyncStatus.error;
      _lastSyncError = e.toString();
    }
  }
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
