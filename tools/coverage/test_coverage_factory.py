#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("coverage_factory.py")
SPEC = importlib.util.spec_from_file_location("coverage_factory", MODULE_PATH)
assert SPEC and SPEC.loader
coverage_factory = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = coverage_factory
SPEC.loader.exec_module(coverage_factory)


class CoverageFactoryTest(unittest.TestCase):
    def test_selects_two_distinct_priority_lanes(self) -> None:
        targets = [
            {"category": "messaging", "path": "lib/message.dart", "profitability": 8, "uncovered": 80},
            {"category": "payments", "path": "lib/payment.dart", "profitability": 3, "uncovered": 30},
            {"category": "authentication", "path": "lib/auth.dart", "profitability": 9, "uncovered": 90},
        ]
        selected = coverage_factory.pick_workers(targets, 2)
        self.assertEqual(["payments", "authentication"], [item["category"] for item in selected])

    def test_never_uses_two_targets_from_same_lane(self) -> None:
        targets = [
            {"category": "payments", "path": "lib/a.dart", "profitability": 10, "uncovered": 100},
            {"category": "payments", "path": "lib/b.dart", "profitability": 9, "uncovered": 90},
            {"category": "publication", "path": "lib/c.dart", "profitability": 1, "uncovered": 10},
        ]
        selected = coverage_factory.pick_workers(targets, 2)
        self.assertEqual(["payments", "publication"], [item["category"] for item in selected])

    def test_worker_payload_contains_fast_and_final_validation(self) -> None:
        payload = coverage_factory.worker_payload(
            1,
            {
                "category": "payments",
                "path": "lib/payment.dart",
                "percent": 40,
                "uncovered": 12,
                "uncovered_ranges": "10-21",
                "profitability": 4,
            },
        )
        self.assertEqual(100, payload["target_percent"])
        self.assertIn("flutter test <test-file>", payload["fast_commands"])
        self.assertIn("flutter test --coverage", payload["final_commands"])


if __name__ == "__main__":
    unittest.main()
