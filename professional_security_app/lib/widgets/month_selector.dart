import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/app_strings.dart';

/// Clamps [month] to [minMonth, the current month] - shared by every
/// screen with a MonthSelector so "can't go past this range" always means
/// the same thing.
DateTime clampToMonthRange(DateTime month, DateTime minMonth) {
  final maxMonth = DateTime(DateTime.now().year, DateTime.now().month);
  if (month.isBefore(minMonth)) return minMonth;
  if (month.isAfter(maxMonth)) return maxMonth;
  return month;
}

/// Prev/next month picker clamped to [minMonth, the current month] - shared
/// by every admin screen that reports/lists a chosen month's data (employee
/// detail, workplace detail).
class MonthSelector extends StatelessWidget {
  final DateTime month;
  final DateTime minMonth;
  final ValueChanged<int>? onChange;

  const MonthSelector({super.key, required this.month, required this.minMonth, this.onChange});

  bool get _isMinMonth => month.year == minMonth.year && month.month == minMonth.month;

  bool get _isMaxMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final monthNames = AppStrings.list('months_full');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: (onChange == null || _isMinMonth) ? null : () => onChange!(-1),
        ),
        Text(
          '${monthNames[month.month - 1]} ${month.year}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          onPressed: (onChange == null || _isMaxMonth) ? null : () => onChange!(1),
        ),
      ],
    );
  }
}
