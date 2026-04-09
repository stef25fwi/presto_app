import 'package:flutter/material.dart';

import '../../profile_page.dart';
import '../../utils/runtime_action_logger.dart';

class SignedOutAccountFallback extends StatefulWidget {
  const SignedOutAccountFallback({
    super.key,
    this.source = 'account',
  });

  final String source;

  @override
  State<SignedOutAccountFallback> createState() =>
      _SignedOutAccountFallbackState();
}

class _SignedOutAccountFallbackState extends State<SignedOutAccountFallback> {
  bool _didLogOpen = false;

  @override
  Widget build(BuildContext context) {
    if (!_didLogOpen) {
      _didLogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        logRuntimeAction(
          area: 'account',
          action: 'signed-out-fallback-profile',
          details: <String, Object?>{
            'source': widget.source,
          },
        );
      });
    }

    return const ProfilePage();
  }
}