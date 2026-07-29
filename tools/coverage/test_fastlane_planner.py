from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fastlane_planner import (
    build_candidates,
    build_packs,
    minimum_pack_gain,
    parse_lcov,
    plan_to_dict,
)


class FastLanePlannerTest(unittest.TestCase):
    def test_ranks_testable_logic_above_hard_firebase_code(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ("lib/models", "lib/services", "lib/widgets"):
                (root / folder).mkdir(parents=True, exist_ok=True)
            (root / "lib/models/order.dart").write_text(
                "class Order { factory Order.fromData(Map<String, Object?> v) => Order(); }",
                encoding="utf-8",
            )
            (root / "lib/services/firestore_service.dart").write_text(
                "final db = FirebaseFirestore.instance;\n" * 8,
                encoding="utf-8",
            )
            (root / "lib/widgets/payment_card.dart").write_text(
                "class PaymentCard extends StatelessWidget { const PaymentCard(); }",
                encoding="utf-8",
            )
            lcov = root / "lcov.info"
            lcov.write_text(
                "\n".join(
                    [
                        "SF:lib/models/order.dart", "LF:40", "LH:10", "DA:1,0", "end_of_record",
                        "SF:lib/services/firestore_service.dart", "LF:70", "LH:10", "DA:1,0", "end_of_record",
                        "SF:lib/widgets/payment_card.dart", "LF:35", "LH:5", "DA:1,0", "end_of_record",
                    ]
                ),
                encoding="utf-8",
            )
            records, hit, found = parse_lcov(lcov)
            candidates = build_candidates(records, root, min_missing=5)
            self.assertEqual((hit, found), (25, 145))
            model = next(item for item in candidates if item.path.endswith("order.dart"))
            firebase = next(item for item in candidates if item.path.endswith("firestore_service.dart"))
            self.assertGreater(model.testability, firebase.testability)
            self.assertGreater(model.score, 0)

    def test_builds_two_non_overlapping_high_yield_packs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in (
                "lib/models/a.dart",
                "lib/models/b.dart",
                "lib/widgets/c.dart",
                "lib/services/d.dart",
            ):
                full = root / path
                full.parent.mkdir(parents=True, exist_ok=True)
                full.write_text("class X { X.fromData(); }", encoding="utf-8")
            lcov = root / "lcov.info"
            lines: list[str] = []
            for path, lines_found, lines_hit in (
                ("lib/models/a.dart", 60, 10),
                ("lib/models/b.dart", 40, 10),
                ("lib/widgets/c.dart", 50, 20),
                ("lib/services/d.dart", 45, 15),
            ):
                lines += [
                    f"SF:{path}",
                    f"LF:{lines_found}",
                    f"LH:{lines_hit}",
                    "DA:1,0",
                    "end_of_record",
                ]
            lcov.write_text("\n".join(lines), encoding="utf-8")
            records, hit, found = parse_lcov(lcov)
            candidates = build_candidates(records, root, min_missing=5)
            packs = build_packs(candidates, 2, 4, 25)
            self.assertLessEqual(len(packs), 2)
            selected = [file.path for pack in packs for file in pack.files]
            self.assertEqual(len(selected), len(set(selected)))
            self.assertTrue(all(pack.expected_gain >= 25 for pack in packs))
            self.assertEqual(plan_to_dict(hit, found, candidates, packs)["policy"]["max_lanes"], 2)

    def test_threshold_drops_only_near_target(self) -> None:
        self.assertEqual(minimum_pack_gain(51.0), 25)
        self.assertEqual(minimum_pack_gain(82.0), 10)
        self.assertEqual(minimum_pack_gain(88.0), 2)


if __name__ == "__main__":
    unittest.main()
