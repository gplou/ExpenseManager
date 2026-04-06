// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authStateHash() => r'118845239933eed72324b87d15d4944b8c77cf59';

/// Estado del stream de autenticación.
/// Escucha cambios en tiempo real (login, logout, token refresh).
///
/// Copied from [authState].
@ProviderFor(authState)
final authStateProvider = AutoDisposeStreamProvider<UserModel?>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AuthStateRef = AutoDisposeStreamProviderRef<UserModel?>;
String _$currentUserHash() => r'bb41c76db08d3c5c02f00d5457b1c146342e0931';

/// Usuario actual (sincrónico, puede ser null).
/// Escucha [authStateProvider] para reconstruirse en cada cambio de auth
/// (login, logout, token refresh, restauración de sesión).
///
/// Copied from [currentUser].
@ProviderFor(currentUser)
final currentUserProvider = AutoDisposeProvider<UserModel?>.internal(
  currentUser,
  name: r'currentUserProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentUserRef = AutoDisposeProviderRef<UserModel?>;
String _$isEmailPasswordUserHash() =>
    r'846470207f66d5f0b00faa4a51765214d6f9fdd4';

/// Devuelve true si el usuario inició sesión con email y contraseña.
/// Los usuarios de Google/Apple tienen provider distinto a 'email'.
///
/// Copied from [isEmailPasswordUser].
@ProviderFor(isEmailPasswordUser)
final isEmailPasswordUserProvider = AutoDisposeProvider<bool>.internal(
  isEmailPasswordUser,
  name: r'isEmailPasswordUserProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isEmailPasswordUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef IsEmailPasswordUserRef = AutoDisposeProviderRef<bool>;
String _$authNotifierHash() => r'5dca9d0cf7b4b6494b53fd6e6fa81bd2f963a6ff';

/// See also [AuthNotifier].
@ProviderFor(AuthNotifier)
final authNotifierProvider =
    AutoDisposeNotifierProvider<AuthNotifier, AuthAction>.internal(
  AuthNotifier.new,
  name: r'authNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthNotifier = AutoDisposeNotifier<AuthAction>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
