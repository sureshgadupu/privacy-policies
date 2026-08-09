#!/usr/bin/env bash
#
# generate-privacy-policy.sh
#
# Generates "<slug>-privacy-policy.html" for a new Android app from the
# "privacy-policy-template.html" template, then rebuilds "index.html" so every
# policy page is linked. The index list is derived from the pages themselves
# (display name = the page's <h1>), so it stays in sync automatically.
#
# Usage:
#   scripts/generate-privacy-policy.sh "App Display Name" [app|game] [custom-slug]
#   scripts/generate-privacy-policy.sh --rebuild-index
#
#   app|game     controls wording: "app" -> "app is developed...", "when you
#                use the ... mobile application"; "game" -> "game is
#                developed...", "when you play the ... mobile game".
#                Default: app.
#   custom-slug  optional explicit file slug. Default: derived from the app
#                name (e.g. "PDF Utilities" -> "pdf-utilities").
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

TEMPLATE="privacy-policy-template.html"

# Escape a string for use inside a sed replacement (delimiter '|').
esc() { printf '%s' "$1" | sed 's/[\\|&]/\\&/g'; }

# Rebuild index.html: one <li> link per *-privacy-policy.html page, sorted by
# the display name found in each page's <h1> (fallback: name derived from the
# file name).
rebuild_index() {
    local file name
    local items=()

    shopt -s nullglob
    for file in *-privacy-policy.html; do
        [[ "$file" == "privacy-policy-template.html" ]] && continue
        name="$(sed -n 's|.*<h1>Privacy Policy for \(.*\)</h1>.*|\1|p' "$file" | head -1)"
        name="$(printf '%s' "$name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        if [[ -z "$name" ]]; then
            # Fallback: derive from the file name.
            name="$(printf '%s' "$file" | sed 's/-privacy-policy\.html$//; s/-/ /g')"
        fi
        items+=("$name"$'\t'"$file")
    done

    {
        cat <<'HTML'
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
HTML
        if (( ${#items[@]} > 0 )); then
            printf '%s\n' ${items[@]+"${items[@]}"} | LC_ALL=C sort -f | while IFS=$'\t' read -r name file; do
                printf '            <li><a href="%s">%s</a></li>\n' "$file" "$name"
            done
        fi
        cat <<'HTML'
        </ul>
    </section>

    <footer>
        <p>&copy; 2026 FullStackCode. All rights reserved.</p>
    </footer>
</body>
</html>
HTML
    } | awk '{ printf "%s\r\n", $0 }' > index.html

    echo "Updated index.html ($(printf '%s\n' ${items[@]+"${items[@]}"} | wc -l) policies linked)"
}

main() {
    if [[ "${1:-}" == "--rebuild-index" ]]; then
        rebuild_index
        exit 0
    fi

    local APP_NAME="${1:-}"
    local APP_TYPE="${2:-app}"
    local APP_SLUG="${3:-}"

    if [[ -z "$APP_NAME" ]]; then
        echo "ERROR: App name is required." >&2
        echo "Usage: $0 \"App Display Name\" [app|game] [custom-slug]" >&2
        exit 1
    fi
    if [[ "$APP_TYPE" != "app" && "$APP_TYPE" != "game" ]]; then
        echo "ERROR: App type must be 'app' or 'game' (got '$APP_TYPE')." >&2
        exit 1
    fi

    local INTRO_ACTION MOBILE_DESC
    if [[ "$APP_TYPE" == "game" ]]; then
        INTRO_ACTION="play"
        MOBILE_DESC="mobile game"
    else
        INTRO_ACTION="use"
        MOBILE_DESC="mobile application"
    fi

    if [[ -z "$APP_SLUG" ]]; then
        APP_SLUG="$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
    fi
    if [[ -z "$APP_SLUG" ]]; then
        echo "ERROR: Could not derive a file slug from '$APP_NAME'." >&2
        exit 1
    fi

    local OUT_FILE="${APP_SLUG}-privacy-policy.html"

    if [[ ! -f "$TEMPLATE" ]]; then
        echo "ERROR: Template '$TEMPLATE' not found in the repo root." >&2
        exit 1
    fi
    if [[ -e "$OUT_FILE" ]]; then
        echo "ERROR: '$OUT_FILE' already exists. Refusing to overwrite it." >&2
        exit 1
    fi

    local E_APP_NAME E_APP_TYPE E_INTRO_ACTION E_MOBILE_DESC
    E_APP_NAME="$(esc "$APP_NAME")"
    E_APP_TYPE="$(esc "$APP_TYPE")"
    E_INTRO_ACTION="$(esc "$INTRO_ACTION")"
    E_MOBILE_DESC="$(esc "$MOBILE_DESC")"

    # Render: strip any CR (template may be checked out CRLF), substitute the
    # placeholders, then write the page with CRLF line endings to match the
    # rest of the repo's working-tree convention.
    sed 's/\r$//' "$TEMPLATE" \
        | sed "s|{{APP_NAME}}|$E_APP_NAME|g; s|{{APP_TYPE}}|$E_APP_TYPE|g; s|{{INTRO_ACTION}}|$E_INTRO_ACTION|g; s|{{MOBILE_DESC}}|$E_MOBILE_DESC|g" \
        | awk '{ printf "%s\r\n", $0 }' > "$OUT_FILE"

    if grep -q '{{' "$OUT_FILE"; then
        echo "WARNING: '$OUT_FILE' still contains un-replaced placeholders — check the template." >&2
    fi

    echo "Created $OUT_FILE"
    rebuild_index
}

main "$@"
