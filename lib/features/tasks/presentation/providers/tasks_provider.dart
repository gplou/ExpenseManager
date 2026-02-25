import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/failures.dart';
import '../../data/tasks_repository.dart';
import '../../domain/task_model.dart';

part 'tasks_provider.g.dart';

/// Lista de tareas del usuario actual.
@riverpod
Future<List<TaskModel>> tasksList(TasksListRef ref) {
  return ref.watch(tasksRepositoryProvider).getTasks();
}

/// Notifier para operaciones CRUD de tareas.
@riverpod
class TasksNotifier extends _$TasksNotifier {
  @override
  AsyncValue<List<TaskModel>> build() {
    return const AsyncValue.loading();
  }

  Future<void> loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final tasks = await ref.read(tasksRepositoryProvider).getTasks();
      state = AsyncValue.data(tasks);
    } on AppFailure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> createTask(TaskModel task) async {
    try {
      final newTask = await ref.read(tasksRepositoryProvider).createTask(task);
      state = state.whenData((tasks) => [newTask, ...tasks]);
      return true;
    } on AppFailure {
      return false;
    }
  }

  Future<bool> updateTask(TaskModel task) async {
    try {
      final updated = await ref.read(tasksRepositoryProvider).updateTask(task);
      state = state.whenData((tasks) =>
          tasks.map((t) => t.id == updated.id ? updated : t).toList());
      return true;
    } on AppFailure {
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      await ref.read(tasksRepositoryProvider).deleteTask(id);
      state = state.whenData((tasks) => tasks.where((t) => t.id != id).toList());
      return true;
    } on AppFailure {
      return false;
    }
  }

  Future<void> toggleTask(String id) async {
    try {
      final updated =
          await ref.read(tasksRepositoryProvider).toggleTaskStatus(id);
      state = state.whenData((tasks) =>
          tasks.map((t) => t.id == updated.id ? updated : t).toList());
    } on AppFailure {
      // Silently fail — la UI puede mostrar un snackbar si quiere
    }
  }
}
