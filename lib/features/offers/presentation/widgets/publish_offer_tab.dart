import 'package:flutter/material.dart';

import '../../../../pages/publish_offer_page.dart';

/// Keeps a visited draft alive while pausing animations outside its tab.
class PublishOfferTab extends StatelessWidget {
  const PublishOfferTab({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: const PublishOfferPage(),
    );
  }
}
