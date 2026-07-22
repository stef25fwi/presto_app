#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("coverage_agent.py")
SPEC = importlib.util.spec_from_file_location("coverage_agent", MODULE_PATH)
assert SPEC and SPEC.loader
coverage_agent = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = coverage_agent
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

    def test_selects_one_target_per_priority_domain(self) -> None:
        fixture = """TN:
SF:/repo/lib/services/payment_service.dart
DA:1,0
DA:2,0
end_of_record
TN:
SF:/repo/lib/pages/publish_offer_page.dart
DA:10,1
DA:11,0
end_of_record
TN:
SF:/repo/lib/messaging/chat_service.dart
DA:20,0
end_of_record
TN:
SF:/repo/lib/pages/admin_dashboard.dart
DA:30,0
DA:31,0
end_of_record
TN:
SF:/repo/lib/services/auth_service.dart
DA:40,0
end_of_record
TN:
SF:/repo/lib/services/unrelated_service.dart
DA:50,0
end_of_record
"""
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "lcov.info"
            report.write_text(fixture, encoding="utf-8")
            records = coverage_agent.parse_lcov(report)

        selected = coverage_agent.choose_targets_by_category(records)

        self.assertEqual(
            [
                "payments",
                "authentication",
                "publication",
                "messaging",
                "administration",
            ],
            [target.category for target in selected],
        )
        self.assertNotIn("other", [target.category for target in selected])

    def test_selects_lowest_covered_file_inside_a_domain(self) -> None:
        fixture = """TN:
SF:/repo/lib/pages/publish_offer_page.dart
DA:1,1
DA:2,0
end_of_record
TN:
SF:/repo/lib/services/offer_publication_service.dart
DA:10,0
DA:11,0
DA:12,0
end_of_record
"""
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "lcov.info"
            report.write_text(fixture, encoding="utf-8")
            records = coverage_agent.parse_lcov(report)

        selected = coverage_agent.choose_targets_by_category(records)

        self.assertEqual(1, len(selected))
        self.assertEqual(
            "lib/services/offer_publication_service.dart",
            selected[0].path,
        )

    def test_loads_five_critical_modules_at_100_percent(self) -> None:
        payload = {
            "modules": [
                {
                    "id": "authentication",
                    "label": "Authentification",
                    "patterns": ["lib/pages/auth/**"],
                    "target_percent": 100,
                },
                {
                    "id": "subscriptions_payment",
                    "label": "Abonnements et paiement",
                    "patterns": ["lib/features/subscriptions/**"],
                    "target_percent": 100,
                },
                {
                    "id": "offer_publication",
                    "label": "Publication d'annonces",
                    "patterns": ["lib/pages/publish_offer_page.dart"],
                    "target_percent": 100,
                },
                {
                    "id": "messaging",
                    "label": "Messagerie",
                    "patterns": ["lib/pages/messages/**"],
                    "target_percent": 100,
                },
                {
                    "id": "administration",
                    "label": "Administration",
                    "patterns": ["lib/pages/admin/**"],
                    "target_percent": 100,
                },
                {
                    "id": "entrepreneur_journey",
                    "label": "Parcours entrepreneur",
                    "patterns": ["lib/pages/toolbox_*.dart"],
                    "target_percent": 85,
                },
            ]
        }
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "critical.json"
            config.write_text(json.dumps(payload), encoding="utf-8")
            rules = coverage_agent.load_critical_rules(config)

        self.assertEqual(
            [
                "payments",
                "authentication",
                "publication",
                "messaging",
                "administration",
            ],
            [rule.category for rule in rules],
        )
        self.assertTrue(all(rule.target_percent == 100 for rule in rules))

    def test_exact_patterns_drive_classification(self) -> None:
        rule = coverage_agent.CriticalRule(
            module_id="offer_publication",
            label="Publication",
            category="publication",
            category_rank=2,
            patterns=("lib/special/flow.dart",),
            target_percent=100,
        )
        self.assertEqual(
            ("publication", 2),
            coverage_agent.classify("lib/special/flow.dart", (rule,)),
        )

    def test_critical_status_requires_every_lane_to_reach_target(self) -> None:
        rules = (
            coverage_agent.CriticalRule(
                "subscriptions_payment",
                "Paiement",
                "payments",
                0,
                ("lib/payment.dart",),
                100,
            ),
            coverage_agent.CriticalRule(
                "authentication",
                "Authentification",
                "authentication",
                1,
                ("lib/auth.dart",),
                100,
            ),
        )
        records = [
            coverage_agent.FileCoverage(
                "lib/payment.dart", 2, 2, [], "payments", 0
            ),
            coverage_agent.FileCoverage(
                "lib/auth.dart", 2, 1, [2], "authentication", 1
            ),
        ]

        status = coverage_agent.build_critical_status(records, rules)

        self.assertTrue(status[0]["target_reached"])
        self.assertFalse(status[1]["target_reached"])

    def test_classifies_administration_files(self) -> None:
        category, rank = coverage_agent.classify(
            "lib/pages/admin/widgets/moderation_dashboard.dart"
        )
        self.assertEqual("administration", category)
        self.assertEqual(4, rank)

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
        self.assertEqual(
            "1-3, 7, 9-10",
            coverage_agent.compact_ranges([1, 2, 3, 7, 9, 10]),
        )


if __name__ == "__main__":
    unittest.main()
