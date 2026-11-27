import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_app/core/utils/user_role_utils.dart';
import 'package:ginga_app/features/biblioteca/widgets/biblioteca_user_context.dart';

void main() {
  group('PED-06A UserRoleUtils y consistencia de roles', () {
    test('Normaliza administrador hacia admin sin romper profesor/instructor/alumno', () {
      expect(UserRoleUtils.normalizeRole('administrador'), 'admin');
      expect(UserRoleUtils.normalizeRole(' ADMINISTRADOR '), 'admin');
      expect(UserRoleUtils.normalizeRole('admin'), 'admin');
      expect(UserRoleUtils.normalizeRole('profesor'), 'profesor');
      expect(UserRoleUtils.normalizeRole('instructor'), 'instructor');
      expect(UserRoleUtils.normalizeRole('alumno'), 'alumno');
      expect(UserRoleUtils.normalizeRole(null), 'alumno');
      expect(UserRoleUtils.normalizeRole(''), 'alumno');

      expect(UserRoleUtils.isAdmin('administrador'), isTrue);
      expect(UserRoleUtils.isAdmin('admin'), isTrue);
      expect(UserRoleUtils.isAdmin('profesor'), isFalse);

      expect(UserRoleUtils.isStaff('administrador'), isTrue);
      expect(UserRoleUtils.isStaff('admin'), isTrue);
      expect(UserRoleUtils.isStaff('profesor'), isTrue);
      expect(UserRoleUtils.isStaff('instructor'), isTrue);
      expect(UserRoleUtils.isStaff('alumno'), isFalse);
    });

    test('BibliotecaUserContext reconoce rol normalizado administrador', () {
      final ctx = BibliotecaUserContext(
        role: UserRoleUtils.normalizeRole('administrador'),
      );
      expect(ctx.isTeacher, isTrue);
      expect(ctx.canBypassTutorialLock, isTrue);
      expect(ctx.roleLabel, 'Administrador · Practicante');
    });
  });
}
