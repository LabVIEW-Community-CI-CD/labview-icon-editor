#!/usr/bin/env python3
"""
Refresh the contributor‑hours table in README.md.

Usage:
  python scripts/update_readme_hours.py  [<path-to-json>]

If <path-to-json> is omitted the script searches for the most recent
`git-hours-*.json` file under `reports/` or `site/data/` in the current
repository.
"""
import json, pathlib, re, sys
from collections import defaultdict

# ────────────────────────── identity normalisation ──────────────────────────
def load_aliases():
    """Return a dict {alias_email -> canonical_email}."""
    aliases = {}
    yaml_path = pathlib.Path("reports/email-aliases.yaml")
    if yaml_path.exists():
        import yaml
        for alias, canon in yaml.safe_load(yaml_path).items():
            aliases[alias.lower()] = canon.lower()

    # honour .mailmap too (same syntax as git, but we only need <mail>)
    mailmap = pathlib.Path(".mailmap")
    if mailmap.exists():
        for line in mailmap.read_text().splitlines():
            m = re.findall(r"<([^>]+)>", line)
            if len(m) >= 2:
                aliases[m[1].lower()] = m[0].lower()
    return aliases

ALIASES = load_aliases()

def canonical(addr: str) -> str:
    return ALIASES.get(addr.lower(), addr)

# ───────────────────────────── data ingestion ───────────────────────────────
def latest_json(path_hint: str | None = None) -> pathlib.Path:
    if path_hint:
        return pathlib.Path(path_hint)

    candidates = list(pathlib.Path("reports").glob("git-hours-*.json"))
    candidates += list(pathlib.Path("site/data").glob("git-hours-*.json"))

    if not candidates:
        sys.exit("❌  No git-hours report found.")

    candidates.sort()
    return candidates[-1]

def load_report(p: pathlib.Path) -> dict[str, dict]:
    return json.loads(p.read_text())

# ────────────────────────── markdown generation ─────────────────────────────
def make_table(data: dict) -> str:
    agg = defaultdict(float)
    for email, rec in data.items():
        if email == "total":
            continue
        agg[canonical(email)] += rec["hours"]
    rows = sorted(agg.items(), key=lambda r: r[1], reverse=True)
    header = "| Contributor | Hours |\n|-------------|-------|"
    body   = "\n".join(f"| {name} | {hours:.1f} |" for name, hours in rows)
    return f"{header}\n{body}\n"

def inject_readme(table_md: str):
    readme = pathlib.Path("README.md")
    txt = readme.read_text().splitlines()
    out, inside = [], False
    for line in txt:
        if line.strip() == "<!-- HOURS_START -->":
            inside = True
            out += [line, "", table_md.rstrip(), ""]
        elif line.strip() == "<!-- HOURS_END -->":
            inside = False
        if not inside:
            out.append(line)
    readme.write_text("\n".join(out))

# ───────────────────────────────── entrypoint ───────────────────────────────
def main():
    src = latest_json(sys.argv[1] if len(sys.argv) > 1 else None)
    data = load_report(src)
    inject_readme(make_table(data))

if __name__ == "__main__":
    main()
