# Cloud development

From the repository root on Linux x86_64:

```bash
bash scripts/cloud/setup.sh
scripts/cloud/run node --version
scripts/cloud/run flutter analyze --no-pub
scripts/cloud/run flutter test --no-pub
scripts/cloud/run npm --prefix functions run lint
scripts/cloud/run npm --prefix functions test
bash scripts/cloud/rules.sh
```

Setup pins Node 22.23.3, Firebase CLI 15.27.0, Flutter 3.44.9, and Python
Playwright 1.62.0. Flutter is downloaded from its official release manifest and
SHA-256 checked; npm and PyPI provide other tools, and Playwright downloads its
matching Chromium and FFmpeg. Lockfiles govern application dependencies. Setup
requires an existing npm, Python with venv, curl, tar/xz, Git, Java 21+, and browser
system libraries. It does not install OS packages or accept SDK licenses. It
preserves an existing Firebase options file, otherwise copies the CI fixture.
Tool/cache directories default to siblings of the checkout; `LEAGUE_HUB_TOOLS`
and `LEAGUE_HUB_CACHE` can override them. Do not share these writable directories
between untrusted projects.

## Activation and saved environments

Use `scripts/cloud/run COMMAND...` for each command, or source
`scripts/cloud/activate.sh` in each shell. Setup-process exports do not activate
later agent shells. No shell profile editing is necessary. `AGENTS.md` directs
future tasks to this wrapper.

The supported persistent mechanism is a setup script in the saved cloud
environment's editor. Once these files are committed and available to its checkout,
configure the Install script as:

```bash
bash /workspace/league-hub/scripts/cloud/setup.sh
```

For the Start skill, use these instructions: run
`/workspace/league-hub/scripts/cloud/run python /workspace/league-hub/scripts/cloud/web.py`
as a supervised long-running process, wait for both PASS readiness messages, and
use `scripts/cloud/run` for subsequent commands. Keep admin demo mode and the
local-only contact endpoint; do not bind credentials.

Current environments require Save and Republish in the environment editor to
capture reusable state, then a new task for validation. This implementation does
not publish or republish anything. Legacy environments may expose a maintenance
hook; the same setup command can refresh dependencies there. It intentionally runs `npm ci`;
do not invoke it while development servers are using node_modules. This repository
cannot update saved environment settings itself. Changes to this running workspace
are not evidence that a future fresh environment is fixed. Verify by creating a new
task after the script is saved. No saved-environment configuration API was exposed
during implementation, so that step remains external to this checkout.

See the [current cloud environment guide](https://learn.chatgpt.com/docs/environments/cloud-environments)
and [legacy setup/maintenance guidance](https://learn.chatgpt.com/docs/environments/cloud-environment).

## Safe web previews and capture

```bash
scripts/cloud/run python scripts/cloud/web.py
# In a second shell:
scripts/cloud/run python scripts/cloud/capture.py --output /tmp/league-hub-captures
```

Admin listens on 127.0.0.1:3010 with `NEXT_PUBLIC_ADMIN_DEMO_MODE=true`;
marketing listens on 127.0.0.1:3020 with `NEXT_PUBLIC_CONTACT_ENDPOINT` pointing
to an intentionally unavailable local endpoint. Forms show an error rather than
submitting to production. The launcher restores Next-generated configuration after
startup; stop it with Ctrl-C. Do not edit startup-generated files during startup.
Capture produces PNG and WebM files and rejects requests outside the two local
origins. It does not sign in, submit forms, or use production credentials.

Both frontend directories support `npm run verify` (lint, typecheck, tests, build).
For an admin build used in local QA, set `NEXT_PUBLIC_ADMIN_DEMO_MODE=true` before
building. Never deploy a demo build. See [Playwright browser setup](https://playwright.dev/python/docs/browsers).

## Firebase and Flutter emulators

`rules.sh` runs Firestore/Storage tests against `demo-league-hub-rules`, with
Firestore 8181, Storage 9299, hub 4505, and logging 4605. Setup caches the jars;
the wrapper removes proxy variables only for its emulator subprocess because the
pinned CLI does not reliably honor NO_PROXY. No Firebase login is required.

Full native app integration additionally needs Auth 9099, Firestore 8081,
Storage 9199, Functions 5001, and a native platform. On an appropriately configured
local workstation, start a complete isolated stack with a demo project:

```bash
firebase emulators:start --project demo-league-hub --only auth,firestore,storage,functions
flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Use non-production Firebase options whose project ID matches the demo project;
the static CI fixture is not a replacement for platform setup. Android emulator
clients use `10.0.2.2` to reach the host. Native app boot/full-stack behavior has
not been verified in Linux cloud. Messaging has no emulator; the app's emulator
mode disables native FCM auto-initialization. Email Functions use `RESEND_API_KEY`:
do not supply a real key or exercise external email delivery in local QA.

## Platform boundaries

Android SDK installation is blocked until the user handles Google's
[SDK license agreement](https://developer.android.com/studio/terms). Do not run
`yes | sdkmanager --licenses`, prepopulate license hashes, or use the SDK on the
user's behalf to accept terms. This cloud machine also has no `/dev/kvm`, so
hardware-accelerated Android emulation is unavailable. Java 21 is already present.
No Android packages were installed during this implementation.

On the user's Mac, separately check Xcode/SDK selection, CocoaPods, simulator/device
availability, approved non-production Firebase files, and `flutter doctor -v`.
Run native builds and `scripts/run_integration_tests.sh` only after reviewing its
project configuration; that existing script selects the real project ID. iOS
signing and TestFlight checks remain Mac work. No Mac operation is performed by
these cloud scripts. The Flutter repository has no web/Linux target directories;
cloud browser previews are the two Next.js apps.
