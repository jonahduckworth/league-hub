# League Hub

Codex guidance for the League Hub Flutter app.

## Context

- Repository: `jonahduckworth/league-hub`.
- Canonical path: `/Users/jonah/dev/jd-builds/products/league-hub`.
- Stack: Flutter, Firebase Auth/Firestore/Storage/Messaging, Riverpod, GoRouter, Hive, TypeScript Cloud Functions.
- Cloud Functions live in `functions/`.

## Hard Rules

- Before and after app work, run `flutter analyze && flutter test`; both must pass with 0 issues/failures.
- Do not patch around symptoms. Understand root causes, especially auth, permission, offline queue, and notification behavior.
- Use `AuthorizedFirestoreService` for writes, `PermissionService` for role checks, shared widgets for UI, and `FakeFirebaseFirestore` in tests.
- Test role-sensitive changes across `platformOwner`, `superAdmin`, `managerAdmin`, and `staff`.
- Keep disposable artifacts out of app/release commits.

## Commands

```bash
flutter pub get
flutter analyze
flutter test

cd functions
npm ci
npm run lint
npm run build
```

## Verification

- App/UI/model/provider changes: `flutter analyze && flutter test`.
- Cloud Function changes: run `npm run lint` and `npm run build` inside `functions/`.
- Release/TestFlight work is not complete until App Store Connect/TestFlight state is verified, not merely a local IPA build or upload line.
