import 'package:flutter/material.dart';

const Color Primary = Color(0xFFd9a477);
// const Color kBrown = Color(0xFFd9a477);
const Color kBrown = Color(0xFFA56426);
const Color kBrownDark = Color(0xFF744015);
const Color kBrownLight = Color(0xFFC98B4D);
const Color kCanvas = Color(0xFFFFF8F2);
const Color kSurface = Color(0xFFFFFFFF);
const Color kSurfaceWarm = Color(0xFFFFEFE1);
const Color kBorder = Color(0xFFE5D5C7);
const Color kHint = Color(0xFF756A62);
const Color kInk = Color(0xFF261F1A);

class AppTheme {
  const AppTheme._();

  static const double radius = 16;

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: kBrown,
          brightness: Brightness.light,
          surface: kSurface,
        ).copyWith(
          primary: kBrown,
          onPrimary: Colors.white,
          secondary: kBrownDark,
          surface: kSurface,
          onSurface: kInk,
          outline: kBorder,
        );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: kCanvas,
      fontFamily: 'Roboto',
      dividerColor: kBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: kSurface,
        foregroundColor: kInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: kInk,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: kSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: kBorder),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: kHint,
        textColor: kInk,
        selectedColor: kBrownDark,
        selectedTileColor: kSurfaceWarm,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: kSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: kHint, fontSize: 15),
        labelStyle: const TextStyle(color: kHint, fontSize: 15),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: kBrown, width: 1.6),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: Colors.red, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kBrown,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kBrownDark,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          side: const BorderSide(color: kBrown),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kBrownDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kSurface,
        selectedColor: kSurfaceWarm,
        side: const BorderSide(color: kBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: kInk, fontWeight: FontWeight.w600),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: kBrown),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kInk,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
