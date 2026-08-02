from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGIONS = ("guadeloupe", "martinique", "guyane")
LEGAL_ROUTES = (
    "mentions-legales",
    "confidentialite",
    "cgu",
    "suppression-compte",
)
ALL_ROUTES = REGIONS + LEGAL_ROUTES


def replace_once(relative_path: str, old: str, new: str) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"{relative_path}: attendu une occurrence, trouvé {count}: {old[:100]!r}"
        )
    path.write_text(text.replace(old, new), encoding="utf-8")


def patch_index() -> None:
    replace_once(
        "web/index.html",
        '  <link rel="canonical" href="https://ilipresto.fr/">\n',
        '  <link rel="canonical" href="https://ilipresto.fr/">\n'
        '  <link rel="stylesheet" href="/public-pages.css">\n'
        '  <script src="/public-route-seo.js"></script>\n',
    )
    replace_once(
        "web/index.html",
        """        <div class="prelaunch-message">
          Plateforme nationale en cours de déploiement. Première ouverture en Guadeloupe, Martinique et Guyane.
        </div>
      </main>""",
        """        <div class="prelaunch-message">
          Plateforme nationale en cours de déploiement. Première ouverture en Guadeloupe, Martinique et Guyane.
        </div>
        <nav class="prelaunch-public-links" aria-label="Pages publiques iliprestō">
          <a href="/guadeloupe">Guadeloupe</a>
          <a href="/martinique">Martinique</a>
          <a href="/guyane">Guyane</a>
          <a href="/mentions-legales">Mentions légales</a>
          <a href="/confidentialite">Confidentialité</a>
          <a href="/cgu">CGU</a>
          <a href="/suppression-compte">Suppression du compte</a>
        </nav>
      </main>""",
    )


def patch_sitemap() -> None:
    entries = (
        ("/", "weekly", "1.0"),
        ("/guadeloupe", "weekly", "0.8"),
        ("/martinique", "weekly", "0.8"),
        ("/guyane", "weekly", "0.8"),
        ("/confidentialite", "monthly", "0.5"),
        ("/cgu", "monthly", "0.5"),
        ("/mentions-legales", "monthly", "0.3"),
        ("/suppression-compte", "monthly", "0.3"),
    )
    blocks: list[str] = []
    for route, frequency, priority in entries:
        url = "https://ilipresto.fr/" if route == "/" else f"https://ilipresto.fr{route}"
        blocks.append(
            f"""  <url>
    <loc>{url}</loc>
    <lastmod>2026-08-02</lastmod>
    <changefreq>{frequency}</changefreq>
    <priority>{priority}</priority>
  </url>"""
        )
    content = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "\n".join(blocks)
        + "\n</urlset>\n"
    )
    (ROOT / "web/sitemap.xml").write_text(content, encoding="utf-8")


def patch_firebase() -> None:
    path = ROOT / "firebase.json"
    config = json.loads(path.read_text(encoding="utf-8"))
    for hosting in config["hosting"]:
        redirects = hosting.setdefault("redirects", [])
        wanted_redirects: list[dict[str, object]] = []
        for slug in REGIONS:
            wanted_redirects.extend(
                (
                    {"source": f"/{slug}/", "destination": f"/{slug}", "type": 301},
                    {"source": f"/{slug}.html", "destination": f"/{slug}", "type": 301},
                )
            )
        wanted_sources = {item["source"] for item in wanted_redirects}
        hosting["redirects"] = wanted_redirects + [
            item for item in redirects if item.get("source") not in wanted_sources
        ]

        exact_rewrites = [
            {"source": f"/{slug}", "destination": f"/{slug}.html"}
            for slug in REGIONS
        ]
        exact_sources = {item["source"] for item in exact_rewrites}
        hosting["rewrites"] = exact_rewrites + [
            item
            for item in hosting.get("rewrites", [])
            if item.get("source") not in exact_sources
        ]

        public_headers = [
            {
                "source": f"/{slug}",
                "headers": [
                    {"key": "Cache-Control", "value": "no-cache, must-revalidate"}
                ],
            }
            for slug in ALL_ROUTES
        ]
        public_sources = {item["source"] for item in public_headers}
        hosting["headers"] = [
            item
            for item in hosting.get("headers", [])
            if item.get("source") not in public_sources
        ] + public_headers

    path.write_text(
        json.dumps(config, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def patch_seo_workflow() -> None:
    replace_once(
        ".github/workflows/seo-acquisition-readiness.yml",
        """      - name: Validate national positioning
        run: node tools/quality/check_national_positioning.mjs
""",
        """      - name: Validate national positioning
        run: node tools/quality/check_national_positioning.mjs
      - name: Validate every public page
        run: node tools/quality/check_public_page_seo.mjs
""",
    )


def patch_deploy_workflow() -> None:
    path = ROOT / ".github/workflows/deploy.yml"
    text = path.read_text(encoding="utf-8")
    quality_marker = """      - name: Enforce repository quality gates
        run: |
          python3 tools/quality/audit_repository.py \\
            --output-dir quality_reports/production \\
            --git-ref '${{ github.sha }}' \\
            --enforce
"""
    if text.count(quality_marker) != 1:
        raise RuntimeError("deploy.yml: quality gate introuvable")
    text = text.replace(
        quality_marker,
        quality_marker
        + """
      - name: Validate every public page
        run: node tools/quality/check_public_page_seo.mjs
""",
    )

    manifest_marker = """          curl --fail --silent --show-error \\
            --retry 6 --retry-delay 5 --retry-all-errors \\
            https://ilipresto.fr/manifest.json >/dev/null
"""
    if text.count(manifest_marker) != 1:
        raise RuntimeError("deploy.yml: smoke test manifest introuvable")
    urls = (
        "https://ilipresto.fr/",
        "https://ilipresto.fr/guadeloupe",
        "https://ilipresto.fr/martinique",
        "https://ilipresto.fr/guyane",
        "https://ilipresto.fr/mentions-legales",
        "https://ilipresto.fr/confidentialite",
        "https://ilipresto.fr/cgu",
        "https://ilipresto.fr/suppression-compte",
    )
    loop_lines = " \\\n".join(f"            {url}" for url in urls)
    smoke = f"""
          for url in \\
{loop_lines}; do
            page="$(curl --fail --silent --show-error \\
              --retry 6 --retry-delay 5 --retry-all-errors "$url")"
            echo "$page" | grep -q '<title>'
            echo "$page" | grep -q 'rel="canonical"'
          done

          for url in \\
            https://ilipresto.fr/guadeloupe \\
            https://ilipresto.fr/martinique \\
            https://ilipresto.fr/guyane; do
            page="$(curl --fail --silent --show-error "$url")"
            echo "$page" | grep -q '<h1>'
            echo "$page" | grep -q 'aria-label="Fil d’Ariane"'
          done
"""
    path.write_text(text.replace(manifest_marker, manifest_marker + smoke), encoding="utf-8")


def main() -> None:
    patch_index()
    patch_sitemap()
    patch_firebase()
    patch_seo_workflow()
    patch_deploy_workflow()


if __name__ == "__main__":
    main()
