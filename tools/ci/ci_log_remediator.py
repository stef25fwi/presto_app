#!/usr/bin/env python3
"""Generate a narrowly-scoped repair patch from failed GitHub Actions logs."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any

from openai import OpenAI

DENIED_PREFIXES = (".github/", ".git/", "android/key", "ios/Runner/", "secrets/")
MAX_FILES = 3
MAX_PATCH_BYTES = 80_000


def candidate_files(log_text: str) -> list[str]:
    patterns = [
        r"(?P<path>(?:lib|test|integration_test|tool|tools)/[A-Za-z0-9_./-]+\.(?:dart|py|js|ts|json|yaml|yml))",
        r"(?P<path>pubspec\.yaml|analysis_options\.yaml)",
    ]
    found: list[str] = []
    for pattern in patterns:
        for match in re.finditer(pattern, log_text):
            path = match.group("path").rstrip(".:,;)")
            if path not in found and Path(path).is_file() and not path.startswith(DENIED_PREFIXES):
                found.append(path)
    return found[:8]


def read_context(paths: list[str]) -> str:
    chunks: list[str] = []
    for path in paths:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
        chunks.append(f"\n===== FILE {path} =====\n{text[:30000]}")
    return "".join(chunks)


def extract_json(text: str) -> dict[str, Any]:
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("model did not return a JSON object")
    return json.loads(text[start : end + 1])


def validate_patch(patch: str, allowed: set[str]) -> list[str]:
    if not patch.strip() or len(patch.encode()) > MAX_PATCH_BYTES:
        raise ValueError("empty or oversized patch")
    touched = re.findall(r"^\+\+\+ b/(.+)$", patch, flags=re.MULTILINE)
    touched = [p for p in touched if p != "/dev/null"]
    if not touched or len(set(touched)) > MAX_FILES:
        raise ValueError("patch touches an invalid number of files")
    for path in touched:
        if path not in allowed or path.startswith(DENIED_PREFIXES):
            raise ValueError(f"patch touches forbidden or unrelated file: {path}")
    return sorted(set(touched))


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--logs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--model", default=os.getenv("CI_REPAIR_MODEL", "gpt-5.1"))
    args = parser.parse_args()

    logs = args.logs.read_text(encoding="utf-8", errors="replace")[-60000:]
    files = candidate_files(logs)
    result: dict[str, Any] = {"status": "manual", "reason": "", "files": files}
    if not files:
        result["reason"] = "No safe repository file could be identified from the logs."
        args.output.write_text(json.dumps(result, indent=2) + "\n")
        return 2

    client = OpenAI()
    response = client.responses.create(
        model=args.model,
        store=False,
        input=[{
            "role": "user",
            "content": [{
                "type": "input_text",
                "text": (
                    "You are a conservative CI repair agent. Diagnose the failure and return ONLY JSON with "
                    "keys diagnosis, confidence (0..1), patch (unified git diff), validation_commands (array). "
                    "Modify at most 3 files and only files supplied below. Never modify workflows, permissions, "
                    "secrets, generated credentials, lockfiles, dependency versions, or weaken tests/checks. "
                    "Do not add skips, ignores, retries, sleeps, exclusions, or lower thresholds. If a safe fix "
                    "cannot be established, return an empty patch and confidence below 0.8.\n\n"
                    f"FAILED LOGS:\n{logs}\n\nALLOWED FILE CONTEXT:{read_context(files)}"
                ),
            }],
        }],
    )
    proposal = extract_json(response.output_text)
    confidence = float(proposal.get("confidence", 0))
    patch = str(proposal.get("patch", ""))
    result.update({"diagnosis": proposal.get("diagnosis", ""), "confidence": confidence})
    if confidence < 0.8 or not patch.strip():
        result.update(status="manual", reason="The proposed repair was not sufficiently reliable.")
        args.output.write_text(json.dumps(result, indent=2) + "\n")
        return 2

    touched = validate_patch(patch, set(files))
    patch_path = args.output.with_suffix(".patch")
    patch_path.write_text(patch, encoding="utf-8")
    run(["git", "apply", "--check", str(patch_path)])
    run(["git", "apply", str(patch_path)])
    result.update(status="patched", touched_files=touched, validation_commands=proposal.get("validation_commands", []))
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
