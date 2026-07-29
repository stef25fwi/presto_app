part of '../pricing_calculator_page.dart';

/// Barre supérieure commune aux écrans du calculateur.
class _PrestoTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color background;
  final bool showBack;

  const _PrestoTopBar({
    required this.title,
    required this.background,
    required this.showBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: background,
      elevation: 0,
      title: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
            ),
          if (showBack) const SizedBox(width: 2),
          Text(
            title,
            style: kPrestoAppBarTitleStyle.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
