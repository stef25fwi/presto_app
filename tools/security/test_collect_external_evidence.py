import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("collector", Path(__file__).with_name("collect_external_evidence.py"))
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class CollectionSafetyTest(unittest.TestCase):
    def test_key_string_and_unknown_credentials_are_not_exported(self):
        result = collector.key_metadata({"name": "projects/test/locations/global/keys/id",
            "keyString": "synthetic-private-value", "credentials": "synthetic-private-value",
            "restrictions": {"token": "synthetic-private-value", "androidKeyRestrictions": {
                "allowedApplications": [{"packageName": "fr.ilipresto.app", "sha1Fingerprint": "fixture", "secret": "synthetic-private-value"}]}}})
        self.assertNotIn("synthetic-private-value", str(result))

    def test_version_dates_do_not_claim_provider_rotation(self):
        result = collector.secret_metadata({"name": "secret", "payload": "synthetic-private-value"},
            [{"name": "version", "createTime": "2026-09-30", "payload": "synthetic-private-value"}])
        self.assertIsNone(result["lastRotationConfirmed"])
        self.assertNotIn("synthetic-private-value", str(result))

    def test_failed_or_empty_collection_remains_a_draft(self):
        for value in ([], None):
            with patch.object(collector, "command_json", return_value=value):
                result = collector.collect()
            self.assertEqual(result["status"], "draft")
            self.assertEqual(len(result["errors"]), 3)

    def test_source_inventory_includes_places_key_and_excludes_runtime_token(self):
        result = collector.source_inventory()
        self.assertIn("GOOGLE_PLACES_API_KEY", result["secretManagerReferences"])
        self.assertNotIn("GITHUB_TOKEN", result["githubReferences"])


if __name__ == "__main__":
    unittest.main()
