import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  Color _priorityColor(TaskPriority priority) => switch (priority) {
        TaskPriority.high => AppColors.priorityHigh,
        TaskPriority.medium => AppColors.priorityMedium,
        TaskPriority.low => AppColors.priorityLow,
      };

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted;
    final priorityColor = _priorityColor(task.priority);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Checkbox de completado
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppColors.success
                          : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? AppColors.success
                            : context.colors.onSurface.withValues(alpha:0.3),
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const Gap(12),
                // Indicador de prioridad
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Gap(12),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: context.textTheme.titleSmall?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? context.colors.onSurface.withValues(alpha:0.4)
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.description != null) ...[
                        const Gap(4),
                        Text(
                          task.description!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurface.withValues(alpha:0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (task.dueDate != null) ...[
                        const Gap(6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: task.isOverdue
                                  ? AppColors.error
                                  : context.colors.onSurface.withValues(alpha:0.4),
                            ),
                            const Gap(4),
                            Text(
                              task.dueDate!.relativeDateL10n(
                                  AppLocalizations.of(context)),
                              style: context.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: task.isOverdue
                                    ? AppColors.error
                                    : context.colors.onSurface.withValues(alpha:0.4),
                                fontWeight: task.isOverdue
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.colors.onSurface.withValues(alpha:0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
