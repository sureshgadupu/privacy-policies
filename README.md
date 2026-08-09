# privacy-policies

Repo for privacy policies of Android applications. Each app gets one page
(`<app-slug>-privacy-policy.html`) generated from a shared template, and every
page is linked from `index.html`.

## Adding a privacy policy for a new app

Fastest (no local setup): GitHub → Actions → **Create Privacy Policy** →
*Run workflow* → enter the app name → run. The workflow generates the page,
links it on `index.html`, and opens a pull request.

Locally (requires `git` + [GitHub CLI](https://cli.github.com), authenticated
via `gh auth login`, and a clean working tree):

```bash
# Linux / macOS / WSL
./scripts/create-privacy-policy.sh "App Display Name" [app|game]
```

```powershell
# Windows (PowerShell)
.\scripts\create-privacy-policy.ps1 -AppName "App Display Name" [-AppType game]
```

Both scripts:
1. Generate `<slug>-privacy-policy.html` from `privacy-policy-template.html`
2. Rebuild `index.html` (the link list is derived from the pages themselves,
   so it always stays complete and sorted)
3. Create branch `add-privacy-policy-<slug>`, commit, push, open a PR against
   `main`

`app` vs `game` only changes wording ("…app is developed… / …when you use the
… mobile application" vs "…game is developed… / …when you play the … mobile
game").

## Template placeholders

`privacy-policy-template.html` is the single source for new pages:

| Placeholder      | Meaning                                                        |
|------------------|----------------------------------------------------------------|
| `{{APP_NAME}}`   | Display name, e.g. `PDF Utilities`                             |
| `{{APP_TYPE}}`   | `app` or `game` (filled by the scripts, e.g. "The app uses…")  |
| `{{INTRO_ACTION}}` | `use` or `play` (derived from the app type)                  |
| `{{MOBILE_DESC}}`  | `mobile application` or `mobile game` (derived from type)    |

The scripts fill all placeholders automatically — you only supply the app
name (and optionally the type).

## Scripts

- `scripts/generate-privacy-policy.sh "App Name" [app|game] [custom-slug]` —
  generation only, no git operations. Rebuild just the index with
  `scripts/generate-privacy-policy.sh --rebuild-index` (also picks up any
  pages that were added by hand).
- `scripts/create-privacy-policy.sh` — Linux/macOS/WSL full flow (generate +
  branch + commit + push + PR).
- `scripts/create-privacy-policy.ps1` — Windows/PowerShell full flow.
- `.github/workflows/create-privacy-policy.yml` — same flow as a GitHub
  Action (workflow_dispatch with `app_name` / `app_type` inputs).

Note: the slug is derived from the app name (lowercase, non-alphanumeric
characters become `-`). Pass a third argument to the generate script for a
custom slug if the derived one is not what you want.
