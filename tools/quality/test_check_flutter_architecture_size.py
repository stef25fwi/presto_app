#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name('check_flutter_architecture_size.py')
SPEC = importlib.util.spec_from_file_location('architecture_size', MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
architecture_size = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = architecture_size
SPEC.loader.exec_module(architecture_size)


class FlutterArchitectureSizeTest(unittest.TestCase):
    config = {
        'budgets': {'screen_max_lines': 500, 'widget_max_lines': 250},
        'baseline_exceptions': {},
        'ignored_paths': [],
    }

    def _git(self, root: Path, *args: str) -> None:
        subprocess.run(
            ['git', *args],
            cwd=root,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def _screen(self, lines: int, class_name: str = 'LegacyPage') -> str:
        content = [
            "import 'package:flutter/widgets.dart';",
            f'class {class_name} extends StatelessWidget {{',
            f'  const {class_name}({{super.key}});',
            '  @override',
            '  Widget build(BuildContext context) => const SizedBox.shrink();',
            '}',
        ]
        content.extend('// legacy line' for _ in range(lines - len(content)))
        return '\n'.join(content) + '\n'

    def _repository(self) -> tuple[tempfile.TemporaryDirectory[str], Path]:
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        (root / 'lib/pages').mkdir(parents=True)
        self._git(root, 'init', '-b', 'main')
        self._git(root, 'config', 'user.name', 'Architecture Test')
        self._git(root, 'config', 'user.email', 'architecture@example.test')
        return temp, root

    def _commit_all(self, root: Path, message: str) -> None:
        self._git(root, 'add', '-A')
        self._git(root, 'commit', '-m', message)

    def test_legacy_file_may_shrink_without_manual_exception(self) -> None:
        temp, root = self._repository()
        self.addCleanup(temp.cleanup)
        target = root / 'lib/pages/legacy_page.dart'
        target.write_text(self._screen(600), encoding='utf-8')
        self._commit_all(root, 'base')
        self._git(root, 'switch', '-c', 'feature')
        target.write_text(self._screen(590), encoding='utf-8')
        self._commit_all(root, 'shrink legacy screen')

        findings = architecture_size.scan(
            root,
            self.config,
            changed_only=True,
            base_ref='main',
        )

        self.assertEqual(findings, [])

    def test_legacy_file_growth_is_blocked_at_base_size(self) -> None:
        temp, root = self._repository()
        self.addCleanup(temp.cleanup)
        target = root / 'lib/pages/legacy_page.dart'
        target.write_text(self._screen(600), encoding='utf-8')
        self._commit_all(root, 'base')
        self._git(root, 'switch', '-c', 'feature')
        target.write_text(self._screen(610), encoding='utf-8')
        self._commit_all(root, 'grow legacy screen')

        findings = architecture_size.scan(
            root,
            self.config,
            changed_only=True,
            base_ref='main',
        )

        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].limit, 600)
        self.assertEqual(
            findings[0].reason,
            'legacy file grew above its base-branch size',
        )

    def test_new_oversized_file_remains_blocked(self) -> None:
        temp, root = self._repository()
        self.addCleanup(temp.cleanup)
        seed = root / 'lib/pages/seed_page.dart'
        seed.write_text(self._screen(20, 'SeedPage'), encoding='utf-8')
        self._commit_all(root, 'base')
        self._git(root, 'switch', '-c', 'feature')
        target = root / 'lib/pages/new_page.dart'
        target.write_text(self._screen(600, 'NewPage'), encoding='utf-8')
        self._commit_all(root, 'add oversized screen')

        findings = architecture_size.scan(
            root,
            self.config,
            changed_only=True,
            base_ref='main',
        )

        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].path, 'lib/pages/new_page.dart')
        self.assertEqual(findings[0].limit, 500)
        self.assertEqual(findings[0].reason, 'new oversized Flutter file')


if __name__ == '__main__':
    unittest.main()
