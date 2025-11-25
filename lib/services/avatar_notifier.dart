import 'package:flutter/foundation.dart';

/// Notificador global para refrescar la imagen del avatar
///
/// SettingsScreen lo llamará cuando el usuario cambie su avatar.
/// HomeScreen lo escucha para actualizar automáticamente.
final ValueNotifier<int> avatarNotifier = ValueNotifier(0);

class AvatarNotifier {
  /// Fuerza actualización del avatar incrementando el valor.
  /// Esto obliga a cualquier ValueListenableBuilder a redibujar el avatar.
  static void refresh() {
    avatarNotifier.value++;
  }
}
