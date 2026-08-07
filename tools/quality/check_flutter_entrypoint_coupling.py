#!/usr/bin/env python3
"""Guard the Flutter application entrypoint during Lot 2 decomposition.

`lib/main.dart` must remain a thin composition root, not a service locator. A
small transitional allowlist tracks the remaining historical production imports
while Lot 2 removes them progressively. Tests are not allowed to depend on the
entrypoint. The production allowlist is intentionally monotonic: if an allowed
file stops importing main.dart, CI asks us to remove it from the list.
"""

from __future__ import annotations

import re
from pathlib import Path


# Transitional production debt. This set must only shrink during Lot 2.
_ALLOWED_MAIN_IMPORTERS = {
    "lib/pages/account_page.dart",
    "lib/pages/consult_offers_page.dart",
    "lib/pages/fiche_pro_page.dart",
    "lib/pages/home_page.dart",
    "lib/pages/publish_offer_page.dart",
    "lib/pages/user_offers_section.dart",
}

_IMPORT_RE = re.compile(r"^\s*import\s+['\"]([^'\"]+)['\"]", re.MULTILINE)
_FORBIDDEN_ENTRYPOINT_DECLARATION_RE = re.compile(
    r"^\s*(?:class|mixin|enum|extension|typedef)\s+",
    re.MULTILINE,
)
_MAX_MAIN_LINES = 25
_REQUIRED_MAIN = "Future<void> main() => bootstrapPrestoApp(const PrestoApp());"
_ALLOWED_MAIN_IMPORTS = {
    "app/presto_app.dart",
    "bootstrap/app_bootstrap.dart",
}


def _imports_app_main(source: str) -> bool:
    if source == "main.dart":
        return True
    if source == "package:presto_app/main.dart":
        return True
    return source.startswith(".") and source.endswith("/main.dart")


def find_main_importers(root: Path) -> set[str]:
    importers: set[str] = set()
    for source_root in ("lib", "test"):
        directory = root / source_root
        if not directory.exists():
            continue
        for dart_file in sorted(directory.rglob("*.dart")):
            rel = dart_file.relative_to(root).as_posix()
            if rel == "lib/main.dart":
                continue
            text = dart_file.read_text(encoding="utf-8", errors="ignore")
            if any(_imports_app_main(match) for match in _IMPORT_RE.findall(text)):
                importers.add(rel)
    return importers


def validate_main_entrypoint(root: Path) -> list[str]:
    path = root / "lib" / "main.dart"
    if not path.exists():
        return ["lib/main.dart is missing"]

    text = path.read_text(encoding="utf-8", errors="ignore")
    errors: list[str] = []
    line_count = len(text.splitlines())
    imports = set(_IMPORT_RE.findall(text))

    if line_count > _MAX_MAIN_LINES:
        errors.append(
            f"lib/main.dart grew to {line_count} lines (max {_MAX_MAIN_LINES})"
        )

    unexpected_imports = sorted(imports - _ALLOWED_MAIN_IMPORTS)
    if unexpected_imports:
        errors.append(
            "lib/main.dart has unexpected runtime imports: "
            + ", ".join(unexpected_imports)
        )

    if _REQUIRED_MAIN not in text:
        errors.append("lib/main.dart no longer delegates directly to bootstrapPrestoApp")

    if _FORBIDDEN_ENTRYPOINT_DECLARATION_RE.search(text):
        errors.append("lib/main.dart must not declare classes, enums or typedefs")

    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    entrypoint_errors = validate_main_entrypoint(root)
    importers = find_main_importers(root)
    unexpected = sorted(importers - _ALLOWED_MAIN_IMPORTERS)
    stale = sorted(_ALLOWED_MAIN_IMPORTERS - importers)

    if entrypoint_errors or unexpected or stale:
        print("Flutter entrypoint coupling guardrail: FAIL")
        for error in entrypoint_errors:
            print(f"- {error}")
        if unexpected:
            print("New imports of lib/main.dart are forbidden:")
            for path in unexpected:
                print(f"- {path}")
        if stale:
            print("Shrink the transitional allowlist; these files are now decoupled:")
            for path in stale:
                print(f"- {path}")
        return 1

    print(
        "Flutter entrypoint coupling guardrail: OK "
        f"({len(importers)} transitional importer(s) remain; "
        f"main.dart <= {_MAX_MAIN_LINES} lines; tests decoupled)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
