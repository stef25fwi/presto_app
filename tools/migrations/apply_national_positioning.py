from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SEO_TITLE = "iliprestō – Trouvez un service près de chez vous"
SEO_DESCRIPTION = (
    "Trouvez rapidement un particulier, un indépendant ou un professionnel "
    "partout en France. Publiez une annonce assistée par IA et échangez "
    "directement, avec 0 % de commission."
)
HERO_TITLE = (
    "Trouvez rapidement un particulier, un indépendant ou un professionnel "
    "près de chez vous"
)
NATIONAL_LAUNCH_MESSAGE = (
    "Plateforme nationale en cours de déploiement. Première ouverture en "
    "Guadeloupe, Martinique et Guyane."
)


def replace_exact(text: str, old: str, new: str, *, count: int, label: str) -> str:
    actual = text.count(old)
    if actual != count:
        raise RuntimeError(
            f"{label}: attendu {count} occurrence(s), trouvé {actual}. "
            "Le fichier a changé; migration interrompue."
        )
    return text.replace(old, new)


def patch_file(relative_path: str, transform) -> None:
    path = ROOT / relative_path
    original = path.read_text(encoding="utf-8")
    updated = transform(original)
    if updated == original:
        raise RuntimeError(f"{relative_path}: aucune modification produite")
    path.write_text(updated, encoding="utf-8")


def patch_web_index(text: str) -> str:
    old_title = "iliprestō — Les services du quotidien assistés par IA"
    old_description = (
        "Particuliers et professionnels répondent rapidement aux besoins près "
        "de chez vous. Publiez une annonce préremplie automatiquement avec "
        "l’IA et échangez directement, avec 0 % de commission."
    )
    text = replace_exact(
        text,
        old_title,
        SEO_TITLE,
        count=3,
        label="web/index.html title/OG/Twitter",
    )
    text = replace_exact(
        text,
        old_description,
        SEO_DESCRIPTION,
        count=3,
        label="web/index.html description/OG/Twitter",
    )
    text = replace_exact(
        text,
        '        "name": "iliprestō",\n        "url": "https://ilipresto.fr/",\n        "logo": "https://ilipresto.fr/icons/Icon-512.png",\n        "description": "Plateforme de mise en relation pour les services et microservices du quotidien, avec annonces assistées par l’intelligence artificielle et 0 % de commission."',
        '        "name": "iliprestō",\n        "alternateName": "ilipresto",\n        "url": "https://ilipresto.fr/",\n        "logo": "https://ilipresto.fr/icons/Icon-512.png",\n        "areaServed": {\n          "@type": "Country",\n          "name": "France"\n        },\n        "description": "Plateforme nationale de mise en relation pour les services et microservices du quotidien partout en France, avec annonces assistées par l’intelligence artificielle et 0 % de commission."',
        count=1,
        label="web/index.html Organization JSON-LD",
    )
    text = replace_exact(
        text,
        '        "description": "Les services du quotidien assistés par IA, près de chez vous."',
        '        "description": "Trouvez un service près de chez vous partout en France."',
        count=1,
        label="web/index.html WebSite JSON-LD",
    )
    text = replace_exact(
        text,
        "        <h1>Trouvez rapidement un particulier ou un professionnel disponible près de chez vous</h1>",
        f"        <h1>{HERO_TITLE}</h1>",
        count=1,
        label="web/index.html H1",
    )
    text = replace_exact(
        text,
        """        <p>
          iliprestō est une plateforme de mise en relation entre particuliers,
          indépendants et professionnels. Publiez une annonce assistée et
          préremplie par l’IA, puis échangez directement avec les personnes
          disponibles et intéressées, avec 0 % de commission.
        </p>""",
        """        <p>
          Trouvez rapidement un particulier, un indépendant ou un professionnel
          partout en France. Publiez une annonce assistée par IA et échangez
          directement, avec 0 % de commission.
        </p>""",
        count=1,
        label="web/index.html visible description",
    )
    text = replace_exact(
        text,
        "Ouverture prochaine en Guadeloupe, Martinique et Guyane.",
        NATIONAL_LAUNCH_MESSAGE,
        count=1,
        label="web/index.html national launch message",
    )
    return text


def patch_service(text: str) -> str:
    text = replace_exact(
        text,
        """  static const String defaultTitle =
      'Trouvez rapidement un particulier ou un professionnel près de chez vous';
  static const String defaultDescription =
      'iliprestō met en relation particuliers, indépendants et professionnels '
      'pour répondre rapidement à vos besoins en services et microservices du '
      'quotidien, avec des annonces assistées par IA et 0 % de commission.';
  static const String defaultLaunchMessage =
      'Ouverture prochaine en Guadeloupe, Martinique et Guyane.';""",
        """  static const String defaultTitle =
      'Trouvez rapidement un particulier, un indépendant ou un professionnel '
      'près de chez vous';
  static const String defaultDescription =
      'Trouvez rapidement un particulier, un indépendant ou un professionnel '
      'partout en France. Publiez une annonce assistée par IA et échangez '
      'directement, avec 0 % de commission.';
  static const String defaultLaunchMessage =
      'Plateforme nationale en cours de déploiement. Première ouverture en '
      'Guadeloupe, Martinique et Guyane.';

  static const String _legacyDefaultTitle =
      'Trouvez rapidement un particulier ou un professionnel près de chez vous';
  static const String _legacyDefaultDescription =
      'iliprestō met en relation particuliers, indépendants et professionnels '
      'pour répondre rapidement à vos besoins en services et microservices du '
      'quotidien, avec des annonces assistées par IA et 0 % de commission.';
  static const String _legacyDefaultLaunchMessage =
      'Ouverture prochaine en Guadeloupe, Martinique et Guyane.';""",
        count=1,
        label="PublicLandingConfigService default national copy",
    )
    text = replace_exact(
        text,
        """    _launchMessage = _valueOrDefault(
      adapter.getString(launchMessageKey),
      defaultLaunchMessage,
    );""",
        """    _launchMessage = _valueOrDefault(
      adapter.getString(launchMessageKey),
      defaultLaunchMessage,
    );

    // Remote Config peut encore contenir les anciennes valeurs publiées.
    // Cette migration maintient immédiatement le positionnement national sans
    // attendre une modification manuelle de la console Firebase.
    if (_title == _legacyDefaultTitle) {
      _title = defaultTitle;
    }
    if (_description == _legacyDefaultDescription) {
      _description = defaultDescription;
    }
    if (_launchMessage == _legacyDefaultLaunchMessage) {
      _launchMessage = defaultLaunchMessage;
    }""",
        count=1,
        label="PublicLandingConfigService legacy Remote Config migration",
    )
    return text


