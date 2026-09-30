#!/usr/bin/env bash
# Run as the saved environment setup script after the repository is checked out.
set -euo pipefail
source "$(dirname "$0")/activate.sh"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Requires Linux x86_64' >&2; exit 1; }
for tool in npm python3 curl tar xz java git; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
mkdir -p "$LEAGUE_HUB_TOOLS" "$LEAGUE_HUB_CACHE"/{npm,pub,config,firebase-emulators,playwright}
if [[ ! -x "$LEAGUE_HUB_TOOLS/node-tools/node_modules/.bin/node" ]] ||
   [[ "$(node --version)" != v22.23.3 ]] ||
   [[ ! -x "$LEAGUE_HUB_TOOLS/node-tools/node_modules/.bin/firebase" ]] ||
   [[ "$(firebase --version)" != 15.27.0 ]]; then
  npm install --prefix "$LEAGUE_HUB_TOOLS/node-tools" --registry=https://registry.npmjs.org --no-audit --no-fund node@22.23.3 firebase-tools@15.27.0
fi
bash "$LEAGUE_HUB_ROOT/scripts/cloud/flutter-setup.sh"
for component in functions apps/admin apps/marketing; do
  (cd "$LEAGUE_HUB_ROOT/$component" && npm ci --no-audit --no-fund)
done
(cd "$LEAGUE_HUB_ROOT/functions" && npm run build)
firebase setup:emulators:firestore
firebase setup:emulators:storage
if [[ ! -x "$LEAGUE_HUB_TOOLS/browser-venv/bin/python" ]]; then
  python3 -m venv "$LEAGUE_HUB_TOOLS/browser-venv"
fi
"$LEAGUE_HUB_TOOLS/browser-venv/bin/python" -m pip install --index-url https://pypi.org/simple playwright==1.62.0
# Official Playwright distribution; no OS packages or license-acceptance commands.
"$LEAGUE_HUB_TOOLS/browser-venv/bin/python" -m playwright install chromium ffmpeg
node --version
flutter --version
firebase --version
