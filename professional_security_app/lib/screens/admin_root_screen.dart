import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../services/app_strings.dart';
import 'admin_employees_screen.dart';
import 'admin_home_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_workplaces_screen.dart';
import 'history_screen.dart';

/// Bottom-navigation shell for admins/super admins: Home, My Work
/// Sessions, Employees, Workplaces, Profile. Each tab is a
/// self-contained screen (own Scaffold/AppBar); this widget only owns
/// which one is showing. "My Work Sessions" reuses HistoryScreen as-is
/// (see db_files/phase7-admin-self-sessions-and-super-admin.sql) -
/// it already scopes to the signed-in user's own employee_id and
/// works unchanged for an admin/super_admin profile.
class AdminRootScreen extends StatefulWidget {
  final Profile profile;

  const AdminRootScreen({super.key, required this.profile});

  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminHomeScreen(profile: widget.profile),
      HistoryScreen(profile: widget.profile),
      AdminEmployeesScreen(profile: widget.profile),
      AdminWorkplacesScreen(profile: widget.profile),
      AdminProfileScreen(profile: widget.profile),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: AppStrings.t('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: AppStrings.t('nav_my_work_sessions'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            activeIcon: const Icon(Icons.people),
            label: AppStrings.t('nav_employees'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.location_city_outlined),
            activeIcon: const Icon(Icons.location_city),
            label: AppStrings.t('nav_workplaces'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: AppStrings.t('nav_profile'),
          ),
        ],
      ),
    );
  }
}
