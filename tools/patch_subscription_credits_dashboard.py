from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> bool:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return False
    if old not in text:
        raise RuntimeError(f"Marqueur introuvable dans {path}: {old[:80]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    return True


changed = False
account = Path("lib/pages/account_page.dart")
changed |= replace_once(
    account,
    "import 'package:presto_app/pages/account/mon_entreprise_parcours_page.dart';",
    "import 'package:presto_app/pages/account/mon_entreprise_parcours_library_page.dart';",
)

account_text = account.read_text(encoding="utf-8")
if "MonEntrepriseParcoursPage()" in account_text:
    account_text = account_text.replace(
        "MonEntrepriseParcoursPage()",
        "MonEntrepriseParcoursLibraryPage()",
    )
    account.write_text(account_text, encoding="utf-8")
    changed = True
elif "MonEntrepriseParcoursLibraryPage()" not in account_text:
    raise RuntimeError("Route MonEntrepriseParcoursPage introuvable")

changed |= replace_once(
    account,
    """                      description:
                          'Retrouve tes annonces par statut, modifie-les ou supprime-les avec confirmation.',
                      isExpanded: _isPublishedOffersExpanded,""",
    """                      description:
                          'Retrouve tes annonces par statut, modifie-les ou supprime-les avec confirmation.',
                      alwaysVisibleChild: const SubscriptionCreditsInlineBadges(
                        kinds: [SubscriptionCreditKind.activeOffers],
                      ),
                      isExpanded: _isPublishedOffersExpanded,""",
)

ai_control = Path("lib/widgets/ai_publish_control.dart")
changed |= replace_once(
    ai_control,
    "import 'package:flutter/material.dart';\n\nimport 'orbiting_ai_visual.dart';",
    """import 'package:flutter/material.dart';

import '../features/subscriptions/subscription_credit_service.dart';
import '../features/subscriptions/subscription_credits_card.dart';
import 'orbiting_ai_visual.dart';""",
)
changed |= replace_once(
    ai_control,
    """        const SizedBox(height: 14),
        _MethodTabRow(""",
    """        const SizedBox(height: 10),
        const SubscriptionCreditsInlineBadges(
          kinds: [
            SubscriptionCreditKind.voiceAi,
            SubscriptionCreditKind.textAi,
          ],
        ),
        const SizedBox(height: 14),
        _MethodTabRow(""",
)

print("subscription credits dashboard patch", "applied" if changed else "already applied")
