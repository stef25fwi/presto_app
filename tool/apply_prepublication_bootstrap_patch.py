#!/usr/bin/env python3
"""Apply the prepublication bootstrap/routing patch to lib/main.dart.

The script is intentionally strict: every expected legacy fragment must exist,
otherwise it aborts without writing a partial migration.
"""

from __future__ import annotations

import pathlib
import re
import sys

MAIN_PATH = pathlib.Path("lib/main.dart")


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return source.replace(old, new, 1)


def main() -> int:
    source = MAIN_PATH.read_text(encoding="utf-8")

    if "services/initial_route_resolver.dart" not in source:
        source = replace_once(
            source,
            "import 'services/app_route_parser.dart';\n",
            "import 'services/app_route_parser.dart';\n"
            "import 'services/initial_route_resolver.dart';\n",
            "initial route resolver import",
        )

    source = replace_once(
        source,
        "LoginPage.routeName: (_) => const HomePage(),",
        "LoginPage.routeName: (_) => const LoginPage(),",
        "login route",
    )

    source = replace_once(
        source,
        "isRoot ? const Duration(seconds: 3) : const Duration(milliseconds: 600),",
        "isRoot ? Duration.zero : const Duration(milliseconds: 120),",
        "splash delay",
    )

    replacement = r'''  Widget _destinationForCurrentLocation() {
    final resolution = resolveInitialRoute(
      kIsWeb ? Uri.base.toString() : '/',
    );

    // Une seule remise à zéro au démarrage. La reprise post-auth est ensuite
    // gérée par PostAuthNavigationIntentService, sans mutations répétées.
    pendingPostAuthRoute = null;

    switch (resolution.kind) {
      case InitialRouteKind.account:
        return const HomePage(initialIndex: 4);
      case InitialRouteKind.publish:
        return const PublishOfferPage();
      case InitialRouteKind.offer:
        final target = resolution.deepLinkTarget!;
        return OfferDeepLinkPage(
          offerId: target.offerId!,
          preferMarketplace: target.preferMarketplace,
        );
      case InitialRouteKind.profile:
        return UserPublicProfilePage(
          userId: resolution.deepLinkTarget!.userId!,
        );
      case InitialRouteKind.messages:
        final target = resolution.deepLinkTarget!;
        return MessagesPageV2(
          initialConversationId: target.conversationId,
          initialDraftText: target.initialDraftText,
        );
      case InitialRouteKind.home:
        return const HomePage();
    }
  }

'''

    method_pattern = re.compile(
        r"  Widget _destinationForCurrentLocation\(\) \{.*?\n  \}\n\n(?=  void _scheduleNavigation)",
        re.DOTALL,
    )
    source, count = method_pattern.subn(replacement, source, count=1)
    if count != 1:
        raise RuntimeError(
            "initial destination method: expected exactly one method block"
        )

    MAIN_PATH.write_text(source, encoding="utf-8")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001 - CLI must report the exact blocker.
        print(f"bootstrap patch failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
