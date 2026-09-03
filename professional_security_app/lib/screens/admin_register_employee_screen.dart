import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../services/admin_service.dart';
import '../services/app_strings.dart';
import '../widgets/error_banner.dart';

/// Employees tab -> "Register New Employee". Admin/super_admin enters the
/// new employee's name and ID number; the account is created server-side
/// with a fixed default password ("123456") the employee changes after
/// their first login - see db_files/phase7-admin-create-employee.sql.
class AdminRegisterEmployeeScreen extends StatefulWidget {
  const AdminRegisterEmployeeScreen({super.key});

  @override
  State<AdminRegisterEmployeeScreen> createState() => _AdminRegisterEmployeeScreenState();
}

class _AdminRegisterEmployeeScreenState extends State<AdminRegisterEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _adminService = AdminService();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final fullName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();

    try {
      await _adminService.createEmployee(
        employeeId: _employeeIdController.text.trim(),
        fullName: fullName,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('admin_register_employee_success'))),
      );
    } on AdminServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.t('common_something_wrong'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppStrings.t('admin_register_employee_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: const Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 28),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t('admin_register_employee_heading'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.t('admin_register_employee_subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.t('admin_register_employee_note'),
                          style: const TextStyle(color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(labelText: AppStrings.t('register_first_name')),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? AppStrings.t('register_required') : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(labelText: AppStrings.t('register_last_name')),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? AppStrings.t('register_required') : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _employeeIdController,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  onFieldSubmitted: (_) => _submit(),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: AppStrings.t('register_employee_id_label'),
                    hintText: AppStrings.t('register_employee_id_hint'),
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return AppStrings.t('login_employee_id_required');
                    if (!RegExp(r'^\d{9}$').hasMatch(value)) {
                      return AppStrings.t('login_employee_id_invalid');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(AppStrings.t('admin_register_employee_button')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
