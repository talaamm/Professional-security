import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Placeholder for the Profile tab - a later phase per project-phases.md.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(
        child: Text('Coming soon', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
