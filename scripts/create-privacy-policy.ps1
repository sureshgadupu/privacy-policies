<#
.SYNOPSIS
    Adds a privacy policy page for a new Android app and opens a pull request.

.DESCRIPTION
    Generates "<slug>-privacy-policy.html" from privacy-policy-template.html,
    updates index.html, then creates a branch, commits, pushes, and opens a
    pull request via the GitHub CLI (gh).

.PARAMETER AppName
    Display name of the app, e.g. "PDF Utilities".

.PARAMETER AppType
    "app" or "game" (controls wording). Defaults to "app".

.EXAMPLE
    .\scripts\create-privacy-policy.ps1 -AppName "Turbo Racer" -AppType game

.REQUIREMENTS
    git, GitHub CLI (https://cli.github.com) authenticated, clean working tree.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$AppName,

    [Parameter(Position = 1)]
    [ValidateSet("app", "game")]
    [string]$AppType = "app"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root
try {
    # ---- preflight checks ----
    git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) { throw "Not inside a git repository." }

    git diff --quiet
    if ($LASTEXITCODE -ne 0) { throw "Working tree has uncommitted changes to tracked files. Commit or stash them first." }
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { throw "Working tree has staged changes. Commit or stash them first." }

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "GitHub CLI (gh) is required. Install: https://cli.github.com" }
    gh auth status *> $null
    if ($LASTEXITCODE -ne 0) { throw "Not authenticated with GitHub. Run: gh auth login" }

    # ---- derive wording ----
    $IntroAction = "use"
    $MobileDesc  = "mobile application"
    if ($AppType -eq "game") {
        $IntroAction = "play"
        $MobileDesc  = "mobile game"
    }

    # ---- slug + output file ----
    $Slug = ($AppName.ToLowerInvariant() -replace '[^a-z0-9]+', '-' -replace '^-+', '' -replace '-+$', '')
    if ([string]::IsNullOrWhiteSpace($Slug)) { throw "Could not derive a file slug from '$AppName'." }
    $OutFile = "$Slug-privacy-policy.html"

    $Template = Join-Path $Root "privacy-policy-template.html"
    if (-not (Test-Path $Template)) { throw "Template '$Template' not found in the repo root." }
    if (Test-Path (Join-Path $Root $OutFile)) { throw "'$OutFile' already exists. Refusing to overwrite it." }

    # ---- render template (CRLF, UTF-8 without BOM) ----
    $content = [System.IO.File]::ReadAllText($Template)
    $content = $content.Replace('{{APP_NAME}}', $AppName)
    $content = $content.Replace('{{APP_TYPE}}', $AppType)
    $content = $content.Replace('{{INTRO_ACTION}}', $IntroAction)
    $content = $content.Replace('{{MOBILE_DESC}}', $MobileDesc)
    $content = $content -replace "`r?`n", "`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Root $OutFile), $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Created $OutFile"

    if ($content -match '\{\{') { Write-Warning "'$OutFile' still contains un-replaced placeholders — check the template." }

    # ---- rebuild index.html from the existing pages ----
    $items = @(Get-ChildItem -Path $Root -Filter '*-privacy-policy.html' -File |
        Where-Object { $_.Name -ne 'privacy-policy-template.html' } |
        ForEach-Object {
            $m = [regex]::Match((Get-Content -Raw $_.FullName), '<h1>Privacy Policy for (.*?)</h1>')
            if ($m.Success) { $name = $m.Groups[1].Value.Trim() } else { $name = ($_.BaseName -replace '-privacy-policy$', '') -replace '-', ' ' }
            [pscustomobject]@{ Name = $name; File = $_.Name }
        } |
        Sort-Object Name)

    $header = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Android App Privacy Policies</title>
    <style>
        body { font-family: sans-serif; line-height: 1.6; margin: 20px; max-width: 800px; margin-left: auto; margin-right: auto; }
        h1, h2 { color: #333; }
        ul { list-style: none; padding: 0; }
        li { margin-bottom: 10px; }
        a { color: #007bff; text-decoration: none; font-size: 1.1em; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <header>
        <h1>Our Android App Privacy Policies</h1>
        <p>Welcome to our central hub for privacy policies for all our Android applications.</p>
    </header>

    <section>
        <h2>Select an App:</h2>
        <ul>
'@

    $footer = @'
        </ul>
    </section>

    <footer>
        <p>&copy; 2026 FullStackCode. All rights reserved.</p>
    </footer>
</body>
</html>
'@

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($header)
    foreach ($i in $items) {
        $lines.Add("            <li><a href=`"$($i.File)`">$($i.Name)</a></li>")
    }
    $lines.Add($footer)
    $index = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Root 'index.html'), $index, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Updated index.html ($($items.Count) policies linked)"

    # ---- branch / commit / push / PR ----
    $Branch = "add-privacy-policy-$Slug"
    git show-ref --verify --quiet "refs/heads/$Branch"
    if ($LASTEXITCODE -eq 0) { throw "Branch '$Branch' already exists." }

    git checkout -b $Branch
    git add -A
    git commit -m "Add privacy policy for $AppName"
    git push -u origin $Branch

    $Body = @"
Automated creation of the privacy policy page for **$AppName**.

- Adds ``$OutFile`` generated from ``privacy-policy-template.html``
- Adds a link on ``index.html``

Generated via ``scripts\create-privacy-policy.ps1`` (or the ``create-privacy-policy`` GitHub Action workflow).
"@

    gh pr create --title "Add privacy policy for $AppName" --body $Body --base main

    Write-Host ""
    Write-Host "Done: pull request opened for '$AppName'."
}
finally {
    Pop-Location
}
