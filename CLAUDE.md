# League Hub

## Baseline Check

Before ANY work: `flutter analyze && flutter test`. Both must pass with 0 issues and 0 failures. After ANY work: same check. No exceptions.

## Hard Rules

1. **`flutter analyze` must show 0 issues at all times.** Run after every change.
2. **`flutter test` must show all tests passing.** Every change needs tests. Run the full suite before committing.
3. **No bandaid fixes.** Understand root causes.
4. **Follow existing patterns.** `AuthorizedFirestoreService` for writes, `PermissionService` for checks, shared widgets for UI, `FakeFirebaseFirestore` in tests.
5. **Test every role.** platformOwner, superAdmin, managerAdmin, and staff.
6. **Use shared widgets.** `EmptyState`, `StatusBadge`, `showConfirmationDialog()`, `BottomSheetHandle`, `AppUtils.show*SnackBar()`, `AppUtils.roleColor()`, `AvatarWidget`, `BadgeWidget`, `ConnectivityBanner`, `LeagueFilter`. Do NOT create inline duplicates.

## Tech Stack

- **Flutter** 3.x (iOS, Android, macOS, web)
- **Firebase** — Auth, Firestore, Storage, Cloud Messaging
- **Riverpod** — State management
- **GoRouter** — Navigation
- **Hive** — Offline mutation queue
- **Cloud Functions** — 8 Firestore-triggered TypeScript functions in `/functions` (FCM notifications)

## Role Hierarchy

```
platformOwner > superAdmin > managerAdmin > staff
```

- **platformOwner**: Full system access
- **superAdmin**: Org-wide management (users, leagues, hubs, teams, announcements, documents)
- **managerAdmin**: Scoped to assigned hubs — can manage teams, staff, content within those hubs
- **staff**: Read-only for assigned hub content, can participate in chat

## Architecture

### Service Layer (7 services)

| Service | Purpose |
|---------|---------|
| `FirestoreService` | Raw Firestore CRUD |
| `AuthorizedFirestoreService` | Permission-checked wrapper — **all mutations go through here** |
| `PermissionService` | 40+ pure functions for role × action × scope checks |
| `OfflineQueueService` | Hive-backed mutation queue with auto-replay on reconnect |
| `MessagingService` | FCM token management, local notifications, deep linking |
| `StorageService` | Firebase Storage (image/document upload) |
| `AuthService` | Firebase Auth wrapper |

### Data Flow

1. **Reads**: Providers → `FirestoreService` → scope-filtered by user's hubIds/leagueIds
2. **Writes**: Screen → `AuthorizedFirestoreService` (permission check) → `FirestoreService` → Firestore
3. **Offline**: `OfflineQueueService` intercepts writes when offline → Hive queue → auto-replay on reconnect
4. **Notifications**: Firestore write → Cloud Function trigger → FCM push → Flutter deep link via GoRouter

### Provider Architecture

20+ providers in `data_providers.dart`. Scope-filtered: `chatRoomsProvider`, `documentsProvider`, `announcementsProvider` filter by user's hub/league assignments. League IDs denormalized on `AppUser` model (derived from hub assignments). `selectedLeagueProvider` / `selectedCategoryProvider` for UI filtering state.

## File Structure

```
lib/
├── core/           # constants, theme, utils (3 files)
├── models/         # data models (11 files)
├── navigation/     # GoRouter config (1 file)
├── providers/      # Riverpod providers (4 files)
├── screens/        # feature screens (27 files)
│   ├── admin/      # admin screens (4 files)
│   ├── settings/   # settings subscreens (7 files)
│   └── viewers/    # document viewers (2 files)
├── services/       # business logic (7 files)
├── widgets/        # shared UI components (12 files)
├── main.dart
└── firebase_options.dart

test/               # mirrors lib/ structure (67 files)
integration_test/   # Firebase emulator tests (5 files)
functions/          # Cloud Functions TypeScript (8 files)
```

## Routes (GoRouter)

| Route | Min Role |
|-------|----------|
| `/` | staff |
| `/chat`, `/chat/:roomId`, `/chat/:roomId/info` | staff |
| `/documents`, `/documents/:id` | staff |
| `/documents/upload` | managerAdmin |
| `/announcements`, `/announcements/:id` | staff |
| `/announcements/create`, `/announcements/:id/edit` | managerAdmin |
| `/settings` | staff |
| `/settings/users`, `/settings/users/:userId` | superAdmin |
| `/settings/profile`, `/settings/notifications`, `/settings/privacy`, `/settings/roles` | staff |
| `/settings/leagues`, `/settings/branding`, `/settings/app-icon` | superAdmin |
| `/teams/:teamId` | staff |
| `/login`, `/create-org`, `/accept-invite` | unauthenticated |

## Test Stats

~1,651 tests across 67 files. Models (11), Services (7), Providers (3), Navigation (1), Widgets (12), Screens (27), Integration (3), Edge cases (1). Use `FakeFirebaseFirestore` in tests.
