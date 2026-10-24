import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppBackAppBar({super.key, this.title});

  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Colors.white,
    foregroundColor: kInk,
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back),
    ),
    title: title == null
        ? null
        : Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
