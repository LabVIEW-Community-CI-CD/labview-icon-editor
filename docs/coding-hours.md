# Coding-hours Metrics

This page explains how the repository generates contributor hours and where the dashboard is published.

## How the workflow works

The **Coding-hours report** workflow runs weekly and can also be triggered manually. It leverages the [Org Coding Hours Action](https://github.com/LabVIEW-Community-CI-CD/org-coding-hours-action) to gather statistics across multiple repositories and publish the results. It performs the following steps:

1. **Collect statistics** – The job checks out all three repositories and runs `git-hours` to calculate commit hours per contributor. The aggregated report is saved as `git-hours-aggregated-<date>.json` and archived as a workflow artifact.
   The Org Coding Hours Action commits the reports to a dedicated `metrics` branch, so the workflow pulls them back from that branch before archiving.
2. **Build the KPIs site** – Using this aggregated data, a simple HTML dashboard is generated under a `site/` directory. This directory is then uploaded as a Pages artifact. The page includes a section for each repository in addition to organization-wide totals.
3. **Deploy** – The site artifact is deployed to GitHub Pages so everyone can view the latest dashboard covering all repositories.

## Viewing the dashboard

After each successful run, the dashboard is published at:

```
https://ni.github.io/labview-icon-editor/
```

This page shows the most recent hours per contributor along with historical JSON data for all repositories.

## README refresh

A second workflow, **Refresh README contributor hours**, watches for completions of the report workflow. It uses the aggregated JSON data to update the contributor table in `README.md` automatically.
