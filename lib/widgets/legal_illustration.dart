import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum LegalArt { logo, handshake, access, security }

class LegalIllustration extends StatelessWidget {
  const LegalIllustration({
    super.key,
    required this.type,
    required this.size,
  });

  final LegalArt type;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LegalArt.logo:
        return Image.asset(
          'assets/designer.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      case LegalArt.handshake:
        return Image.asset(
          'assets/designer.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      case LegalArt.access:
        return Image.asset(
          'assets/lawyerlogin.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      case LegalArt.security:
        return Image.asset(
          'assets/login.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
    }
  }
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, required this.size, required this.circular});

  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE1C5AC),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: size * .16, child: Icon(Icons.balance, size: size * .42, color: Colors.black87)),
          Positioned(bottom: size * .18, child: Icon(Icons.handshake_outlined, size: size * .55, color: Colors.black87)),
        ],
      ),
    );
  }
}

class IconCluster extends StatelessWidget {
  const IconCluster({
    super.key,
    required this.size,
    required this.background,
    required this.icons,
  });

  final double size;
  final Color background;
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * .78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 8,
            child: Container(
              width: size * .82,
              height: size * .55,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * .08)),
            ),
          ),
          Positioned(left: size * .12, top: size * .12, child: Icon(icons[0], color: const Color(0xFF24383B), size: size * .28)),
          Positioned(right: size * .1, bottom: size * .11, child: Icon(icons[1], color: kBrown, size: size * .28)),
          Positioned(top: size * .03, child: Icon(icons[2], color: const Color(0xFF24383B), size: size * .36)),
          Positioned(bottom: size * .04, left: size * .36, child: Icon(icons[3], color: const Color(0xFFFF9E2C), size: size * .22)),
        ],
      ),
    );
  }
}
