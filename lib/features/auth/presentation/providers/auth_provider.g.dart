// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Estado del stream de autenticación.
/// Escucha cambios en tiempo real (login, logout, token refresh).

@ProviderFor(authState)
const authStateProvider = AuthStateProvider._();

/// Estado del stream de autenticación.
/// Escucha cambios en tiempo real (login, logout, token refresh).

final class AuthStateProvider extends $FunctionalProvider<
        AsyncValue<UserModel?>, UserModel?, Stream<UserModel?>>
    with $FutureModifier<UserModel?>, $StreamProvider<UserModel?> {
  /// Estado del stream de autenticación.
  /// Escucha cambios en tiempo real (login, logout, token refresh).
  const AuthStateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authStateHash();

  @$internal
  @override
  $StreamProviderElement<UserModel?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<UserModel?> create(Ref ref) {
    return authState(ref);
  }
}

String _$authStateHash() => r'4c480f6fcb624566b9e45dc082bd14daa667c5b8';

/// Usuario actual (sincrónico, puede ser null).
/// Escucha [authStateProvider] para reconstruirse en cada cambio de auth
/// (login, logout, token refresh, restauración de sesión).

@ProviderFor(currentUser)
const currentUserProvider = CurrentUserProvider._();

/// Usuario actual (sincrónico, puede ser null).
/// Escucha [authStateProvider] para reconstruirse en cada cambio de auth
/// (login, logout, token refresh, restauración de sesión).

final class CurrentUserProvider
    extends $FunctionalProvider<UserModel?, UserModel?, UserModel?>
    with $Provider<UserModel?> {
  /// Usuario actual (sincrónico, puede ser null).
  /// Escucha [authStateProvider] para reconstruirse en cada cambio de auth
  /// (login, logout, token refresh, restauración de sesión).
  const CurrentUserProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentUserProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $ProviderElement<UserModel?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserModel? create(Ref ref) {
    return currentUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserModel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserModel?>(value),
    );
  }
}

String _$currentUserHash() => r'99d2d942ccf291bf7a1afeddf1251659e99bf6d2';

/// Devuelve true si el usuario inició sesión con email y contraseña.
/// Los usuarios de Google/Apple tienen provider distinto a 'email'.

@ProviderFor(isEmailPasswordUser)
const isEmailPasswordUserProvider = IsEmailPasswordUserProvider._();

/// Devuelve true si el usuario inició sesión con email y contraseña.
/// Los usuarios de Google/Apple tienen provider distinto a 'email'.

final class IsEmailPasswordUserProvider
    extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  /// Devuelve true si el usuario inició sesión con email y contraseña.
  /// Los usuarios de Google/Apple tienen provider distinto a 'email'.
  const IsEmailPasswordUserProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isEmailPasswordUserProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isEmailPasswordUserHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isEmailPasswordUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isEmailPasswordUserHash() =>
    r'28bbf8ae3bde1439a48321358b76138fe7ffa5c5';

@ProviderFor(AuthNotifier)
const authProvider = AuthNotifierProvider._();

final class AuthNotifierProvider
    extends $NotifierProvider<AuthNotifier, AuthAction> {
  const AuthNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authNotifierHash();

  @$internal
  @override
  AuthNotifier create() => AuthNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthAction value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthAction>(value),
    );
  }
}

String _$authNotifierHash() => r'b399d7d3681c49f44f7a267c7c45a995bc8dc2a7';

abstract class _$AuthNotifier extends $Notifier<AuthAction> {
  AuthAction build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AuthAction, AuthAction>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AuthAction, AuthAction>, AuthAction, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
