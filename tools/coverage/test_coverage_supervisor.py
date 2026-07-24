from datetime import datetime, timezone
import unittest

from coverage_supervisor import supervise


NOW = datetime(2026, 7, 24, 12, tzinfo=timezone.utc)


class CoverageSupervisorTest(unittest.TestCase):
    def test_orphan_issue_does_not_consume_a_slot(self):
        issues = [{
            "number": 10,
            "title": "worker",
            "body": "Fichier de production : `lib/a.dart`\nBranche réservée : `coverage/w1-a`",
            "updatedAt": "2026-07-23T00:00:00Z",
        }]
        plan = supervise(issues, [], now=NOW, stale_hours=8, max_workers=4,
                         global_percent=50, target_percent=80)
        self.assertEqual(plan["available_slots"], 4)
        self.assertEqual(len(plan["orphaned_workers"]), 1)

    def test_recent_pr_consumes_one_slot(self):
        prs = [{
            "number": 20,
            "title": "coverage",
            "body": "",
            "headRefName": "coverage/w1-auth",
            "updatedAt": "2026-07-24T11:00:00Z",
        }]
        plan = supervise([], prs, now=NOW, stale_hours=8, max_workers=4,
                         global_percent=50, target_percent=80)
        self.assertEqual(plan["occupied_slots"], 1)
        self.assertEqual(plan["available_slots"], 3)

    def test_target_stops_new_workers(self):
        plan = supervise([], [], now=NOW, stale_hours=8, max_workers=4,
                         global_percent=80, target_percent=80)
        self.assertTrue(plan["target_reached"])
        self.assertEqual(plan["available_slots"], 0)


if __name__ == "__main__":
    unittest.main()
