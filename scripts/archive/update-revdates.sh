#!/usr/bin/env bash
set -euo pipefail
# set -x

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

find ru/modules/ROOT/pages -type f -name "*.adoc" | while read -r f; do
  # Check if ':revdate:' is present in the file
  if ! grep -q '^:revdate:' "$f"; then
    continue
  fi

  # Extract revdate value after ':revdate:'
  revdate=$(grep '^:revdate:' "$f" | sed -E 's/^:revdate:[[:space:]]*//')

  # Get file modified date in dd.mm.YYYY format
  mod_ddmmyyyy=$(date -r "$f" +"%d.%m.%Y")

  # If equal, skip
  if [ "$revdate" = "$mod_ddmmyyyy" ]; then
    continue
  fi

  # Skip if no changes since last commit
  if git diff --quiet HEAD -- "$f"; then
    continue
  fi

  # Replace revdate in file with modified date in dd.mm.YYYY
  sed -i '' "1,/:revdate:/s|^:revdate:.*$|:revdate: $mod_ddmmyyyy|" "$f"
  echo "Updated revdate in $f to $mod_ddmmyyyy"
done

