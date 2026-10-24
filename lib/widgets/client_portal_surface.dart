import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'auth_background.dart';

/// Shared visual language for every client-facing screen.
class ClientPortalSurface extends StatelessWidget {
  const ClientPortalSurface({super.key, required this.child});

  final Widget child;

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    final glassBorder = BorderSide(color: Colors.white.withValues(alpha: .17));
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: glassBorder,
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: Primary,
        onPrimary: const Color(0xFF3B2116),
        surface: const Color(0xFF352019),
        onSurface: Colors.white,
        outline: Colors.white24,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Primary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xE621100B),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xE638241C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: glassBorder,
        ),
      ),
      dividerColor: Colors.white.withValues(alpha: .14),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xD934211A),
        hintStyle: const TextStyle(color: Color(0xFFCCBBB1)),
        labelStyle: const TextStyle(color: Primary),
        prefixIconColor: Primary,
        suffixIconColor: Primary,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: Primary, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Primary
              : const Color(0xE638241C),
        ),
        backgroundColor: const Color(0xE638241C),
        selectedColor: Primary,
        secondarySelectedColor: Primary,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF3B2116)
                : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        secondaryLabelStyle: const TextStyle(
          color: Color(0xFF3B2116),
          fontWeight: FontWeight.w800,
        ),
        checkmarkColor: const Color(0xFF3B2116),
        side: glassBorder,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF352019),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF352019),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Color(0xFF352019),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF352019),
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        textColor: Colors.white,
        iconColor: Primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AuthBackground(
    overlay: .86,
    child: Theme(data: theme(context), child: child),
  );
}
