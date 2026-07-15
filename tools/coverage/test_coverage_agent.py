#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("coverage_agent.py")
SPEC = importlib.util.spec_from_file_location("coverage_agent", MODULE_PATH)
assert SPEC and SPEC.loader
coverage_agent = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(coverage_agent)


class CoverageAgentTest(unittest.TestCase):
    def test_prioritises_payments_before_authentication(self) -> None:
        fixture = """TN:
SF:/repo/lib/services/auth_service.dart
DA:10,0
DA:11,0
end_of_record
TN:
SF:/repo/lib/services/payment_service.dart
DA:20,1
DA:21,0
end_of_record
TN:
SF:/repo/lib/pages/unrelated_page.dart
DA:30,0
end_of_record
"""
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "lcov.info"
            report.write_text(fixture, encoding="utf-8")
            records = coverage_agent.parse_lcov(report)

        selected = coverage_agent.choose_target(records)
        self.assertEqual("payments", selected.category)
        self.assertEqual("lib/services/payment_service.dart", selected.path)
        self.assertEqual([21], selected.uncovered_lines)

    def test_excludes_generated_files(self) -> None:
        fixture = """TN:
SF:/repo/lib/models/user.g.dart
DA:1,0
end_of_record
TN:
SF:/repo/lib/messaging/chat_service.dart
DA:5,0
end_of_record
"""
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "lcov.info"
            report.write_text(fixture, encoding="utf-8")
            records = coverage_agent.parse_lcov(report)

        self.assertEqual(1, len(records))
        self.assertEqual("lib/messaging/chat_service.dart", records[0].path)

    def test_compacts_uncovered_ranges(self) -> None:
        self.assertEqual("1-3, 7, 9-10", coverage_agent.compact_ranges([1, 2, 3, 7, 9, 10]))


if __name__ == "__main__":
    unittest.main()
