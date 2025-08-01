#!/usr/bin/env python3
"""Compute coding hours for the current repository using git-hours.

The script determines the repository root, runs ``git-hours`` there (optionally
passing a start date via the ``WINDOW_START`` environment variable), and writes
``reports/git-hours-<date>.json`` with the results.
"""
import json
import os
import pathlib
import subprocess
import datetime

SINCE = os.getenv("WINDOW_START", "")


def repo_root() -> pathlib.Path:
    """Return the path to the repository root via ``git rev-parse``."""
    out = subprocess.check_output([
        "git",
        "rev-parse",
        "--show-toplevel",
    ], text=True)
    return pathlib.Path(out.strip())


def run_git_hours(path: pathlib.Path) -> dict:
    """Run ``git-hours`` in the given directory and return parsed JSON output."""
    cmd = ["git-hours"]
    if SINCE:
        cmd.extend(["-since", SINCE])
    out = subprocess.check_output(cmd, cwd=path, text=True)
    return json.loads(out)


def main() -> None:
    root = repo_root()
    data = run_git_hours(root)
    date = datetime.date.today().isoformat()
    reports = root / "reports"
    reports.mkdir(exist_ok=True)
    (reports / f"git-hours-{date}.json").write_text(json.dumps(data, indent=2))
    print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
