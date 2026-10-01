#!/usr/bin/env python3
"""Read-only metadata collection. Never accesses a secret version or key string.

Output is a draft, not an attestation. Owners, rotation and mobile signatures
must be reconciled by the operator before updating security-controls.json.
"""
import argparse
import datetime
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
PROJECT = "presto-app-74abe"
REPO = "stef25fwi/presto_app"


def command_json(args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise RuntimeError("metadata command failed; check CLI authentication and read permissions")
        return json.loads(result.stdout)
    except FileNotFoundError:
        raise RuntimeError("required CLI unavailable") from None
    except (json.JSONDecodeError, subprocess.TimeoutExpired):
        raise RuntimeError("metadata command returned invalid JSON or timed out") from None


def project_resource(name):
    return isinstance(name, str) and re.fullmatch(r"projects/[^/]+/(?:locations/global/keys|secrets)/[^/]+", name)


def key_metadata(raw):
    # Explicit projection prevents a future API response from exporting keyString.
    restrictions = raw.get("restrictions") or {}
    allowed_fields = {
        "browserKeyRestrictions": ("allowedReferrers",),
        "androidKeyRestrictions": ("allowedApplications",),
        "iosKeyRestrictions": ("allowedBundleIds",),
        "serverKeyRestrictions": ("allowedIps",),
    }
    safe = {}
    for kind, fields in allowed_fields.items():
        value = restrictions.get(kind)
        if isinstance(value, dict):
            safe[kind] = {k: value[k] for k in fields if k in value}
            if kind == "androidKeyRestrictions":
                safe[kind]["allowedApplications"] = [
                    {k: app[k] for k in ("packageName", "sha1Fingerprint") if k in app}
                    for app in value.get("allowedApplications", []) if isinstance(app, dict)
                ]
    safe["apiTargets"] = [{"service": x.get("service"), "methods": x.get("methods", [])}
                          for x in restrictions.get("apiTargets", []) if isinstance(x, dict)]
    return {k: raw.get(k) for k in ("name", "displayName", "createTime", "updateTime")} | {"restrictions": safe}


def source_inventory():
    functions, github = set(), set()
    paths = [ROOT / "functions/index.js", *sorted((ROOT / "functions/src").rglob("*.ts"))]
    for path in paths:
        if path.name.endswith(".test.ts"):
            continue
        functions.update(re.findall(r"defineSecret\([\"']([A-Z0-9_]+)[\"']\)", path.read_text()))
    for path in sorted((ROOT / ".github/workflows").glob("*.y*ml")):
        github.update(re.findall(r"secrets\.([A-Z][A-Z0-9_]+)", path.read_text()))
    github.discard("GITHUB_TOKEN")  # ephemeral token issued for each job
    return {"secretManagerReferences": sorted(functions), "githubReferences": sorted(github)}


def secret_metadata(raw, versions):
    return {"name": raw.get("name"), "createTime": raw.get("createTime"),
            "ownerLabel": (raw.get("labels") or {}).get("owner"),
            "versions": [{k: v.get(k) for k in ("name", "state", "createTime")} for v in versions],
            "lastRotationConfirmed": None}  # createTime is not provider-side revocation


def collect(include_github=False):
    output = {"schemaVersion": 1, "project": PROJECT, "repository": REPO,
              "collectedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "status": "draft", "sourceInventory": source_inventory(),
              "apiKeys": [], "secrets": [], "githubSecretMetadata": [], "errors": []}
    try:
        keys = command_json(["gcloud", "services", "api-keys", "list", f"--project={PROJECT}",
                             "--format=json(name,displayName,restrictions,createTime,updateTime)"])
        if not isinstance(keys, list) or not keys:
            raise RuntimeError("no API keys returned; inventory completeness unverified")
        for raw in keys:
            if not project_resource(raw.get("name")):
                raise RuntimeError("invalid key resource")
            detail = command_json(["gcloud", "services", "api-keys", "describe", raw["name"],
                                   f"--project={PROJECT}", "--format=json(name,displayName,restrictions,createTime,updateTime)"])
            output["apiKeys"].append(key_metadata(detail))
    except RuntimeError as error:
        output["errors"].append({"scope": "api-keys", "reason": str(error)})
    try:
        secrets = command_json(["gcloud", "secrets", "list", f"--project={PROJECT}",
                                "--format=json(name,createTime,labels)"])
        if not isinstance(secrets, list) or not secrets:
            raise RuntimeError("no secrets returned; inventory completeness unverified")
        for raw in secrets:
            if not project_resource(raw.get("name")):
                raise RuntimeError("invalid secret resource")
            try:
                versions = command_json(["gcloud", "secrets", "versions", "list", raw["name"],
                                         f"--project={PROJECT}", "--format=json(name,state,createTime)"])
                output["secrets"].append(secret_metadata(raw, versions))
            except RuntimeError as error:
                output["errors"].append({"scope": "secret-versions", "resource": raw["name"], "reason": str(error)})
    except RuntimeError as error:
        output["errors"].append({"scope": "secrets", "reason": str(error)})
    if include_github:
        # gh requires permission to list secret metadata; never asks for values.
        scopes = [f"repos/{REPO}/actions/secrets"]
        try:
            pages = command_json(["gh", "api", "--paginate", "--slurp", f"repos/{REPO}/environments"])
            for page in pages:
                for environment in page.get("environments", []):
                    scopes.append(f"repos/{REPO}/environments/{quote(environment['name'], safe='')}/secrets")
        except RuntimeError as error:
            output["errors"].append({"scope": "github-environments", "reason": str(error)})
        for scope in scopes:
            try:
                pages = command_json(["gh", "api", "--paginate", "--slurp", scope])
                for page in pages:
                    for raw in page.get("secrets", []):
                        output["githubSecretMetadata"].append({"scope": scope,
                            **{k: raw.get(k) for k in ("name", "created_at", "updated_at")},
                            "lastRotationConfirmed": None})
            except RuntimeError as error:
                output["errors"].append({"scope": scope, "reason": str(error)})
    else:
        output["errors"].append({"scope": "github", "reason": "metadata not collected; use --github with authenticated gh"})
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--github", action="store_true")
    parser.add_argument("--out", default=str(ROOT / "quality_reports/security-external/metadata.json"))
    args = parser.parse_args()
    result = collect(args.github)
    target = Path(args.out)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(f"Metadata draft written: {target}; unresolved collection scopes: {len(result['errors'])}")
    print("No control status changed. Confirm owners, rotations and key restrictions before attestation.")
    return 2 if result["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
