import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Placeholder for the Reports tab - a later phase per project-phases.md.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(
        child: Text('Coming soon', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
