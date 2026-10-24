import 'dart:ui';

import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child, this.overlay = .58});

  final Widget child;
  final double overlay;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/lawyerbg.jpg',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        semanticLabel: 'Courtroom with scales of justice and law books',
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: overlay * .62),
              const Color(0xFF301A10).withValues(alpha: overlay * .78),
              const Color(0xFF120604).withValues(alpha: overlay),
            ],
            stops: const [0, .52, 1],
          ),
        ),
      ),
      child,
    ],
  );
}

class AuthGlassPanel extends StatelessWidget {
  const AuthGlassPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF3A241B).withValues(alpha: .42),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .28)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 18,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

InputDecorationTheme authInputTheme() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: .32)),
  );
  return InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: Colors.white.withValues(alpha: .07),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    hintStyle: const TextStyle(color: Colors.white60, fontSize: 13),
    labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
    prefixIconColor: Colors.white70,
    suffixIconColor: Colors.white70,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: Color(0xFFD5A66F), width: 1.7),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: Color(0xFFFF8A80)),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.7),
    ),
  );
}

ThemeData authFormTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    inputDecorationTheme: authInputTheme(),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    colorScheme: base.colorScheme.copyWith(
      surface: const Color(0xFF4A3026),
      onSurface: Colors.white,
    ),
  );
}
