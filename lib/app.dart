import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

import 'theme/app_colors.dart';

class AapkeLawyerApp extends StatelessWidget {
  const AapkeLawyerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aapke Lawyer',
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
