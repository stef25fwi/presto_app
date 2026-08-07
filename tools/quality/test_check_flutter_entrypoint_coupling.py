#!/usr/bin/env python3
"""Unit tests for the Flutter entrypoint coupling guardrail."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


_MODULE_PATH = Path(__file__).with_name("check_flutter_entrypoint_coupling.py")
_SPEC = importlib.util.spec_from_file_location("entrypoint_guard", _MODULE_PATH)
assert _SPEC is not None and _SPEC.loader is not None
_GUARD = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_GUARD)


class EntrypointCouplingGuardTests(unittest.TestCase):
    def _write(self, root: Path, relative_path: str, content: str) -> None:
        path = root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def _valid_main(self) -> str:
        return (
            "import 'app/presto_app.dart';\n"
            "import 'bootstrap/app_bootstrap.dart';\n\n"
            "Future<void> main() => bootstrapPrestoApp(const PrestoApp());\n"
        )

    def test_find_main_importers_scans_lib_and_test(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write(root, "lib/main.dart", self._valid_main())
            self._write(
                root,
                "lib/pages/legacy_page.dart",
                "import '../main.dart';\n",
            )
            self._write(
                root,
                "test/legacy_test.dart",
                "import 'package:presto_app/main.dart';\n",
            )
            self._write(
                root,
                "test/direct_page_test.dart",
                "import 'package:presto_app/pages/home_page.dart';\n",
            )

            self.assertEqual(
                _GUARD.find_main_importers(root),
                {
                    "lib/pages/legacy_page.dart",
                    "test/legacy_test.dart",
                },
            )

    def test_validate_main_entrypoint_accepts_thin_composition_root(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write(root, "lib/main.dart", self._valid_main())

            self.assertEqual(_GUARD.validate_main_entrypoint(root), [])

    def test_validate_main_entrypoint_rejects_runtime_growth(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            oversized_padding = "\n".join(f"// line {i}" for i in range(30))
            self._write(
                root,
                "lib/main.dart",
                (
                    "import 'app/presto_app.dart';\n"
                    "import 'bootstrap/app_bootstrap.dart';\n"
                    "import 'services/legacy_service.dart';\n"
                    "export 'pages/home_page.dart';\n\n"
                    "class LegacyRuntime {}\n\n"
                    "Future<void> main() => bootstrapPrestoApp(const PrestoApp());\n"
                    f"{oversized_padding}\n"
                ),
            )

            errors = _GUARD.validate_main_entrypoint(root)

            self.assertTrue(any("grew to" in error for error in errors))
            self.assertTrue(
                any("unexpected runtime imports" in error for error in errors)
            )
            self.assertTrue(
                any("must not re-export" in error for error in errors)
            )
            self.assertTrue(
                any("must not declare classes" in error for error in errors)
            )


if __name__ == "__main__":
    unittest.main()
