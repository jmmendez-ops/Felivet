import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../screens/splash_screen.dart';

class FeliVetApp extends StatelessWidget {
  const FeliVetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FeliVet Insight',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: Colors.deepPurple,
            primaryColor: Colors.deepPurple,
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.grey[50],
            cardColor: Colors.white,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.deepPurple,
            primaryColor: Colors.deepPurple,
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
