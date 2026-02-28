// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tasksListHash() => r'83305469ec0e2cb43b298ca4f1aeb2b4838280d8';

/// Lista de tareas del usuario actual.
///
/// Copied from [tasksList].
@ProviderFor(tasksList)
final tasksListProvider = AutoDisposeFutureProvider<List<TaskModel>>.internal(
  tasksList,
  name: r'tasksListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$tasksListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TasksListRef = AutoDisposeFutureProviderRef<List<TaskModel>>;
String _$tasksNotifierHash() => r'c7f8c03c53f72afdddd30735cf3b82e2425cc691';

/// Notifier para operaciones CRUD de tareas.
///
/// Copied from [TasksNotifier].
@ProviderFor(TasksNotifier)
final tasksNotifierProvider = AutoDisposeNotifierProvider<TasksNotifier,
    AsyncValue<List<TaskModel>>>.internal(
  TasksNotifier.new,
  name: r'tasksNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tasksNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TasksNotifier = AutoDisposeNotifier<AsyncValue<List<TaskModel>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
