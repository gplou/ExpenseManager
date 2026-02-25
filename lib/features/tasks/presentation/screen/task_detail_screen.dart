import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/utils/extensions.dart';
import '../providers/tasks_provider.dart';
import '../../domain/task_model.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksNotifierProvider);

    final task = tasksState.valueOrNull?.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );

    if (task == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de tarea'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: navegar a edición
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: context.colors.error),
            onPressed: () => _confirmDelete(context, ref, task),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusBadge(status: task.status),
            const Gap(16),
            Text(task.title, style: context.textTheme.headlineSmall),
            if (task.description != null) ...[
              const Gap(12),
              Text(
                task.description!,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colors.onSurface.withValues(alpha:0.7),
                ),
              ),
            ],
            const Gap(24),
            _InfoRow(
              icon: Icons.flag_outlined,
              label: 'Prioridad',
              value: task.priority.name.capitalize,
            ),
            if (task.dueDate != null) ...[
              const Gap(12),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Vencimiento',
                value: task.dueDate!.relativeDate,
                valueColor: task.isOverdue ? context.colors.error : null,
              ),
            ],
            const Gap(12),
            _InfoRow(
              icon: Icons.access_time_outlined,
              label: 'Creada',
              value: task.createdAt.formattedDateTime,
            ),
            const Gap(40),
            ElevatedButton(
              onPressed: () =>
                  ref.read(tasksNotifierProvider.notifier).toggleTask(task.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: task.isCompleted
                    ? context.colors.surfaceContainerHighest
                    : context.colors.primary,
              ),
              child: Text(
                task.isCompleted ? 'Marcar como pendiente' : 'Marcar como completada',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TaskModel task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Estás seguro de que quieres eliminar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(tasksNotifierProvider.notifier).deleteTask(task.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TaskStatus.pending => ('Pendiente', Colors.orange),
      TaskStatus.inProgress => ('En progreso', Colors.blue),
      TaskStatus.completed => ('Completada', Colors.green),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.onSurface.withValues(alpha:0.5)),
        const Gap(8),
        Text(
          '$label: ',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha:0.5),
          ),
        ),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
