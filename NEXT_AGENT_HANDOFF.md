# League Hub — Next Agent Handoff

## Instructions

You are picking up development on the League Hub Flutter app. Read this document fully before doing anything. Run `flutter analyze && flutter test` first to confirm the baseline. Both must pass before you make any changes.

## Current State (as of 2026-03-26)

- **Framework**: Flutter/Dart, Riverpod state management, Firebase backend (Firestore, Auth, Storage, Cloud Messaging), GoRouter navigation
- **Status**: `flutter analyze` — 0 issues. `flutter test` — 1,651 tests, all green.
- **Cloud Functions**: 8 Firestore-triggered TypeScript functions in `/functions` handling FCM notifications
- **Codebase**: 60 source files (~13,500 LOC), 67 test files (~25,000 LOC), fully refactored with zero duplication

## Architecture

### Role Hierarchy
```
platformOwner > superAdmin > managerAdmin > staff
```
- **platformOwner**: Full system access
- **superAdmin**: Org-wide management (users, leagues, hubs, teams, announcements, documents)
- **managerAdmin**: Scoped to assigned hubs — can manage teams, staff, content within those hubs
- **staff**: Read-only for assigned hub content, can participate in chat

### Service Layer (7 services)
| Service | Purpose |
|---------|---------|
| `FirestoreService` | Raw Firestore CRUD (813 LOC) |
| `AuthorizedFirestoreService` | Permission-checked wrapper — all mutations go through here |
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

### Provider Architecture (20+ providers in `data_providers.dart`)
- Scope-filtered: `chatRoomsProvider`, `documentsProvider`, `announcementsProvider` filter by user's hub/league assignments
- League IDs denormalized on `AppUser` model (derived from hub assignments)
- `selectedLeagueProvider` / `selectedCategoryProvider` for UI filtering state

### Shared Widget Library (12 widgets)
| Widget | Purpose |
|--------|---------|
| `EmptyState` | Icon + title + subtitle + optional action for empty lists |
| `StatusBadge` | Role badges, scope tags, category pills |
| `showConfirmationDialog()` | Yes/no confirmation with custom labels/colors |
| `BottomSheetHandle` | Drag handle bar for bottom sheets |
| `AppUtils.showErrorSnackBar()` | Centralized error feedback |
| `AppUtils.showSuccessSnackBar()` | Centralized success feedback |
| `AppUtils.showInfoSnackBar()` | Centralized info feedback |
| `AppUtils.roleColor()` | Consistent role → color mapping |
| `AvatarWidget` | User avatar with network image + initials fallback |
| `BadgeWidget` | Notification count badge |
| `ConnectivityBanner` | Offline/online status with pending mutation count |
| `LeagueFilter` | Horizontal league filter pills |

### Routes (GoRouter)
| Route | Screen | Min Role |
|-------|--------|----------|
| `/` | Dashboard | staff |
| `/chat` | Chat list | staff |
| `/chat/:roomId` | Conversation | staff (must be participant) |
| `/chat/:roomId/info` | Chat room settings | staff |
| `/documents` | Document library | staff |
| `/documents/:id` | Document detail/viewer | staff |
| `/documents/upload` | Upload document | managerAdmin |
| `/announcements` | Announcements feed | staff |
| `/announcements/:id` | Announcement detail | staff |
| `/announcements/create` | Create announcement | managerAdmin |
| `/announcements/:id/edit` | Edit announcement | managerAdmin |
| `/settings` | Settings menu | staff |
| `/settings/users` | User management | superAdmin |
| `/settings/users/:userId` | User detail/edit | superAdmin |
| `/settings/profile` | Edit profile | staff |
| `/settings/leagues` | Manage leagues/hubs/teams | superAdmin |
| `/settings/roles` | Role matrix docs | staff |
| `/settings/branding` | Org branding | superAdmin |
| `/settings/app-icon` | App icon | superAdmin |
| `/settings/notifications` | Notification prefs | staff |
| `/settings/privacy` | Privacy/security | staff |
| `/teams/:teamId` | Team detail/roster | staff |
| `/login` | Login | unauthenticated |
| `/create-org` | Org creation wizard | unauthenticated |
| `/accept-invite` | Accept invitation | unauthenticated |

## Hard Rules

1. **`flutter analyze` must show 0 issues at all times.** Run after every change.
2. **`flutter test` must show all tests passing.** Every change needs tests. Run the full suite before committing.
3. **No bandaid fixes.** Understand root causes.
4. **Follow existing patterns.** `AuthorizedFirestoreService` for writes, `PermissionService` for checks, shared widgets for UI, `FakeFirebaseFirestore` in tests.
5. **Test every role.** platformOwner, superAdmin, managerAdmin, and staff.
6. **Use shared widgets.** `EmptyState`, `StatusBadge`, `showConfirmationDialog()`, `BottomSheetHandle`, `AppUtils.show*SnackBar()`, `AppUtils.roleColor()`. Do NOT create inline duplicates.

## Completed Work (Phases 1–7 + Structural Refactoring)

All phases from the original handoff have been implemented and are in production:

- ✅ **Phase 1**: FCM push notifications (Cloud Functions + Flutter-side + notification preferences)
- ✅ **Phase 2**: Offline mutation queue (Hive-backed `OfflineQueueService` + `ConnectivityBanner` with pending count)
- ✅ **Phase 3**: League-scope filtering (leagueIds denormalized on AppUser, scope-filtered providers)
- ✅ **Phase 4**: Team management UI (team detail screen, roster management, team chat rooms, routes)
- ✅ **Phase 5**: Document viewing & download (in-app PDF/image viewer, download with progress, file type fallback)
- ✅ **Phase 6**: Profile photo upload (ImagePicker + StorageService + avatarUrl update)
- ✅ **Phase 7**: Integration tests (3 flow tests: permission, user flow, role flow)
- ✅ **Structural refactoring**: Extracted 12 shared widgets, eliminated all inline duplication across 60 source files

## Test Coverage

| Category | Files | Tests |
|----------|-------|-------|
| Models | 11 | ~200 |
| Services | 7 | ~350 |
| Providers | 3 | ~100 |
| Navigation | 1 | ~150 |
| Widgets | 12 | ~80 |
| Screens | 27 | ~500 |
| Integration | 3 | ~100 |
| Edge cases | 1 | ~50 |
| **Total** | **67** | **1,651** |

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
├── main.dart       # app entry point
└── firebase_options.dart

test/               # mirrors lib/ structure (67 files)
├── core/
├── models/
├── navigation/
├── providers/
├── screens/
├── services/
├── widgets/
├── integration/
├── edge_cases/
└── helpers/

integration_test/   # Firebase emulator tests (5 files)
functions/          # Cloud Functions TypeScript (8 files)
```

## What's Next

The core platform is complete. Potential next phases (not yet scoped):

- **Search**: Global search across announcements, documents, chat messages, users
- **Analytics dashboard**: Org-level stats (active users, message volume, document uploads)
- **Scheduling / Calendar**: Event scheduling tied to hubs/teams with calendar integration
- **Multi-org support**: Allow users to belong to multiple organizations
- **Audit log**: Track all admin actions (role changes, deactivations, content deletions)
- **Dark mode**: Theme switching with `AppTheme.darkTheme`
- **Localization**: i18n support for multi-language orgs
- **Web support**: Responsive layout for Flutter web deployment

## Reminder

Before any work: `flutter analyze && flutter test`. Both must pass with 0 issues and 0 failures. After any work: same check. No exceptions.
