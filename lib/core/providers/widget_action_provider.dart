import 'package:flutter_riverpod/legacy.dart';

/// Almacena la acción pendiente lanzada desde un widget de pantalla de inicio.
/// Valores posibles: 'voice', 'add', null (sin acción)
final pendingWidgetActionProvider = StateProvider<String?>((ref) => null);
