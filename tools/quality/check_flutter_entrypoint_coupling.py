#!/usr/bin/env python3
"""Guard the Flutter application entrypoint after Lot 2 decomposition.

`lib/main.dart` must remain a thin, export-free composition root. Production and
test code must import dedicated modules directly rather than the application
entrypoint, so any future coupling fails CI immediately.
"""

from __future__ import annotations

import re
from pathlib import Path


_IMPORT_RE = re.compile(r"^\s*import\s+['\"]([^'\"]+)['\"]", re.MULTILINE)
_EXPORT_RE = re.compile(r"^\s*export\s+['\"]([^'\"]+)['\"]", re.MULTILINE)
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
    exports = sorted(set(_EXPORT_RE.findall(text)))

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

    if exports:
        errors.append(
            "lib/main.dart must not re-export application modules: "
            + ", ".join(exports)
        )

    if _REQUIRED_MAIN not in text:
        errors.append("lib/main.dart no longer delegates directly to bootstrapPrestoApp")

    if _FORBIDDEN_ENTRYPOINT_DECLARATION_RE.search(text):
        errors.append("lib/main.dart must not declare classes, enums or typedefs")

    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    entrypoint_errors = validate_main_entrypoint(root)
    importers = sorted(find_main_importers(root))

    if entrypoint_errors or importers:
        print("Flutter entrypoint coupling guardrail: FAIL")
        for error in entrypoint_errors:
            print(f"- {error}")
        if importers:
            print("Imports of lib/main.dart are forbidden:")
            for path in importers:
                print(f"- {path}")
        return 1

    print(
        "Flutter entrypoint coupling guardrail: OK "
        f"(0 importer(s); main.dart <= {_MAX_MAIN_LINES} lines; "
        "export-free; tests decoupled)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
