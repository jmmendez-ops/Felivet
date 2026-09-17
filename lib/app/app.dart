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
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.light,
              surface: const Color(0xFFF5F5F7),
            ),
            primaryColor: const Color(0xFF7C3AED),
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            cardColor: Colors.white,
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.08),
            ),
            appBarTheme: const AppBarTheme(
              toolbarHeight: 52,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Color(0xFFF5F5F7),
              foregroundColor: Color(0xFF17121F),
              centerTitle: false,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                elevation: 2,
                shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.24),
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              height: 68,
              elevation: 0,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFF7C3AED).withValues(alpha: 0.14),
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF9B5CFF),
              brightness: Brightness.dark,
              surface: const Color(0xFF121212),
            ),
            primaryColor: const Color(0xFF9B5CFF),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1E1E),
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.35),
            ),
            appBarTheme: const AppBarTheme(
              toolbarHeight: 52,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Color(0xFF121212),
              foregroundColor: Colors.white,
              centerTitle: false,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                elevation: 2,
                shadowColor: const Color(0xFF9B5CFF).withValues(alpha: 0.28),
                backgroundColor: const Color(0xFF9B5CFF),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              height: 68,
              elevation: 0,
              backgroundColor: const Color(0xFF1E1E1E),
              indicatorColor: const Color(0xFF9B5CFF).withValues(alpha: 0.24),
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
