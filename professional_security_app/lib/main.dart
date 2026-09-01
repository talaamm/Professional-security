import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'config/theme.dart';
import 'services/app_strings.dart';
import 'widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  await AppStrings.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app - including text direction - the moment the
    // language changes from the Profile tab (AppStrings.setLanguage).
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppStrings.current,
      builder: (context, language, _) {
        return MaterialApp(
          title: 'Professional Security',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          builder: (context, child) => Directionality(
            textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
