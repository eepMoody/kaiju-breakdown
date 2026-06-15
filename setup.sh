#!/usr/bin/env bash
# Idempotent dependency setup for Kaiju Breakdown (Godot 4.6 .NET / C#).
#
# Installs Godot addon dependencies declared in addons.cfg into the untracked
# addons/ dir (clone + copy), then restores the C# <PackageReference>s declared
# in KaijuBreakdown.csproj (Chickensoft, Yarn deps via the addon .props, gdUnit4)
# via `dotnet restore` into the untracked obj/ + the global NuGet cache.
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

# --- C# package restore ---
# Restores <PackageReference>s from KaijuBreakdown.csproj into untracked folders.
# Guarded so the script doesn't hard-fail on machines without the .NET SDK
# (e.g. a CI lane or contributor that only needs the Godot addons).
echo "--- dotnet restore ---"
if command -v dotnet >/dev/null 2>&1; then
  dotnet restore
  echo "  Restored."
else
  echo "  dotnet not found, skipping restore (install the .NET 8 SDK and re-run for C# packages)."
fi
