#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./Scripts/localization_audit.sh [root_path] [swift_scope]
# Examples:
#   ./Scripts/localization_audit.sh .
#   ./Scripts/localization_audit.sh . ./Presentation/Map
#
# Default root is current directory.
# Default scope is <root>/Presentation.

ROOT_DIR="${1:-.}"
SCOPE_PATH="${2:-$ROOT_DIR/Presentation}"

if [[ ! -d "$SCOPE_PATH" ]]; then
  echo "Scope path not found: $SCOPE_PATH" >&2
  exit 1
fi

TMP_LITERALS="$(mktemp)"
TMP_KEYS_USED="$(mktemp)"
TMP_KEYS_EN="$(mktemp)"
TMP_KEYS_PT="$(mktemp)"
trap 'rm -f "$TMP_LITERALS" "$TMP_KEYS_USED" "$TMP_KEYS_EN" "$TMP_KEYS_PT"' EXIT

LITERAL_PATTERN='Text\("[^"]+"|Label\("[^"]+"|Button\("[^"]+"|Section\("[^"]+"|Picker\("[^"]+"|Toggle\("[^"]+"|navigationTitle\("[^"]+"|alert\("[^"]+"|Tab\("[^"]+"'

echo "== Possible hardcoded UI literals =="
rg -n --glob "*.swift" "$LITERAL_PATTERN" "$SCOPE_PATH" > "$TMP_LITERALS" || true

TOTAL_LITERALS="$(wc -l < "$TMP_LITERALS" | tr -d ' ')"
echo "Scope: $SCOPE_PATH"
echo "Total matches: $TOTAL_LITERALS"

for token in Text Label Button Section Picker Toggle navigationTitle alert Tab; do
  count="$( (rg -n --glob "*.swift" "${token}\\(\"[^\"]+\"" "$SCOPE_PATH" || true) | wc -l | tr -d ' ' )"
  echo "  - ${token}: ${count}"
done

if [[ "$TOTAL_LITERALS" -gt 0 ]]; then
  echo
  cat "$TMP_LITERALS"
fi

echo
echo "== Localization keys used in code =="
{
  rg -o --glob "*.swift" 'localized\("[^"]+"\)' "$ROOT_DIR/Presentation" | sed -E 's/.*localized\("([^"]+)"\).*/\1/'
  rg -o --glob "*.swift" 'stopDetailLocalized\("[^"]+"\)' "$ROOT_DIR/Presentation" | sed -E 's/.*stopDetailLocalized\("([^"]+)"\).*/\1/'
  rg -o --glob "*.swift" 'NSLocalizedString\("[^"]+"' "$ROOT_DIR/Presentation" | sed -E 's/.*NSLocalizedString\("([^"]+)".*/\1/'
} | sort -u > "$TMP_KEYS_USED"

echo "Total distinct keys: $(wc -l < "$TMP_KEYS_USED" | tr -d ' ')"
cat "$TMP_KEYS_USED"

EN_FILE="$ROOT_DIR/Resources/en.lproj/Localizable.strings"
PT_FILE="$ROOT_DIR/Resources/pt-BR.lproj/Localizable.strings"

if [[ -f "$EN_FILE" ]]; then
  sed -E -n 's/^"([^"]+)" = .*/\1/p' "$EN_FILE" | sort -u > "$TMP_KEYS_EN"
else
  : > "$TMP_KEYS_EN"
fi

if [[ -f "$PT_FILE" ]]; then
  sed -E -n 's/^"([^"]+)" = .*/\1/p' "$PT_FILE" | sort -u > "$TMP_KEYS_PT"
else
  : > "$TMP_KEYS_PT"
fi

echo
echo "== Missing keys in en =="
comm -23 "$TMP_KEYS_USED" "$TMP_KEYS_EN" || true

echo
echo "== Missing keys in pt-BR =="
comm -23 "$TMP_KEYS_USED" "$TMP_KEYS_PT" || true
