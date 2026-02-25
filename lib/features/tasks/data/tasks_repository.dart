import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/task_model.dart';
import '../domain/tasks_repository_contract.dart';

class TasksRepository implements TasksRepositoryContract {
  final SupabaseClient _client;

  TasksRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<TaskModel>> getTasks() async {
    try {
      final data = await _client
          .from('tasks')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false);

      return data.map((e) => TaskModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw NetworkFailure(e.message);
    } catch (e) {
      throw const UnexpectedFailure();
    }
  }

  @override
  Future<TaskModel> getTaskById(String id) async {
    try {
      final data = await _client
          .from('tasks')
          .select()
          .eq('id', id)
          .eq('user_id', _userId)
          .single();

      return TaskModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw NetworkFailure(e.message);
    }
  }

  @override
  Future<TaskModel> createTask(TaskModel task) async {
    try {
      final data = await _client
          .from('tasks')
          .insert(task.toJson()..['user_id'] = _userId)
          .select()
          .single();

      return TaskModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw NetworkFailure(e.message);
    }
  }

  @override
  Future<TaskModel> updateTask(TaskModel task) async {
    try {
      final data = await _client
          .from('tasks')
          .update({
            ...task.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', task.id)
          .eq('user_id', _userId)
          .select()
          .single();

      return TaskModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw NetworkFailure(e.message);
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      await _client
          .from('tasks')
          .delete()
          .eq('id', id)
          .eq('user_id', _userId);
    } on PostgrestException catch (e) {
      throw NetworkFailure(e.message);
    }
  }

  @override
  Future<TaskModel> toggleTaskStatus(String id) async {
    final task = await getTaskById(id);
    final newStatus = task.isCompleted
        ? TaskStatus.pending
        : TaskStatus.completed;

    return updateTask(task.copyWith(status: newStatus));
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final tasksRepositoryProvider = Provider<TasksRepositoryContract>((ref) {
  return TasksRepository(ref.watch(supabaseClientProvider));
});
