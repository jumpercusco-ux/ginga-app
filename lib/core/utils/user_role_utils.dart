/// Utilidades centralizadas de normalización y verificación de roles en GINGA (`PED-06A`).
/// Resuelve la inconsistencia histórica entre `'admin'` y `'administrador'`.
class UserRoleUtils {
  const UserRoleUtils._();

  static String normalizeRole(dynamic raw) {
    final norm = (raw ?? '').toString().trim().toLowerCase();
    if (norm == 'administrador') return 'admin';
    if (norm.isEmpty) return 'alumno';
    return norm;
  }

  static bool isAdmin(dynamic raw) => normalizeRole(raw) == 'admin';

  static bool isStaff(dynamic raw) {
    final norm = normalizeRole(raw);
    return norm == 'profesor' || norm == 'instructor' || norm == 'admin';
  }
}
