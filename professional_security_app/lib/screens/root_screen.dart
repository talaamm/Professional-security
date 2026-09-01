import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/profile.dart';
import '../services/app_strings.dart';
import 'employee_profile_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// Bottom-navigation shell for the employee app: Home, History, Profile.
/// Each tab is a self-contained screen (own Scaffold/AppBar); this widget
/// only owns which one is showing.
class RootScreen extends StatefulWidget {
  final Profile profile;

  const RootScreen({super.key, required this.profile});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(profile: widget.profile),
      HistoryScreen(profile: widget.profile),
      EmployeeProfileScreen(profile: widget.profile),
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
            label: AppStrings.t('nav_history'),
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
