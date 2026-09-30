#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/activate.sh"
cd "$LEAGUE_HUB_ROOT"
# CLI 15.27.0 does not reliably honor NO_PROXY; keep emulator traffic local.
# Setup preloads the required emulator jars before removing these variables.
exec env -u HTTPS_PROXY -u HTTP_PROXY -u https_proxy -u http_proxy -u ALL_PROXY -u all_proxy \
  firebase emulators:exec --config firebase.rules-test.json \
  --project demo-league-hub-rules --only firestore,storage \
  'node --test functions/test/*.rules.js'