def patch_html_test(text: str) -> str:
    text = replace_exact(
        text,
        "Trouvez rapidement un particulier ou un professionnel disponible près de chez vous",
        HERO_TITLE,
        count=1,
        label="HTML shell test H1",
    )
    text = replace_exact(
        text,
        "Ouverture prochaine en Guadeloupe, Martinique et Guyane.",
        NATIONAL_LAUNCH_MESSAGE,
        count=1,
        label="HTML shell test launch message",
    )
    marker = """      expect(html, contains('\"@type\": \"Organization\"'));
    });"""
    replacement = f"""      expect(html, contains('\"@type\": \"Organization\"'));
      expect(html, contains('<title>{SEO_TITLE}</title>'));
      expect(
        html,
        contains(
          '<meta name=\"description\" content=\"{SEO_DESCRIPTION}\">',
        ),
      );
      expect(html, contains('\"areaServed\"'));
      expect(html, contains('\"@type\": \"Country\"'));
      expect(html, contains('\"name\": \"France\"'));
      expect(
        html,
        isNot(contains('Ouverture prochaine en Guadeloupe, Martinique et Guyane.')),
      );
    });"""
    return replace_exact(
        text,
        marker,
        replacement,
        count=1,
        label="HTML shell test national metadata assertions",
    )


def patch_service_test(text: str) -> str:
    marker = """  group('PublicLandingConfigService', () {
    test('est actif par défaut uniquement sur le domaine public', () {"""
    insertion = f"""  group('PublicLandingConfigService', () {{
    test('publie un positionnement national par défaut', () {{
      expect(
        PublicLandingConfigService.defaultTitle,
        '{HERO_TITLE}',
      );
      expect(
        PublicLandingConfigService.defaultDescription,
        '{SEO_DESCRIPTION}',
      );
      expect(
        PublicLandingConfigService.defaultLaunchMessage,
        '{NATIONAL_LAUNCH_MESSAGE}',
      );
    }});

    test('est actif par défaut uniquement sur le domaine public', () {{"""
    text = replace_exact(
        text,
        marker,
        insertion,
        count=1,
        label="service test default positioning",
    )
    end_marker = """    test('remplace les valeurs distantes vides par les textes par défaut',
        () async {"""
    migration_test = """    test('migre les anciennes valeurs Remote Config vers le national',
        () async {
      final service = PublicLandingConfigService(
        adapter: _FakePublicLandingRemoteConfigAdapter(
          title:
              'Trouvez rapidement un particulier ou un professionnel près de chez vous',
          description:
              'iliprestō met en relation particuliers, indépendants et professionnels pour répondre rapidement à vos besoins en services et microservices du quotidien, avec des annonces assistées par IA et 0 % de commission.',
          launchMessage:
              'Ouverture prochaine en Guadeloupe, Martinique et Guyane.',
        ),
      );

      await service.initialize();

      expect(service.title, PublicLandingConfigService.defaultTitle);
      expect(
        service.description,
        PublicLandingConfigService.defaultDescription,
      );
      expect(
        service.launchMessage,
        PublicLandingConfigService.defaultLaunchMessage,
      );
    });

    test('remplace les valeurs distantes vides par les textes par défaut',
        () async {"""
    return replace_exact(
        text,
        end_marker,
        migration_test,
        count=1,
        label="service test Remote Config migration",
    )


def patch_product_requirements(text: str) -> str:
    text = text.replace(
        "iliprestō — Les services du quotidien assistés par IA",
        SEO_TITLE,
    )
    text = text.replace(
        "Particuliers et professionnels répondent rapidement aux besoins près de chez vous. Publiez une annonce préremplie automatiquement avec l’IA et échangez directement, avec 0 % de commission.",
        SEO_DESCRIPTION,
    )
    return text


def main() -> None:
    patch_file("web/index.html", patch_web_index)
    patch_file(
        "lib/services/public_landing_config_service.dart",
        patch_service,
    )
    patch_file(
        "test/web/public_prelaunch_html_shell_test.dart",
        patch_html_test,
    )
    patch_file(
        "test/services/public_landing_config_service_test.dart",
        patch_service_test,
    )
    patch_file(
        "docs/product/product-requirements.md",
        patch_product_requirements,
    )


if __name__ == "__main__":
    main()
