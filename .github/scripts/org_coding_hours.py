#!/usr/bin/env python3
import json, os, pathlib, subprocess, tempfile, datetime, sys

REPOS = os.getenv("REPOS", "").split()
SINCE = os.getenv("WINDOW_START", "")

if not REPOS:
    sys.exit("REPOS env var must list repositories to process")

def run_git_hours(repo: str) -> dict:
    with tempfile.TemporaryDirectory() as temp:
        subprocess.run(
            ["git", "clone", f"https://github.com/{repo}.git", temp],
            check=True,
        )
        cmd = ["git-hours"]
        if SINCE:
            cmd.extend(["-since", SINCE])
        out = subprocess.check_output(cmd, cwd=temp, text=True)
        return json.loads(out)

def aggregate(results: list[dict]) -> dict:
    agg = {"total": {"hours": 0, "commits": 0}}
    for data in results:
        for email, rec in data.items():
            if email == "total":
                continue
            entry = agg.setdefault(email, {"hours": 0, "commits": 0})
            entry["hours"] += rec["hours"]
            entry["commits"] += rec["commits"]
            agg["total"]["hours"] += rec["hours"]
            agg["total"]["commits"] += rec["commits"]
    return agg

def main():
    results = {}
    for repo in REPOS:
        print(f"Processing {repo}")
        results[repo] = run_git_hours(repo)
    agg = aggregate(list(results.values()))
    date = datetime.date.today().isoformat()
    reports = pathlib.Path("reports")
    reports.mkdir(exist_ok=True)
    for repo, data in results.items():
        name = repo.replace('/', '_')
        (reports / f"git-hours-{name}-{date}.json").write_text(json.dumps(data, indent=2))
    (reports / f"git-hours-aggregated-{date}.json").write_text(json.dumps(agg, indent=2))
    print(json.dumps(agg, indent=2))

if __name__ == "__main__":
    main()
