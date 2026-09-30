# League Hub

A Flutter app for managing sports leagues, hubs, and teams. Built for commissioners, administrators, and staff to communicate, share documents, and manage league operations from a single platform.

## Tech Stack

- **Flutter** 3.x (iOS & Android)
- **Firebase** — Auth, Firestore, Storage, Messaging
- **Riverpod** — State management
- **go_router** — Navigation
- **cached_network_image** — Image caching
- **shimmer** — Loading states

## Getting Started

For Linux cloud development, start with [the cloud setup guide](scripts/cloud/README.md).
It provides pinned toolchain setup, safe frontend previews, emulator tests, screenshots,
and video capture without Firebase credentials.

For a native developer workstation, install Flutter **3.44.9** (the CI version),
run `flutter pub get --enforce-lockfile`, and supply the platform-specific Firebase
configuration for your approved development project. `lib/main.dart` already calls
`Firebase.initializeApp`; no initialization code needs uncommenting. The cloud setup
uses `tool/ci/firebase_options.dart` only as a static-analysis/test fixture, not a
working production configuration. The app does not automatically switch to mock UI.

Run `flutter analyze && flutter test` before native development. Android requires
an SDK and its license agreements; iOS/macOS development requires a Mac and Xcode.
See the cloud guide for the emulator flags and platform limitations.

## Project Structure

```
lib/
├── core/           # Theme, constants, utilities
├── models/         # Dart data models with fromJson/toJson
├── services/       # Firebase service layer (auth, firestore, storage, messaging)
├── providers/      # Riverpod state providers + mock data
├── navigation/     # go_router configuration
├── screens/        # App screens (login, dashboard, chat, docs, announcements, settings)
└── widgets/        # Reusable UI components
```

## Design System

| Token | Hex |
|---|---|
| Primary | `#1A3A5C` |
| Primary Light | `#2E75B6` |
| Accent | `#4DA3FF` |
| Background | `#F5F7FA` |
| Card | `#FFFFFF` |
| Text | `#1A1A2E` |
| Text Secondary | `#6B7280` |
| Text Muted | `#9CA3AF` |
| Border | `#E5E7EB` |
| Success | `#10B981` |
| Warning | `#F59E0B` |
| Danger | `#EF4444` |

## Firebase Setup

Native configuration files are intentionally ignored by Git. Configure an approved
non-production project on your developer workstation; do not create credentials or
connect this cloud environment to production just to run tests. The admin preview
must use `NEXT_PUBLIC_ADMIN_DEMO_MODE=true`, and marketing previews must override
`NEXT_PUBLIC_CONTACT_ENDPOINT`. The cloud preview launcher sets both safely.

## Firebase deployment

Pull requests that change the admin app, landing page, Functions, or Firebase
configuration validate every affected surface. Production Functions changes
must also update `functions/release-plan.json` with either every affected export
or an explicit all-Functions release. A successful push to `main` deploys those
Functions first, verifies that they are active on Node.js 22 in `us-central1`,
and only then deploys dependent `admin` or `marketing` Hosting changes.

For a targeted release, use:

```json
{
  "all": false,
  "targets": ["adminCreatePolicy"],
  "reason": "Deploy the updated policy creation callable."
}
```

Changes to shared Functions dependencies or TypeScript configuration require
`"all": true` with an empty target list so the broader rollout is intentional.

The `Deploy Functions` workflow can also be run manually from `main` with a
comma-separated target list. This provides a safe retry path after a provider
outage without requiring an empty commit or redeploying unrelated Functions.

The GitHub repository must define a
`FIREBASE_SERVICE_ACCOUNT_JDB_LEAGUE_HUB` Actions secret containing a Firebase
service-account JSON key with permission to deploy Hosting and Cloud Functions
for the `jdb-league-hub` project.

## Contributing

This project uses clean architecture with a clear separation of concerns:
- **Models** are plain Dart classes with Firestore serialization
- **Services** are thin wrappers around Firebase SDKs
- **Providers** expose reactive state via Riverpod
- **Screens** are pure UI, reading from providers
