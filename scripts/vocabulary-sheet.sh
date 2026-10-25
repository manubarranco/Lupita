#!/bin/sh
# Contact sheet of the git vocabulary cards (six terms, Spanish) and the menu with the «Git» switch (D42).
# Usage: scripts/vocabulary-sheet.sh [out-dir]   (default: reports/, ignored by git; see D36)
set -e
cd "$(dirname "$0")/.."
swift build --product LupitaApp >/dev/null
exec "$(swift build --show-bin-path)/LupitaApp" --render-vocabulary "${1:-reports}"
