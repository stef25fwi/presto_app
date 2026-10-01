import unittest
from unittest.mock import patch

import collect_api_usage as collector


def series(credential, code="403"):
    return {"resource": {"type": "consumed_api", "labels": {
        "service": collector.SERVICES[0], "credential_id": credential}},
        "metric": {"labels": {"response_code": code, "response_code_class": code[0] + "xx"}},
        "payload": "synthetic-private-payload"}


class UsageSafetyTest(unittest.TestCase):
    def test_only_metadata_is_exported_and_unknown_credentials_are_hashed(self):
        result = collector.usage_rows([series("synthetic-private-value")])
        self.assertNotIn("synthetic-private", str(result))
        self.assertTrue(result[0]["credentialId"].startswith("opaque:"))

    def test_key_uuid_and_success_and_failure_are_retained(self):
        key = "83512e8a-3c39-496f-b3a8-1dbddacdf97e"
        result = collector.usage_rows([series("apikey:" + key, "200"), series(key, "403")])
        self.assertEqual({r["responseCode"] for r in result}, {"200", "403"})
        self.assertEqual({r["credentialId"] for r in result}, {key})

    def test_all_pages_are_read_and_duplicate_headers_removed(self):
        calls = []

        def fetch(params):
            calls.append(dict(params))
            return {"timeSeries": [series("fixture")], **({"nextPageToken": "next"} if len(calls) == 1 else {})}

        self.assertEqual(len(collector.collect_pages(fetch, {"view": "HEADERS"})), 1)
        self.assertEqual(calls[1]["pageToken"], "next")

    def test_auth_failure_does_not_print_stderr_or_exception(self):
        with patch.object(collector.subprocess, "check_output", side_effect=OSError("synthetic-private-value")), \
             patch("sys.stderr") as stderr:
            self.assertEqual(collector.main(), 2)
        self.assertNotIn("synthetic-private-value", str(stderr.write.call_args_list))


if __name__ == "__main__":
    unittest.main()
