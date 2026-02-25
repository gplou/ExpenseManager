import '../domain/task_model.dart';

abstract interface class TasksRepositoryContract {
  /// Obtiene todas las tareas del usuario actual.
  Future<List<TaskModel>> getTasks();

  /// Obtiene una tarea por su ID.
  Future<TaskModel> getTaskById(String id);

  /// Crea una nueva tarea.
  Future<TaskModel> createTask(TaskModel task);

  /// Actualiza una tarea existente.
  Future<TaskModel> updateTask(TaskModel task);

  /// Elimina una tarea.
  Future<void> deleteTask(String id);

  /// Cambia el estado de una tarea.
  Future<TaskModel> toggleTaskStatus(String id);
}
