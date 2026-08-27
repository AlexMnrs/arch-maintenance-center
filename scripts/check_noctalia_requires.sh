#!/usr/bin/env bash
set -euo pipefail

plugin_dir="${1:-arch-maintenance-center}"
invalid_requires="$(rg -n --pcre2 'require\(\s*(?!"(?:\./|\.\./)[^"]+\.luau"\s*\))' "$plugin_dir" -g '*.luau' || true)"

if [[ -n "$invalid_requires" ]]; then
  printf '%s\n' "Noctalia requires must use literal relative .luau paths:"
  printf '%s\n' "$invalid_requires"
  exit 1
fi
