import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import 'admin_employees_screen.dart';
import 'admin_home_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_workplaces_screen.dart';

/// Bottom-navigation shell for admins/super admins: Home, Employees,
/// Workplaces, Profile. Each tab is a self-contained screen (own
/// Scaffold/AppBar); this widget only owns which one is showing.
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
      const AdminEmployeesScreen(),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Employees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city_outlined),
            activeIcon: Icon(Icons.location_city),
            label: 'Workplaces',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
