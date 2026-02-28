import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../../core/config/router.dart';
import '../../../../core/utils/extensions.dart';
import '../providers/tasks_provider.dart';
import '../widgets/task_card.dart';

class TasksListScreen extends ConsumerStatefulWidget {
  const TasksListScreen({super.key});

  @override
  ConsumerState<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends ConsumerState<TasksListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(tasksNotifierProvider.notifier).loadTasks(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () {
              // TODO: Implementar filtros
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoutes.tasks}/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
      body: tasksState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.read(tasksNotifierProvider.notifier).loadTasks(),
        ),
        data: (tasks) {
          if (tasks.isEmpty) return const _EmptyView();

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(tasksNotifierProvider.notifier).loadTasks(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Gap(8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskCard(
                  task: task,
                  onToggle: () =>
                      ref.read(tasksNotifierProvider.notifier).toggleTask(task.id),
                  onTap: () => context.push(
                    AppRoutes.taskDetail.replaceAll(':id', task.id),
                  ),
                  onDelete: () =>
                      ref.read(tasksNotifierProvider.notifier).deleteTask(task.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 64,
            color: context.colors.onSurface.withValues(alpha:0.3),
          ),
          const Gap(16),
          Text(
            '¡Sin tareas pendientes!',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha:0.5),
            ),
          ),
          const Gap(8),
          Text(
            'Pulsa + para crear tu primera tarea',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha:0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            const Gap(16),
            Text(message, textAlign: TextAlign.center),
            const Gap(24),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
