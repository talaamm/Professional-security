import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../services/app_strings.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('forgot_password_success_snackbar'))),
      );
    } on AuthServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.t('common_something_wrong'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showAlreadySubmittedInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppStrings.t('forgot_password_info_title'),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          AppStrings.t('forgot_password_info_body'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.t('common_got_it')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppStrings.t('forgot_password_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.t('forgot_password_heading'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.t('forgot_password_subtitle'),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],
                Text(
                  AppStrings.t('forgot_password_employee_id_section'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                  decoration: InputDecoration(
                    hintText: AppStrings.t('login_employee_id_hint'),
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return AppStrings.t('login_employee_id_required');
                    if (!RegExp(r'^\d{9}$').hasMatch(v)) {
                      return AppStrings.t('login_employee_id_invalid');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t('forgot_password_message_section'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  maxLength: 200,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: AppStrings.t('forgot_password_message_hint'),
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
                      : Text(AppStrings.t('forgot_password_submit')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _showAlreadySubmittedInfo,
                  child: Text(AppStrings.t('forgot_password_already_submitted')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
