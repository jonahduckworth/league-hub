#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/activate.sh"
tools_dir="$LEAGUE_HUB_TOOLS"
mkdir -p "$tools_dir"
if ! [ -f "$tools_dir/flutter-3.44.9-verified" ] || ! [ -x "$tools_dir/flutter/bin/flutter" ]; then
  curl --fail --silent --show-error --retry 2 https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json -o "$tools_dir/flutter-releases.json"
  python3 - <<'PY'
import json, os
from pathlib import Path
root=Path(os.environ['LEAGUE_HUB_TOOLS'])
manifest=json.loads((root/'flutter-releases.json').read_text())
release=next(r for r in manifest['releases'] if r['version']=='3.44.9' and r['channel']=='stable' and r.get('dart_sdk_arch','x64')=='x64')
base=manifest['base_url']
assert base == 'https://storage.googleapis.com/flutter_infra_release/releases'
(root/'flutter-archive-url.txt').write_text(base+'/'+release['archive'])
(root/'flutter-SHA256SUMS').write_text(release['sha256']+'  flutter-sdk.tar.xz\n')
PY
  curl --fail --silent --show-error --retry 2 "$(cat "$tools_dir/flutter-archive-url.txt")" -o "$tools_dir/flutter-sdk.tar.xz"
  (cd "$tools_dir" && sha256sum --check flutter-SHA256SUMS)
  if [ -e "$tools_dir/flutter" ]; then
    echo 'A Flutter directory already exists without a verified installation marker; inspect it before proceeding.' >&2
    exit 1
  fi
  tar -xJf "$tools_dir/flutter-sdk.tar.xz" -C "$tools_dir"
  cp "$tools_dir/flutter-SHA256SUMS" "$tools_dir/flutter-3.44.9-verified"
fi
source "$(dirname "$0")/activate.sh"
flutter --version
cd "$LEAGUE_HUB_ROOT"
if ! [ -e lib/firebase_options.dart ]; then
  cp tool/ci/firebase_options.dart lib/firebase_options.dart
fi
flutter pub get --enforce-lockfile
