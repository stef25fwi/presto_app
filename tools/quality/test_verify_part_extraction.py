#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name('verify_part_extraction.py')
SPEC = importlib.util.spec_from_file_location('verify_part_extraction', MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
verify = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify
SPEC.loader.exec_module(verify)


class SignificantLinesTest(unittest.TestCase):
    def test_drops_part_directives_and_blanks(self) -> None:
        text = (
            "import 'a.dart';\n"
            "\n"
            "part 'sub/widgets.dart';\n"
            "class A {}\n"
        )
        self.assertEqual(
            verify.significant_lines(text),
            ["import 'a.dart';", 'class A {}'],
        )

    def test_drops_part_of_directive(self) -> None:
        text = "part of '../page.dart';\n\nclass B {}\n"
        self.assertEqual(verify.significant_lines(text), ['class B {}'])

    def test_preserves_indentation_so_edits_are_caught(self) -> None:
        self.assertEqual(
            verify.significant_lines('  final int a = 1;\n'),
            ['  final int a = 1;'],
        )


class DeclaredPartsTest(unittest.TestCase):
    def test_collects_every_declared_part_in_order(self) -> None:
        text = (
            "part 'x/one.dart';\n"
            "class A {}\n"
            "part 'x/two.dart';\n"
        )
        self.assertEqual(verify.declared_parts(text), ['x/one.dart', 'x/two.dart'])

    def test_ignores_part_of(self) -> None:
        self.assertEqual(verify.declared_parts("part of '../page.dart';\n"), [])


class CompareTest(unittest.TestCase):
    def test_pure_move_reports_nothing(self) -> None:
        before = ['class A {}', 'class B {}']
        after = ['class B {}', 'class A {}']
        self.assertEqual(verify.compare(before, after), [])

    def test_detects_an_edited_line(self) -> None:
        findings = verify.compare(['  final bool a;'], ['  final bool a; // edit'])
        self.assertEqual(len(findings), 2)
        self.assertTrue(any(f.startswith('  - perdue') for f in findings))
        self.assertTrue(any(f.startswith('  + ajoutée') for f in findings))

    def test_detects_a_dropped_line(self) -> None:
        findings = verify.compare(['class A {}', 'class B {}'], ['class A {}'])
        self.assertEqual(findings, ['  - perdue x1 : class B {}'])

    def test_detects_a_duplicated_line(self) -> None:
        findings = verify.compare(['x();'], ['x();', 'x();'])
        self.assertEqual(findings, ['  + ajoutée x1 : x();'])

    def test_counts_repeated_occurrences(self) -> None:
        findings = verify.compare(['a;', 'a;', 'a;'], ['a;'])
        self.assertEqual(findings, ['  - perdue x2 : a;'])


if __name__ == '__main__':
    unittest.main()
