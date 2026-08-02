from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "https://ilipresto.fr"
ORG_ID = f"{BASE}/#organization"
WEBSITE_ID = f"{BASE}/#website"
LOGO_ID = f"{BASE}/#logo"


def compact_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def script_block(value: object) -> str:
    return (
        '  <script type="application/ld+json">\n'
        f"  {compact_json(value)}\n"
        "  </script>"
    )


def replace_first_jsonld(relative_path: str, value: object) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r'  <script type="application/ld\+json">[\s\S]*?</script>',
        re.MULTILINE,
    )
    updated, count = pattern.subn(script_block(value), text, count=1)
    if count != 1:
        raise RuntimeError(f"{relative_path}: bloc JSON-LD attendu une fois, trouvé {count}")
    path.write_text(updated, encoding="utf-8")


def organization_node() -> dict[str, object]:
    return {
        "@type": "Organization",
        "@id": ORG_ID,
        "name": "iliprestō",
        "alternateName": "ilipresto",
        "url": f"{BASE}/",
        "description": (
            "Plateforme nationale de mise en relation pour les services et "
            "microservices du quotidien partout en France, avec annonces "
            "assistées par intelligence artificielle et 0 % de commission."
        ),
        "logo": {
            "@type": "ImageObject",
            "@id": LOGO_ID,
            "url": f"{BASE}/icons/Icon-512.png",
            "contentUrl": f"{BASE}/icons/Icon-512.png",
            "width": 512,
            "height": 512,
            "caption": "Logo iliprestō",
        },
        "image": {"@id": LOGO_ID},
        "areaServed": {"@type": "Country", "name": "France"},
        "knowsLanguage": "fr-FR",
    }


def patch_homepage() -> None:
    description = (
        "Trouvez rapidement un particulier, un indépendant ou un professionnel "
        "partout en France. Publiez une annonce assistée par IA et échangez "
        "directement, avec 0 % de commission."
    )
    graph = {
        "@context": "https://schema.org",
        "@graph": [
            organization_node(),
            {
                "@type": "WebSite",
                "@id": WEBSITE_ID,
                "url": f"{BASE}/",
                "name": "iliprestō",
                "alternateName": "ilipresto",
                "description": "Trouvez un service près de chez vous partout en France.",
                "inLanguage": "fr-FR",
                "publisher": {"@id": ORG_ID},
            },
            {
                "@type": "WebPage",
                "@id": f"{BASE}/#webpage",
                "url": f"{BASE}/",
                "name": "iliprestō – Trouvez un service près de chez vous",
                "description": description,
                "inLanguage": "fr-FR",
                "isPartOf": {"@id": WEBSITE_ID},
                "about": {"@id": ORG_ID},
                "mainEntity": {"@id": f"{BASE}/#service"},
                "primaryImageOfPage": {"@id": LOGO_ID},
            },
            {
                "@type": "Service",
                "@id": f"{BASE}/#service",
                "name": "Mise en relation pour les services du quotidien",
                "serviceType": "Plateforme de mise en relation pour services et microservices",
                "description": (
                    "Publication d’annonces assistée par intelligence artificielle "
                    "et échange direct entre particuliers, indépendants et professionnels."
                ),
                "provider": {"@id": ORG_ID},
                "areaServed": {"@type": "Country", "name": "France"},
                "availableChannel": {
                    "@type": "ServiceChannel",
                    "serviceUrl": f"{BASE}/",
                },
            },
        ],
    }
    replace_first_jsonld("web/index.html", graph)

    path = ROOT / "web/index.html"
    text = path.read_text(encoding="utf-8")
    marker = (
        '        <nav class="prelaunch-public-links" '
        'aria-label="Pages publiques iliprestō">\n'
    )
    if marker not in text:
        raise RuntimeError("web/index.html: navigation publique introuvable")
    additions = (
        '          <a href="/a-propos">À propos</a>\n'
        '          <a href="/guides/comment-fonctionne-ilipresto">Guide d’utilisation</a>\n'
    )
    if 'href="/a-propos"' not in text:
        text = text.replace(marker, marker + additions, 1)
    path.write_text(text, encoding="utf-8")


def region_graph(slug: str, name: str, description: str) -> dict[str, object]:
    canonical = f"{BASE}/{slug}"
    service_id = f"{canonical}#service"
    return {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "WebPage",
                "@id": f"{canonical}#webpage",
                "url": canonical,
                "name": f"Services en {name} – Trouvez un prestataire | iliprestō",
                "description": description,
                "inLanguage": "fr-FR",
                "isPartOf": {"@id": WEBSITE_ID},
                "publisher": {"@id": ORG_ID},
                "about": {"@id": service_id},
                "mainEntity": {"@id": service_id},
                "primaryImageOfPage": {"@id": LOGO_ID},
                "breadcrumb": {"@id": f"{canonical}#breadcrumb"},
            },
            {
                "@type": "Service",
                "@id": service_id,
                "name": f"Services et microservices en {name}",
                "serviceType": "Mise en relation pour services et microservices du quotidien",
                "description": description,
                "provider": {"@id": ORG_ID},
                "areaServed": {"@type": "AdministrativeArea", "name": name},
                "availableChannel": {
                    "@type": "ServiceChannel",
                    "serviceUrl": canonical,
                },
            },
            {
                "@type": "BreadcrumbList",
                "@id": f"{canonical}#breadcrumb",
                "itemListElement": [
                    {
                        "@type": "ListItem",
                        "position": 1,
                        "name": "Accueil",
                        "item": f"{BASE}/",
                    },
                    {
                        "@type": "ListItem",
                        "position": 2,
                        "name": name,
                        "item": canonical,
                    },
                ],
            },
        ],
    }


