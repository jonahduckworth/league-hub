#!/usr/bin/env bash
# Source this file, or use scripts/cloud/run to activate for every command.
LEAGUE_HUB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export LEAGUE_HUB_ROOT
export LEAGUE_HUB_TOOLS="${LEAGUE_HUB_TOOLS:-$(dirname "$LEAGUE_HUB_ROOT")/.league-hub-tools}"
export LEAGUE_HUB_CACHE="${LEAGUE_HUB_CACHE:-$(dirname "$LEAGUE_HUB_ROOT")/.league-hub-cache}"
export PATH="$LEAGUE_HUB_TOOLS/browser-venv/bin:$LEAGUE_HUB_TOOLS/node-tools/node_modules/.bin:$LEAGUE_HUB_TOOLS/flutter/bin:$PATH"
export NPM_CONFIG_CACHE="$LEAGUE_HUB_CACHE/npm"
export PUB_CACHE="$LEAGUE_HUB_CACHE/pub"
export ANALYZER_STATE_LOCATION_OVERRIDE="$LEAGUE_HUB_CACHE/dart-analyzer"
export XDG_CONFIG_HOME="$LEAGUE_HUB_CACHE/config"
export FIREBASE_EMULATORS_PATH="$LEAGUE_HUB_CACHE/firebase-emulators"
export PLAYWRIGHT_BROWSERS_PATH="$LEAGUE_HUB_CACHE/playwright"
export FLUTTER_SUPPRESS_ANALYTICS=true NEXT_TELEMETRY_DISABLED=1 CI=true
if command -v chromium >/dev/null; then
  export CHROME_EXECUTABLE="$(command -v chromium)"
fi
