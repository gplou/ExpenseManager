import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../core/config/router.dart';
import '../../core/utils/extensions.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../tasks/presentation/providers/tasks_provider.dart';
import '../tasks/domain/task_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(tasksNotifierProvider.notifier).loadTasks(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final tasksState = ref.watch(tasksNotifierProvider);

    final tasks = tasksState.valueOrNull ?? [];
    final pendingCount = tasks.where((t) => !t.isCompleted).length;
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final overdueCount = tasks.where((t) => t.isOverdue).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, ${user?.name?.split(' ').first ?? 'usuario'} 👋',
              style: context.textTheme.titleLarge,
            ),
            Text(
              DateTime.now().formattedDate,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha:0.5),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Pendientes',
                    count: pendingCount,
                    icon: Icons.pending_actions_outlined,
                    color: Colors.orange,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _StatCard(
                    label: 'Completadas',
                    count: completedCount,
                    icon: Icons.task_alt_outlined,
                    color: Colors.green,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _StatCard(
                    label: 'Vencidas',
                    count: overdueCount,
                    icon: Icons.warning_amber_outlined,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const Gap(28),

            // Acceso rápido
            Text('Acceso rápido', style: context.textTheme.titleMedium),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_task,
                    label: 'Nueva tarea',
                    onTap: () => context.push('${AppRoutes.tasks}/new'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.list_alt_outlined,
                    label: 'Ver tareas',
                    onTap: () => context.push(AppRoutes.tasks),
                  ),
                ),
              ],
            ),
            const Gap(28),

            // Tareas recientes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tareas recientes', style: context.textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.push(AppRoutes.tasks),
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const Gap(8),
            tasksState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(e.toString()),
              data: (tasks) {
                final recent = tasks.take(3).toList();
                if (recent.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No hay tareas todavía',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurface.withValues(alpha:0.4),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: recent
                      .map((task) => _RecentTaskTile(
                            task: task,
                            onTap: () => context.push(
                              AppRoutes.taskDetail.replaceAll(':id', task.id),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const Gap(8),
            Text(
              '$count',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const Gap(2),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha:0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: context.colors.primary),
              const Gap(10),
              Text(label, style: context.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTaskTile extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  const _RecentTaskTile({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        task.isCompleted
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked,
        color: task.isCompleted
            ? Colors.green
            : context.colors.onSurface.withValues(alpha:0.3),
      ),
      title: Text(
        task.title,
        style: context.textTheme.bodyMedium?.copyWith(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          color: task.isCompleted
              ? context.colors.onSurface.withValues(alpha:0.4)
              : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: task.dueDate != null
          ? Text(
              task.dueDate!.relativeDate,
              style: context.textTheme.bodySmall?.copyWith(
                color: task.isOverdue ? Colors.red : null,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
