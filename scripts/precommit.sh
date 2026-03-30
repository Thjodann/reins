#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

echo "Running format check on staged Dart files..."
staged_dart_files=()
while IFS= read -r file; do
  if [ -n "$file" ]; then
    staged_dart_files+=("$file")
  fi
done < <(git diff --cached --name-only --diff-filter=ACMR -- '*.dart')

if [ "${#staged_dart_files[@]}" -gt 0 ]; then
  dart format --output=none --set-exit-if-changed "${staged_dart_files[@]}"
else
  echo "No staged Dart files to format-check."
fi

echo "Running static analysis..."
flutter analyze --no-fatal-infos

echo "Pre-commit checks passed."
