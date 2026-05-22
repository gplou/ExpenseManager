import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

/// Creates a [ProviderContainer] with the given [overrides] and registers
/// `addTearDown(container.dispose)` automatically so individual tests
/// don't have to remember.
///
/// ```dart
/// final container = makeContainer([
///   chatRepositoryProvider.overrideWith((ref) => mockRepo),
/// ]);
/// expect(container.read(chatMessagesProvider), isEmpty);
/// ```
ProviderContainer makeContainer([List<Override> overrides = const []]) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

/// Reads [provider] from a fresh container with [overrides]. Disposes
/// the container after the current test ends.
T readOnce<T>(
  ProviderListenable<T> provider, {
  List<Override> overrides = const [],
}) {
  final container = makeContainer(overrides);
  return container.read(provider);
}
