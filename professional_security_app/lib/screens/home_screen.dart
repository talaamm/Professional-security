import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';

/// Minimal placeholder landing screen. The real employee dashboard
/// (start/finish work, status, history) is built in Phase 3.
class HomeScreen extends StatelessWidget {
  final Profile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${profile.fullName}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Employee ID: ${profile.employeeId}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            Text(
              'Role: ${profile.role.name}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
