#!/usr/bin/env python3
"""Generate KPI site from git-hours JSON files."""
import json, datetime, pathlib, html, textwrap, os, glob, sys

def main(agg_path: str, tmp_dir: str, date: str) -> None:
    data = json.load(open(agg_path))
    total = data['total']

    labels = [html.escape(k) for k in data if k != 'total']
    rows = "\n".join(
        f"<tr><td>{l}</td><td>{data[l]['hours']}</td><td>{data[l]['commits']}</td></tr>"
        for l in labels
    )

    sections = []
    pattern = os.path.join(tmp_dir, f"git-hours-*-{date}.json")
    for path in glob.glob(pattern):
        if 'aggregated' in path:
            continue
        repo_enc = pathlib.Path(path).stem.split(f'-{date}')[0][10:]
        repo = repo_enc.replace('_', '/')
        repo_data = json.load(open(path))
        repo_labels = [html.escape(k) for k in repo_data if k != 'total']
        repo_rows = "\n".join(
            f"<tr><td>{l}</td><td>{repo_data[l]['hours']}</td><td>{repo_data[l]['commits']}</td></tr>"
            for l in repo_labels
        )
        sections.append(
            f"<h2>{repo}</h2><table class='sortable'>"
            f"<thead><tr><th>Contributor</th><th>Hours</th><th>Commits</th></tr></thead>"
            f"<tbody>{repo_rows}</tbody></table>"
        )

    page = f"""
    <!doctype html><html lang='en'><head>
      <meta charset='utf-8'>
      <title>Collaborator KPIs</title>
      <link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/simpledotcss/simple.min.css'>
      <script src='https://cdn.jsdelivr.net/npm/sortable-tablesort/sortable.min.js' defer></script>
      <script src='https://cdn.jsdelivr.net/npm/chart.js'></script>
      <style>canvas{{max-height:400px}}</style>
    </head><body><main>
      <h1>Collaborator KPIs</h1>
      <p><em>Last updated {datetime.datetime.utcnow():%Y-%m-%d %H:%M UTC}</em></p>

      <h2>Totals (all repos)</h2>
      <ul>
        <li><strong>Hours</strong>: {total['hours']}</li>
        <li><strong>Commits</strong>: {total['commits']}</li>
        <li><strong>Contributors</strong>: {len(data)-1}</li>
      </ul>

      <h2>Hours per contributor</h2>
      <canvas id='hoursChart'></canvas>

      <h2>Detail table (all repos)</h2>
      <table class='sortable'>
        <thead><tr><th>Contributor</th><th>Hours</th><th>Commits</th></tr></thead>
        <tbody>{rows}</tbody>
      </table>

      {''.join(sections)}

      <p>Historical JSON snapshots live in <code>/data</code>.</p>

      <script>
        fetch('git-hours-latest.json')
          .then(r => r.json())
          .then(d => {{
            const labels = Object.keys(d).filter(k => k !== 'total');
            const hours  = labels.map(l => d[l].hours);
            new Chart(document.getElementById('hoursChart'), {{
              type: 'bar',
              data: {{ labels, datasets:[{{label:'Hours',data:hours}}] }},
              options: {{
                responsive:true, maintainAspectRatio:false,
                plugins:{{legend:{{display:false}}}},
                scales:{{y:{{beginAtZero:true}}}}
              }}
            }});
          }});
      </script>
    </main></body></html>
    """
    pathlib.Path('site').mkdir(exist_ok=True)
    pathlib.Path('site/index.html').write_text(textwrap.dedent(page))

if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit('Usage: build_org_kpi_site.py <aggregated-json> <tmp-dir> <date>')
    main(sys.argv[1], sys.argv[2], sys.argv[3])
