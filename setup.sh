#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
MANIFEST="addons.cfg"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: addons.cfg not found"
  exit 1
fi

# Strip all spaces so we don't need to trim each field individually
while IFS='|' read -r name git_url ref repo_subdir install_dir; do
  # Skip comments and blank lines
  [[ "$name" == "#"* || -z "$name" ]] && continue

  target="${install_dir:-addons/$name}"
  version_file="$target/.addon_version"

  echo "--- $name ($ref) ---"

  if [[ -f "$version_file" ]] && [[ "$(cat "$version_file")" == "$ref" ]]; then
    echo "  Already installed, skipping."
    continue
  fi

  tmp_dir="$(mktemp -d)"
  echo "  Cloning $git_url @ $ref..."

  source_dir="$tmp_dir/repo/$repo_subdir"
  if git clone --depth 1 --branch "$ref" "$git_url" "$tmp_dir/repo" 2>&1 | sed 's/^/  /' \
     && [[ -d "$source_dir" ]]; then
    rm -rf "$target"
    cp -R "$source_dir" "$target"
    echo "$ref" > "$target/.addon_version"
    echo "  Installed."
  else
    echo "  ERROR: Failed to install $name"
  fi

  rm -rf "$tmp_dir"
done < <(tr -d ' ' < "$MANIFEST")
