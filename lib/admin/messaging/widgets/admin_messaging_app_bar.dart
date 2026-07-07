import 'package:flutter/material.dart';

import '../../../constants.dart';

class AdminMessagingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;

  const AdminMessagingAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: const Color(0xFF1A73E8),
      foregroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 16,
      title: Text(title, style: kPrestoAppBarTitleStyle),
      actions: actions,
    );
  }
}
