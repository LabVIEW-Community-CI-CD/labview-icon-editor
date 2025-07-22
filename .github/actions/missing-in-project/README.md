# Missing‑In‑Project 💼🔍

Validate that **every file on disk that should live in a LabVIEW project
*actually* appears in the `.lvproj`.**  
The check is executed as the *first* step in your CI pipeline so the
run fails fast and you never ship a package or run a unit test with a
broken project file.

Internally the action launches the **`MissingInProjectCLI.vi`** utility
(checked into the same directory) through **g‑cli**.  
Results are returned as standard GitHub Action outputs so downstream jobs
can decide what to do next (for example, post a comment with the missing
paths).

---

## Table of Contents
1. [Prerequisites](#prerequisites)  
2. [Inputs](#inputs)  
3. [Outputs](#outputs)  
4. [Quick‑start](#quick-start)  
5. [Example: Fail‑fast workflow](#example-fail-fast-workflow)  
6. [How it works](#how-it-works)  
7. [Exit codes & failure modes](#exit-codes--failure-modes)  
8. [Troubleshooting](#troubleshooting)  
9. [Developing & testing locally](#developing--testing-locally)  
10. [License](#license)

---

## Prerequisites
| Requirement            | Notes |
|------------------------|-------|
| **Windows runner**     | LabVIEW and g‑cli are only available on Windows. |
| **LabVIEW** `>= 2020`  | Must match the *numeric* version you pass in **`lv-ver`**. |
| **g‑cli** in `PATH`    | The action calls `g-cli --lv-ver …`. Install from NI Package Manager or copy the executable into the runner image. |
| **PowerShell 7**       | Composite steps use PowerShell Core (`pwsh`). |

---

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `lv-ver` | **Yes** | `2021` | LabVIEW *major* version number that should be used to run `MissingInProjectCLI.vi` :contentReference[oaicite:0]{index=0} |
| `arch` | **Yes** | `32` or `64` | Bitness of the LabVIEW runtime to launch :contentReference[oaicite:1]{index=1} |
| `project-file` | No | `source/MyPlugin.lvproj` | Path (absolute or relative to repository root) of the project to inspect. Defaults to **`lv_icon.lvproj`** :contentReference[oaicite:2]{index=2} |

---

## Outputs
| Name | Type | Meaning |
|------|------|---------|
| `passed` | `true \| false` | `true` when *no* missing files were detected and the VI ran without error :contentReference[oaicite:3]{index=3} |
| `missing-files` | `string` | Comma‑separated list of *relative* paths that are absent from the project (empty on success) :contentReference[oaicite:4]{index=4} |

---

## Quick start
```yaml
# .github/workflows/ci.yml  (excerpt)
jobs:
  prepare:
    runs-on: self-hosted-windows-lv
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Verify no files are missing from the project
        id: mip
        uses: ./.github/actions/missing-in-project
        with:
          lv-ver: 2021          # LabVIEW major version installed on runner
          arch: 64             # 32 or 64
          # project-file:      # optional override

      # use the output in later steps if you wish
      - name: Print report
        if: ${{ steps.mip.outputs.passed == 'false' }}
        run: echo "Missing: ${{ steps.mip.outputs['missing-files'] }}"
```
