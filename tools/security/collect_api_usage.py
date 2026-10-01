"""Read-only seven-day API usage headers; never reads API key or secret values."""

import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

PROJECT = "presto-app-74abe"
SERVICES = (
    "generativelanguage.googleapis.com",
    "places-backend.googleapis.com",
    "speech.googleapis.com",
    "static-maps-backend.googleapis.com",
)
UUID = re.compile(r"(?<![a-zA-Z0-9])[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}(?![a-zA-Z0-9])")


def credential_identifier(value):
    """Export a UUID if available, otherwise a stable opaque correlation ID."""
    value = str(value or "")
    match = UUID.search(value)
    if match:
        return match.group(0)
    return "opaque:" + hashlib.sha256(value.encode()).hexdigest()[:16] if value else "unreported"


def usage_rows(series):
    rows = set()
    for item in series:
        resource = item.get("resource", {})
        labels = resource.get("labels", {})
        if resource.get("type") != "consumed_api" or labels.get("service") not in SERVICES:
            continue
        metric = item.get("metric", {}).get("labels", {})
        code = str(metric.get("response_code", ""))
        code_class = str(metric.get("response_code_class", ""))
        rows.add((labels["service"], credential_identifier(labels.get("credential_id")),
                  code if re.fullmatch(r"[1-5][0-9]{2}", code) else "unreported",
                  code_class if re.fullmatch(r"[1-5]xx", code_class) else "unreported"))
    return [dict(zip(("service", "credentialId", "responseCode", "responseClass"), row))
            for row in sorted(rows)]


def collect_pages(fetch, params):
    rows = []
    while True:
        page = fetch(params)
        rows.extend(page.get("timeSeries", []))
        next_token = page.get("nextPageToken")
        if not next_token:
            return usage_rows(rows)
        params = dict(params, pageToken=next_token)


def main():
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=7)
    params = {
        "filter": 'metric.type="serviceruntime.googleapis.com/api/request_count" '
                  'AND resource.type="consumed_api" AND (' + " OR ".join(
                      f'resource.labels.service="{service}"' for service in SERVICES) + ")",
        "interval.startTime": start.isoformat(),
        "interval.endTime": end.isoformat(),
        "view": "HEADERS",
        "pageSize": "1000",
    }
    try:
        token = subprocess.check_output(
            ["gcloud", "auth", "print-access-token"], text=True, stderr=subprocess.DEVNULL,
            timeout=30).strip()
        if not token:
            raise ValueError("empty token")

        def fetch(query):
            request = Request(
                f"https://monitoring.googleapis.com/v3/projects/{PROJECT}/timeSeries?" + urlencode(query),
                headers={"Authorization": f"Bearer {token}"})
            with urlopen(request, timeout=30) as response:
                return json.load(response)

        rows = collect_pages(fetch, params)
    except HTTPError as error:
        print(f"Monitoring metadata collection failed (HTTP {error.code}); no control changed.", file=sys.stderr)
        return 2
    except (URLError, OSError, subprocess.SubprocessError, ValueError):
        print("Monitoring metadata collection failed; no control changed.", file=sys.stderr)
        return 2
    print(json.dumps({"project": PROJECT, "startTime": start.isoformat(),
                      "endTime": end.isoformat(), "usageHeaders": rows,
                      "note": "Headers only, no request counts. Empty or missing data does not prove absence of usage."
                      }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
