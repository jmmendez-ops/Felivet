import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';

class FeliVetApp extends StatelessWidget {
  const FeliVetApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFB9A2F0);
    const onPrimary = Color(0xFF1C172B);
    const surface = Color(0xFF1F1F1E);
    const background = Color(0xFF161615);
    const surfaceVariant = Color(0xFF2A2A28);
    const elevatedSurface = Color(0xFF262624);
    const outline = Color(0xFF6A6963);
    const outlineVariant = Color(0xFF3A3A37);
    const onSurface = Color(0xFFECEBE6);
    const onSurfaceVariant = Color(0xFFA6A49C);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: const Color(0xFF3C3158),
      onPrimaryContainer: const Color(0xFFC9B8F5),
      secondary: const Color(0xFFC9B8F5),
      onSecondary: onPrimary,
      secondaryContainer: surfaceVariant,
      onSecondaryContainer: onSurface,
      tertiary: const Color(0xFFE5B454),
      onTertiary: const Color(0xFF261E0D),
      tertiaryContainer: const Color(0xFF4A3B1D),
      onTertiaryContainer: const Color(0xFFFFE5A8),
      error: const Color(0xFFF07A7A),
      onError: const Color(0xFF351313),
      errorContainer: const Color(0xFF5A2525),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: background,
      inversePrimary: const Color(0xFF6E5AA5),
      surfaceTint: primary,
      surfaceContainerLowest: background,
      surfaceContainerLow: const Color(0xFF1B1B1A),
      surfaceContainer: const Color(0xFF20201F),
      surfaceContainerHigh: elevatedSurface,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FeliVet Insight',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        primaryColor: primary,
        scaffoldBackgroundColor: background,
        cardColor: surface,
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          toolbarHeight: 52,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: background,
          foregroundColor: onSurface,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            elevation: 0,
            backgroundColor: primary,
            foregroundColor: onPrimary,
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
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: onSurface,
            side: const BorderSide(color: outline),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceVariant,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primary),
            borderRadius: BorderRadius.circular(12),
          ),
          hintStyle: const TextStyle(color: onSurfaceVariant),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: elevatedSurface,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: elevatedSurface,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: elevatedSurface,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: elevatedSurface,
          contentTextStyle: TextStyle(color: onSurface),
          actionTextColor: primary,
        ),
        dividerTheme: const DividerThemeData(color: outlineVariant),
        listTileTheme: const ListTileThemeData(
          textColor: onSurface,
          iconColor: onSurfaceVariant,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? onPrimary
                : onSurfaceVariant,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primary
                : surfaceVariant,
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: primary,
          thumbColor: primary,
          inactiveTrackColor: outlineVariant,
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: surfaceVariant,
          selectedColor: primary,
          side: BorderSide(color: outlineVariant),
          labelStyle: TextStyle(color: onSurfaceVariant),
          checkmarkColor: onPrimary,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          elevation: 0,
          backgroundColor: surface,
          indicatorColor: primary.withValues(alpha: 0.16),
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? primary
                  : onSurfaceVariant,
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