def patch_regions() -> None:
    regions = {
        "guadeloupe": (
            "Guadeloupe",
            "Trouvez un particulier, un indépendant ou un professionnel en Guadeloupe. "
            "Publiez une annonce assistée par IA et échangez directement, avec 0 % de commission.",
        ),
        "martinique": (
            "Martinique",
            "Trouvez un particulier, un indépendant ou un professionnel en Martinique. "
            "Publiez une annonce assistée par IA et échangez directement, avec 0 % de commission.",
        ),
        "guyane": (
            "Guyane",
            "Trouvez un particulier, un indépendant ou un professionnel en Guyane. "
            "Publiez une annonce assistée par IA et échangez directement, avec 0 % de commission.",
        ),
    }
    for slug, (name, description) in regions.items():
        replace_first_jsonld(
            f"web/{slug}.html",
            region_graph(slug, name, description),
        )


def patch_guide() -> None:
    route = "/guides/comment-fonctionne-ilipresto"
    canonical = f"{BASE}{route}"
    description = (
        "Découvrez comment publier une annonce, recevoir des réponses et échanger "
        "directement sur iliprestō, la plateforme nationale de services assistée par IA."
    )
    graph = {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "Article",
                "@id": f"{canonical}#article",
                "headline": "Comment fonctionne iliprestō ?",
                "description": description,
                "image": {"@id": LOGO_ID},
                "datePublished": "2026-08-02T18:00:00Z",
                "dateModified": "2026-08-02T18:00:00Z",
                "author": {"@id": ORG_ID},
                "publisher": {"@id": ORG_ID},
                "mainEntityOfPage": {"@id": f"{canonical}#webpage"},
                "articleSection": "Guide d’utilisation",
                "inLanguage": "fr-FR",
                "isAccessibleForFree": True,
            },
            {
                "@type": "WebPage",
                "@id": f"{canonical}#webpage",
                "url": canonical,
                "name": "Comment fonctionne iliprestō ? Guide de mise en relation",
                "description": description,
                "inLanguage": "fr-FR",
                "isPartOf": {"@id": WEBSITE_ID},
                "about": {"@id": f"{BASE}/#service"},
                "breadcrumb": {"@id": f"{canonical}#breadcrumb"},
                "primaryImageOfPage": {"@id": LOGO_ID},
            },
            organization_node(),
            {
                "@type": "BreadcrumbList",
                "@id": f"{canonical}#breadcrumb",
                "itemListElement": [
                    {
                        "@type": "ListItem",
                        "position": 1,
                        "name": "Accueil",
                        "item": f"{BASE}/",
                    },
                    {
                        "@type": "ListItem",
                        "position": 2,
                        "name": "Comment fonctionne iliprestō",
                        "item": canonical,
                    },
                ],
            },
        ],
    }
    replace_first_jsonld("web/guides/comment-fonctionne-ilipresto.html", graph)

    path = ROOT / "web/guides/comment-fonctionne-ilipresto.html"
    text = path.read_text(encoding="utf-8")
    old = (
        '<nav class="public-breadcrumb" aria-label="Fil d’Ariane"><ol>'
        '<li><a href="/">Accueil</a></li><li>Guides</li>'
        '<li aria-current="page">Comment fonctionne iliprestō</li></ol></nav>'
    )
    new = (
        '<nav class="public-breadcrumb" aria-label="Fil d’Ariane"><ol>'
        '<li><a href="/">Accueil</a></li>'
        '<li aria-current="page">Comment fonctionne iliprestō</li></ol></nav>'
    )
    if old not in text:
        raise RuntimeError("guide: fil d’Ariane visible introuvable")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def patch_firebase() -> None:
    path = ROOT / "firebase.json"
    config = json.loads(path.read_text(encoding="utf-8"))
    pages = {
        "/a-propos": "/a-propos.html",
        "/guides/comment-fonctionne-ilipresto": "/guides/comment-fonctionne-ilipresto.html",
    }
    for hosting in config["hosting"]:
        redirects = hosting.setdefault("redirects", [])
        redirect_sources = {
            source
            for route, destination in pages.items()
            for source in (f"{route}/", destination)
        }
        desired_redirects = [
            {"source": source, "destination": route, "type": 301}
            for route, destination in pages.items()
            for source in (f"{route}/", destination)
        ]
        hosting["redirects"] = desired_redirects + [
            item for item in redirects if item.get("source") not in redirect_sources
        ]

        rewrites = hosting.setdefault("rewrites", [])
        route_sources = set(pages)
        desired_rewrites = [
            {"source": route, "destination": destination}
            for route, destination in pages.items()
        ]
        hosting["rewrites"] = desired_rewrites + [
            item for item in rewrites if item.get("source") not in route_sources
        ]

        headers = hosting.setdefault("headers", [])
        header_sources = set(pages)
        desired_headers = [
            {
                "source": route,
                "headers": [
                    {"key": "Cache-Control", "value": "no-cache, must-revalidate"}
                ],
            }
            for route in pages
        ]
        hosting["headers"] = [
            item for item in headers if item.get("source") not in header_sources
        ] + desired_headers

    path.write_text(
        json.dumps(config, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    patch_homepage()
    patch_regions()
    patch_guide()
    patch_firebase()


if __name__ == "__main__":
    main()
