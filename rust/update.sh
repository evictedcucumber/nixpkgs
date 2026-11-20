#!/usr/bin/env bash
# Add Rust channel manifests (1.x.y or nightly-YYYY-MM-DD) to manifests.json.
# Without arguments, adds the current stable release.
set -euo pipefail

file="$(dirname "$(readlink -f "$0")")/manifests.json"
dist=https://static.rust-lang.org/dist

channels=("$@")
if [ ${#channels[@]} -eq 0 ]; then
  version=$(curl -fsSL "$dist/channel-rust-stable.toml" |
    awk '/^\[pkg\.rust\]$/ { found = 1; next } found && /^version/ { gsub(/"/, "", $3); print $3; found = 0 }')
  channels=("$version")
fi

[ -f "$file" ] || echo '{}' >"$file"

for channel in "${channels[@]}"; do
  if jq -e --arg c "$channel" 'has($c)' "$file" >/dev/null; then
    continue
  fi
  case $channel in
  nightly-????-??-??) url="$dist/${channel#nightly-}/channel-rust-nightly.toml" ;;
  1.*.*) url="$dist/channel-rust-$channel.toml" ;;
  *)
    echo "unsupported channel: $channel" >&2
    exit 1
    ;;
  esac
  hash=$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r .hash)
  jq -S --arg c "$channel" --arg h "$hash" '. + {($c): $h}' "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
  echo "$channel"
done
