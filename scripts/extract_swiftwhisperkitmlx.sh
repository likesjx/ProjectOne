#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/SwiftWhisperKitMLX"
DEST_PARENT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)"
DEST_DIR="$DEST_PARENT/SwiftWhisperKitMLX"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Source package directory not found: $SRC_DIR" >&2
  exit 1
fi

if [[ -d "$DEST_DIR" ]]; then
  echo "Destination already exists: $DEST_DIR" >&2
  exit 2
fi

echo "Copying package to parent directory: $DEST_DIR"
cp -R "$SRC_DIR" "$DEST_DIR"

pushd "$DEST_DIR" >/dev/null
if [[ ! -d .git ]]; then
  echo "Initializing new git repository"
  git init -q
  git add .
  git commit -m "chore: initial import of SwiftWhisperKitMLX (extracted from ProjectOne)" >/dev/null
fi
popd >/dev/null

cat <<EOF
Extraction complete.
Next steps:
  1. Create GitHub repo: https://github.com/new (name: SwiftWhisperKitMLX)
  2. cd "$DEST_DIR" && git remote add origin git@github.com:<you>/SwiftWhisperKitMLX.git
  3. git branch -M main
  4. git push -u origin main
  5. (optional) git tag v0.1.0 && git push origin v0.1.0
  6. Update ProjectOne to use remote dependency:
       In Xcode: File > Add Packages > enter repo URL > select main (or version)
  7. Remove internal /SwiftWhisperKitMLX from ProjectOne after confirming build.
EOF

echo "Done."
