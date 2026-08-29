import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Employees sign in with an internal Employee ID + password (not a real
/// email address), so there is no automated inbox to send a reset link to.
/// Password resets are handled by an administrator (Phase 7: "Reset
/// credentials"). This screen matches the UI design and points the user
/// to that process instead of a non-functional email flow.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _employeeIdController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _employeeIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_employeeIdController.text.trim().isEmpty) return;
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Account Recovery')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Reset Password',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your Employee ID below. Password resets for this app are handled by your administrator.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const Text(
                'EMPLOYEE ID',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _employeeIdController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. 10428955',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'If you have lost access to your account, contact your system administrator to reset your password.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_submitted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Please contact your administrator with Employee ID "${_employeeIdController.text.trim()}" to reset your password.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
              OutlinedButton(
                onPressed: _submit,
                child: const Text('Request Reset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
