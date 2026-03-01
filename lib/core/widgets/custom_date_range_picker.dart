import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shows a custom date-range picker with:
///   - Left/right arrows to move between months
///   - Tapping the header label switches to month-grid view
///   - In month-grid, left/right arrows change the year (back to 2025, etc.)
Future<DateTimeRange?> showCustomDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _CustomDateRangePickerDialog(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateRange,
    ),
  );
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _CustomDateRangePickerDialog extends StatefulWidget {
  const _CustomDateRangePickerDialog({
    required this.firstDate,
    required this.lastDate,
    this.initialDateRange,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialDateRange;

  @override
  State<_CustomDateRangePickerDialog> createState() =>
      _CustomDateRangePickerDialogState();
}

enum _PickerMode { calendar, monthGrid }

class _CustomDateRangePickerDialogState
    extends State<_CustomDateRangePickerDialog> {
  late DateTime _displayedMonth;
  DateTime? _start;
  DateTime? _end;
  _PickerMode _mode = _PickerMode.calendar;
  late int _monthGridYear;

  @override
  void initState() {
    super.initState();
    final init = widget.initialDateRange;
    if (init != null) {
      _start = init.start;
      _end = init.end;
      _displayedMonth = DateTime(init.start.year, init.start.month);
    } else {
      final now = DateTime.now();
      _displayedMonth = DateTime(now.year, now.month);
    }
    _monthGridYear = _displayedMonth.year;
  }

  // ── Day helpers ─────────────────────────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isStart(DateTime d) => _start != null && _isSameDay(d, _start!);
  bool _isEnd(DateTime d) => _end != null && _isSameDay(d, _end!);
  bool _isInRange(DateTime d) =>
      _start != null &&
      _end != null &&
      d.isAfter(_start!) &&
      d.isBefore(_end!);

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else {
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
      }
    });
  }

  // ── Month navigation ────────────────────────────────────────────────────────

  bool get _canGoPrevMonth {
    final prev = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    return !prev.isBefore(
        DateTime(widget.firstDate.year, widget.firstDate.month));
  }

  bool get _canGoNextMonth {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    return !next
        .isAfter(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  void _prevMonth() => setState(() {
        _displayedMonth =
            DateTime(_displayedMonth.year, _displayedMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _displayedMonth =
            DateTime(_displayedMonth.year, _displayedMonth.month + 1);
      });

  // ── Year navigation (month-grid mode) ──────────────────────────────────────

  bool get _canGoPrevYear => _monthGridYear > widget.firstDate.year;
  bool get _canGoNextYear => _monthGridYear < widget.lastDate.year;

  void _prevYear() => setState(() => _monthGridYear--);
  void _nextYear() => setState(() => _monthGridYear++);

  void _onMonthSelected(int month) => setState(() {
        _displayedMonth = DateTime(_monthGridYear, month);
        _mode = _PickerMode.calendar;
      });

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _mode == _PickerMode.calendar
              ? [
                  _CalendarHeader(
                    displayedMonth: _displayedMonth,
                    canGoPrev: _canGoPrevMonth,
                    canGoNext: _canGoNextMonth,
                    onPrev: _prevMonth,
                    onNext: _nextMonth,
                    onHeaderTap: () => setState(() {
                      _monthGridYear = _displayedMonth.year;
                      _mode = _PickerMode.monthGrid;
                    }),
                  ),
                  const SizedBox(height: 8),
                  _WeekdayRow(),
                  const SizedBox(height: 4),
                  _DayGrid(
                    displayedMonth: _displayedMonth,
                    start: _start,
                    end: _end,
                    isStart: _isStart,
                    isEnd: _isEnd,
                    isInRange: _isInRange,
                    onDayTap: _onDayTap,
                  ),
                  const SizedBox(height: 12),
                  _CalendarActions(
                    canConfirm: _start != null && _end != null,
                    onCancel: () => Navigator.of(context).pop(),
                    onConfirm: () => Navigator.of(context)
                        .pop(DateTimeRange(start: _start!, end: _end!)),
                  ),
                ]
              : [
                  _MonthGridHeader(
                    year: _monthGridYear,
                    canGoPrev: _canGoPrevYear,
                    canGoNext: _canGoNextYear,
                    onPrev: _prevYear,
                    onNext: _nextYear,
                  ),
                  const SizedBox(height: 12),
                  _MonthGrid(
                    year: _monthGridYear,
                    selectedMonth: _displayedMonth,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    onMonthSelected: _onMonthSelected,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _mode = _PickerMode.calendar),
                      child: const Text('Volver'),
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

// ── Calendar header: ←  Marzo 2026  → ────────────────────────────────────────

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.displayedMonth,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onHeaderTap,
  });

  final DateTime displayedMonth;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final label = _capitalize(
      DateFormat('MMMM yyyy', 'es').format(displayedMonth),
    );
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: canGoPrev ? onPrev : null,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onHeaderTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}

// ── Weekday labels ────────────────────────────────────────────────────────────

class _WeekdayRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Row(
      children: labels
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── Day grid ──────────────────────────────────────────────────────────────────

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.displayedMonth,
    required this.start,
    required this.end,
    required this.isStart,
    required this.isEnd,
    required this.isInRange,
    required this.onDayTap,
  });

  final DateTime displayedMonth;
  final DateTime? start;
  final DateTime? end;
  final bool Function(DateTime) isStart;
  final bool Function(DateTime) isEnd;
  final bool Function(DateTime) isInRange;
  final void Function(DateTime) onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final offset = firstDay.weekday - 1; // Monday = 0
    final rows = ((offset + daysInMonth) / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final n = row * 7 + col - offset + 1;
            if (n < 1 || n > daysInMonth) {
              return const Expanded(child: SizedBox(height: 36));
            }
            final day =
                DateTime(displayedMonth.year, displayedMonth.month, n);
            return Expanded(
              child: _DayCell(
                day: day,
                isStart: isStart(day),
                isEnd: isEnd(day),
                inRange: isInRange(day),
                hasEnd: end != null,
                onTap: () => onDayTap(day),
              ),
            );
          }),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isStart,
    required this.isEnd,
    required this.inRange,
    required this.hasEnd,
    required this.onTap,
  });

  final DateTime day;
  final bool isStart;
  final bool isEnd;
  final bool inRange;
  final bool hasEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Color? bg;
    Color? fg;
    BorderRadius radius = BorderRadius.circular(18);

    if (isStart || isEnd) {
      bg = colors.primary;
      fg = colors.onPrimary;
      if (isStart && hasEnd && !isEnd) {
        radius = const BorderRadius.horizontal(left: Radius.circular(18));
      } else if (isEnd && !isStart) {
        radius = const BorderRadius.horizontal(right: Radius.circular(18));
      }
    } else if (inRange) {
      bg = colors.primary.withValues(alpha: 0.15);
      radius = BorderRadius.zero;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight:
                    isStart || isEnd ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

// ── Calendar actions ──────────────────────────────────────────────────────────

class _CalendarActions extends StatelessWidget {
  const _CalendarActions({
    required this.canConfirm,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool canConfirm;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: canConfirm ? onConfirm : null,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

// ── Month-grid header: ←  2026  → ────────────────────────────────────────────

class _MonthGridHeader extends StatelessWidget {
  const _MonthGridHeader({
    required this.year,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: canGoPrev ? onPrev : null,
        ),
        Expanded(
          child: Center(
            child: Text(
              '$year',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}

// ── Month grid ────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.selectedMonth,
    required this.firstDate,
    required this.lastDate,
    required this.onMonthSelected,
  });

  final int year;
  final DateTime selectedMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final void Function(int month) onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, i) {
        final month = i + 1;
        final monthDate = DateTime(year, month);
        final isSelected =
            monthDate.year == selectedMonth.year &&
            monthDate.month == selectedMonth.month;
        final isDisabled =
            monthDate.isAfter(DateTime(now.year, now.month)) ||
            monthDate.isBefore(
                DateTime(firstDate.year, firstDate.month));

        final label = _capitalize(
          DateFormat('MMM', 'es').format(DateTime(2000, month)),
        );

        return GestureDetector(
          onTap: isDisabled ? null : () => onMonthSelected(month),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colors.primary : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.outline.withValues(alpha: 0.3),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDisabled
                        ? colors.onSurface.withValues(alpha: 0.3)
                        : isSelected
                            ? colors.onPrimary
                            : null,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ),
        );
      },
    );
  }
}

// ── Utils ─────────────────────────────────────────────────────────────────────

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
