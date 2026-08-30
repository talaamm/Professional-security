import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A titled, countable, expandable card used for admin review queues
/// (currently-working employees, unverified sessions, open issue reports).
class DashboardSection extends StatelessWidget {
  final String title;
  final int count;
  final String emptyText;
  final List<Widget> children;

  const DashboardSection({
    super.key,
    required this.title,
    required this.count,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            '$title  ($count)',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          children: [
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(emptyText, style: const TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
