import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../../core/models/cuerdas_fiu.dart';
import '../../../core/utils/user_role_utils.dart';

/// Contexto del usuario actual dentro de la Biblioteca unificada.
/// Conserva exactamente las reglas de bloqueo de tutoriales vigentes sin ampliar permisos.
class BibliotecaUserContext {
  final String role;
  final String cordaName;
  final String displayName;

  const BibliotecaUserContext({
    this.role = 'alumno',
    this.cordaName = 'Crua',
    this.displayName = 'Capoeirista',
  });

  bool get isTeacher =>
      role == 'profesor' || role == 'instructor' || role == 'admin';

  /// Regla heredada de `TutorialesScreen`: solo `instructor` y `admin` omiten el candado visual.
  bool get canBypassTutorialLock =>
      role == 'instructor' || role == 'admin';

  CordaFIU get cordaFIU =>
      CuerdasFIU.encontrarCordaFIU(cordaName) ?? CuerdasFIU.lista.first;

  int get adultCordaIndex => cordaFIU.index;

  bool get isBeyondDigitizedV1 => adultCordaIndex > 6;

  /// Evalúa si un tutorial heredado queda bloqueado para el alumno actual.
  /// Si `legacyCordaProd` está vacío (`""`, como en Ginga/Passape/Martelo/Cocorinha + base), es acceso libre.
  bool isTutorialLocked(String legacyCordaProd) {
    if (canBypassTutorialLock) return false;
    final clean = legacyCordaProd.trim();
    if (clean.isEmpty) return false;
    final tutorialCorda =
        CuerdasFIU.encontrarCordaFIU(clean) ?? CuerdasFIU.lista.first;
    return tutorialCorda.index > cordaFIU.index;
  }

  String get roleLabel {
    if (role == 'admin') return 'Administrador · Practicante';
    if (role == 'profesor' || role == 'instructor') {
      return 'Profesor · Practicante';
    }
    return 'Alumno';
  }
}

/// Proveedor seguro de contexto que funciona tanto con Firebase conectado como en modo local/tests.
class BibliotecaUserContextProvider extends StatelessWidget {
  final BibliotecaUserContext? overrideContext;
  final Widget Function(BuildContext context, BibliotecaUserContext userContext)
      builder;

  const BibliotecaUserContextProvider({
    super.key,
    this.overrideContext,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (overrideContext != null) {
      return builder(context, overrideContext!);
    }

    if (Firebase.apps.isEmpty) {
      return builder(context, const BibliotecaUserContext());
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return builder(context, const BibliotecaUserContext());
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        String corda = 'Crua';
        String rol = 'alumno';
        String nombre = 'Capoeirista';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          corda = (data['corda'] ?? 'Crua').toString();
          rol = UserRoleUtils.normalizeRole(data['rol']);
          nombre = (data['nombre'] ?? 'Capoeirista').toString();
        }

        return builder(
          context,
          BibliotecaUserContext(
            role: rol.isEmpty ? 'alumno' : rol,
            cordaName: corda.isEmpty ? 'Crua' : corda,
            displayName: nombre.isEmpty ? 'Capoeirista' : nombre,
          ),
        );
      },
    );
  }
}

/// Cinta visual reutilizable de la graduación FIU (mismo patrón visual de `GraduacionesScreen`).
class CordaRibbonBar extends StatelessWidget {
  final CordaFIU corda;
  final double height;
  final double? width;

  const CordaRibbonBar({
    super.key,
    required this.corda,
    this.height = 10,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(height / 2);
    if (corda.esMixta && corda.colores.length >= 2) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Row(
            children: [
              Expanded(
                child: Container(color: corda.colores[0]),
              ),
              Expanded(
                child: Container(color: corda.colores[1]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: corda.colores,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: corda.nombre == 'Branca'
            ? Border.all(color: Colors.grey.shade300, width: 0.8)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
