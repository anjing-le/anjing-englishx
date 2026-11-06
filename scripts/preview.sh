#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --disable-keychain --product EnglishX
python3 scripts/package-preview.py
open "$PWD/dist/preview/EnglishX.app"
