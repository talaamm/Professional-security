import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/error_banner.dart';

/// Employees sign in with an internal Employee ID + password (not a real
/// email address), so there is no automated inbox to send a reset link to.
/// Instead this form sends an admin a request_password_reset() request
/// (see db_files/phase7-password-reset.sql) with the employee's ID and an
/// optional message; an admin resets the password to the fixed temporary
/// password "123456" from the Employees tab.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _messageController = TextEditingController();
  final _authService = AuthService();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _authService.requestPasswordReset(
        employeeId: _employeeIdController.text,
        message: _messageController.text,
      );
      if (!mounted) return;
      _employeeIdController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your request has been sent to the admins.'),
      ));
    } on AuthServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showAlreadySubmittedInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Already submitted a request?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Once an administrator resets your password and processes your request, '
          'you can log in with the temporary password "123456". We recommend '
          'changing it from your Profile as soon as you log in.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Account Recovery')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                  'Enter your Employee ID and let an administrator know. They will reset '
                  'your password and let you know when it is ready.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'EMPLOYEE ID',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _employeeIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 034829551',
                    prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Employee ID is required';
                    if (!RegExp(r'^\d{9}$').hasMatch(v)) {
                      return 'Employee ID must be exactly 9 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'MESSAGE TO THE ADMIN (OPTIONAL)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  maxLength: 200,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. I forgot my password, please reset it',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('SUBMIT REQUEST'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _showAlreadySubmittedInfo,
                  child: const Text('Already submitted a request?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
