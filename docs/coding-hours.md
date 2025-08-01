# Coding-hours Metrics

This page explains how the repository generates contributor hours and where the dashboard is published.

## How the workflow works

The **Coding-hours report** workflow runs weekly and can also be triggered manually. It leverages the [Org Coding Hours Action](https://github.com/LabVIEW-Community-CI-CD/org-coding-hours-action) to compute statistics and publish the results. It performs the following steps:

1. **Collect statistics** – The job checks out the repository and runs `git-hours` to calculate commit hours per contributor. The results are saved as `git-hours.json` and archived as a workflow artifact.
2. **Commit to metrics branch** – The JSON report and a `badge.json` file are committed to the `metrics` branch. Historical snapshots are stored under `reports/` in that branch.
3. **Build the KPIs site** – Using the JSON data, a simple HTML dashboard is generated under a `site/` directory. This directory is then uploaded as a Pages artifact.
4. **Deploy** – The site artifact is deployed to GitHub Pages so everyone can view the latest dashboard.

## Viewing the dashboard

After each successful run, the dashboard is published at:

```
https://ni.github.io/labview-icon-editor/
```

This page shows the most recent hours per contributor along with historical JSON data.

## Metrics branch and README refresh

The workflow pushes all reports to the separate `metrics` branch. A second workflow, **Refresh README contributor hours**, watches for completions of the report workflow. It pulls the latest JSON data from the metrics branch and updates the contributor table in `README.md` automatically.
