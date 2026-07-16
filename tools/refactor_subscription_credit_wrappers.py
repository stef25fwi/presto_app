from pathlib import Path
import subprocess


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise RuntimeError(f"Marqueur introuvable dans {path}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# Le widget historique revient exactement à sa version main : aucune dette ne grandit.
ai_control = Path("lib/widgets/ai_publish_control.dart")
ai_control.write_bytes(
    subprocess.check_output(
        ["git", "show", "origin/main:lib/widgets/ai_publish_control.dart"]
    )
)

account = Path("lib/pages/account_page.dart")
replace_once(
    account,
    "import 'user_offers_section.dart';",
    "import 'account/account_offers_credits_section.dart';",
)
replace_once(
    account,
    """                    _buildAccountSectionCard(
                      icon: Icons.campaign_outlined,
                      title: 'Gérer mes annonces',
                      description:
                          'Retrouve tes annonces par statut, modifie-les ou supprime-les avec confirmation.',
                      alwaysVisibleChild: const SubscriptionCreditsInlineBadges(
                        kinds: [SubscriptionCreditKind.activeOffers],
                      ),
                      isExpanded: _isPublishedOffersExpanded,
                      onToggle: () {
                        setState(() {
                          _isPublishedOffersExpanded =
                              !_isPublishedOffersExpanded;
                        });
                      },
                      child: RepaintBoundary(
                        child: UserOffersSection(
                          userId: user.uid,
                          showTitle: false,
                        ),
                      ),
                    ),""",
    """                    AccountOffersCreditsSection(
                      userId: user.uid,
                      isExpanded: _isPublishedOffersExpanded,
                      onToggle: () {
                        setState(() {
                          _isPublishedOffersExpanded =
                              !_isPublishedOffersExpanded;
                        });
                      },
                    ),""",
)

publish = Path("lib/pages/publish_offer_page.dart")
replace_once(
    publish,
    "import '../widgets/ai_publish_control.dart';",
    "import '../widgets/ai_publish_control_with_credits.dart';",
)
publish_text = publish.read_text(encoding="utf-8")
if "AiPublishControlWithCredits(" not in publish_text:
    if "AiPublishControl(" not in publish_text:
        raise RuntimeError("Constructeur AiPublishControl introuvable")
    publish.write_text(
        publish_text.replace("AiPublishControl(", "AiPublishControlWithCredits("),
        encoding="utf-8",
    )

print("subscription credit wrappers applied")
