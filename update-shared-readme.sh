#!/usr/bin/env bash
# update-shared-readme.sh
# Replaces marker blocks in README.org files with content from shared files.
# Marker format (trailing comment after second --- is optional):
#   # --- BEGIN SHARED: <name> --- see https://...
#   # --- END SHARED: <name> --- see https://...
# Shared files: ~/src/screencasts/shared_<name>.org
# Details: id:2026-03-01-README-dot-org-files-share-common-snippets-across-multiple-repositories

set -euo pipefail

SHARED_DIR="${HOME}/src/screencasts"
SEARCH_DIR="${HOME}/src"

find "$SEARCH_DIR" \
    -path "$SHARED_DIR" -prune \
    -o -name "README.org" -print | while read -r readme; do

    # CHANGED: drop the lookahead (?= ---) so trailing content after the name is ignored
    names=$(grep -oP '(?<=# --- BEGIN SHARED: )[\w-]+' "$readme" || true)

    if [[ -z "$names" ]]; then
        echo "SKIP (no markers): $readme"
        continue
    fi

    cp "$readme" "${readme}.bak"
    tmpfile=$(mktemp)
    cp "$readme" "$tmpfile"

    changed=0
    for name in $names; do
        shared_file="${SHARED_DIR}/shared_${name}.org"

        if [[ ! -f "$shared_file" ]]; then
            echo "WARN: No shared file for block '$name': $shared_file — skipping block"
            continue
        fi

        # CHANGED: match begin/end markers with a wildcard suffix to allow trailing comments
        awk -v begin="# --- BEGIN SHARED: ${name}" -v end="# --- END SHARED: ${name}" -v shared="$shared_file" '
            index($0, begin) == 1 { print; inside=1; while ((getline line < shared) > 0) print line; close(shared); next }
            index($0, end)   == 1 { inside=0 }
            !inside                { print }
        ' "$tmpfile" > "${tmpfile}.new"
        mv "${tmpfile}.new" "$tmpfile"
        ((changed++)) || true
    done

    if [[ $changed -gt 0 ]]; then
        mv "$tmpfile" "$readme"
        echo "UPDATED ($changed block(s)): $readme"
    else
        rm "$tmpfile"
        echo "SKIP (no valid shared files found): $readme"
    fi
done

