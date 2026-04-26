import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emite `true` cuando hay al menos una interfaz de red activa.
/// El valor por defecto mientras no se ha emitido ninguno es `true`
/// (optimista: asumimos conexión hasta que se pruebe lo contrario).
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

/// Bool sincrónico — se usa en repositories para decidir si escribir en
/// la nube o encolar para más tarde. Por defecto `true` (optimista).
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).value ?? true;
});
