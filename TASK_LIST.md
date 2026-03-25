# League Hub — Complete Build-Out & Test Coverage Task List

> Generated from a deep-dive audit of the codebase on March 25, 2026.
> Organized by user role flows, then shared infrastructure, then test coverage gaps.

---

## Current State Summary

**Tech Stack:** Flutter 3.x, Dart 3.x, Firebase (Auth/Firestore/Storage/FCM), Riverpod, go_router

**4 User Roles:** Platform Owner, Super Admin, Manager Admin, Staff

**What exists:** 22 screens, 6 widgets, 4 services, 15+ providers, 10 model classes, 29 test files (models, 5 widgets, 1 provider file, 1 utility file, 7 settings screen tests)

**What's missing:** Role-based route guards, service-layer permission enforcement, complete screen tests, integration tests, error/edge-case handling, and several incomplete user flows.

---

## Part 1: Flows That Need to Be Built Out

### 1.1 Platform Owner Flows

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Build org-level management dashboard (view all orgs, billing, data deletion) | Not started | Currently no multi-org view; Platform Owner sees the same dashboard as everyone else |
| 2 | Add ability to create/delete organizations | Not started | `createOrganization` exists in service but no screen flow for Platform Owner to manage multiple orgs |
| 3 | Add data deletion flow (GDPR/compliance) | Not started | No UI or service method for wiping org data |
| 4 | Add billing management screen/flow | Not started | No billing model, service, or screen exists |
| 5 | Add Platform Owner route guard — restrict org management routes | Not started | Router has zero role-based guards |
| 6 | Add ability to promote/demote Super Admins across orgs | Not started | `UserDetailScreen` blocks role changes for platformOwner/superAdmin targets but Platform Owner should be able to manage Super Admins |

### 1.2 Super Admin Flows

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7 | Enforce Super Admin guard on ManageLeaguesScreen | Not started | Screen has no role check; any authenticated user can access `/settings` and manage leagues |
| 8 | Enforce Super Admin guard on UserManagementScreen | Not started | No role check at screen or route level |
| 9 | Enforce Super Admin guard on BrandingScreen | Not started | No role check |
| 10 | Enforce Super Admin guard on AppIconScreen | Not started | No role check |
| 11 | Build user role change audit trail | Not started | No logging when a Super Admin changes someone's role |
| 12 | Add bulk invite flow (CSV upload of staff) | Not started | Only single invitations supported |
| 13 | Add league chat room auto-creation on league create | Partial | `createLeagueChatRooms` exists but isn't always called from ManageLeaguesScreen |
| 14 | Add cascade delete for leagues (delete hubs → teams → chat rooms → documents scoped to league) | Not started | `deleteLeague` only deletes the league doc, orphaning children |
| 15 | Add cascade delete for hubs (delete teams under hub) | Not started | Same orphan problem |
| 16 | Build org-wide announcement push notification trigger | Not started | TODO in `firestore_service.dart` line 508 — no FCM send on announcement create |
| 17 | Build document upload notification to relevant users | Not started | No notification on new document |

### 1.3 Manager Admin Flows

| # | Task | Status | Notes |
|---|------|--------|-------|
| 18 | Scope Manager Admin's view to only their assigned hubs/teams | Not started | Manager Admins currently see ALL hubs, teams, chat rooms, and documents in the org |
| 19 | Restrict Manager Admin from editing leagues they aren't assigned to | Not started | No hub/league ownership check on ManageLeaguesScreen |
| 20 | Restrict Manager Admin announcement scope to their hubs only | Partial | CreateAnnouncementScreen blocks org-wide scope for Manager Admin, but doesn't verify hub ownership for hub-scoped announcements |
| 21 | Restrict Manager Admin document uploads to their assigned hubs/leagues | Not started | UploadDocumentScreen has no scoping logic |
| 22 | Add Manager Admin ability to manage staff within their hubs | Not started | UserManagementScreen shows all org users with no hub-level filtering |
| 23 | Restrict Manager Admin chat room creation to their league/hub scope | Not started | ChatListScreen allows creating event rooms for any league |
| 24 | Add Manager Admin dashboard filtered to their hubs | Not started | DashboardScreen shows org-wide stats |

### 1.4 Staff Flows

| # | Task | Status | Notes |
|---|------|--------|-------|
| 25 | Scope Staff view to only their assigned hubs/teams | Not started | Staff sees everything in the org |
| 26 | Hide admin settings tiles (Manage Leagues, User Management, Branding, App Icon) from Staff | Not started | SettingsScreen shows all tiles to all roles |
| 27 | Restrict Staff from creating announcements | Partial | FAB hidden for staff role, but no server-side enforcement |
| 28 | Restrict Staff from uploading documents | Partial | FAB hidden for staff, but no server-side enforcement |
| 29 | Restrict Staff from archiving chat rooms | Not started | No role check on archive action |
| 30 | Restrict Staff from deactivating/reactivating users | Not started | Long-press deactivate available to anyone on UserManagementScreen |
| 31 | Add Staff profile self-edit flow (only own profile) | Partial | EditProfileScreen exists but no enforcement preventing editing other users |
| 32 | Build Staff onboarding experience (first login after accepting invite) | Not started | Staff lands on generic dashboard with no guided intro |

### 1.5 Shared / Cross-Role Flows

| # | Task | Status | Notes |
|---|------|--------|-------|
| 33 | Build invitation expiration logic (expire after N days) | Not started | Invitations have `pending` status but no TTL or expiration check |
| 34 | Build invitation token validation on accept | Not started | `getInvitationByToken` doesn't verify expiry; `createAccountFromInvite` trusts all invitation data |
| 35 | Build chat message editing/deletion | Not started | Messages are write-only — no edit or delete |
| 36 | Build chat media/image sharing flow | Not started | Message model supports `mediaUrl` and `mediaType` but no UI to attach/send media |
| 37 | Build chat link preview generation | Not started | Message model has `linkPreview` but no URL detection or preview fetching |
| 38 | Build document version history UI in DocumentDetailScreen | Not started | Model supports versions array but detail screen doesn't display version list or allow rollback |
| 39 | Build document download flow | Not started | No download button or handler in DocumentDetailScreen |
| 40 | Build document search (full-text) | Not started | DocumentsScreen has a search bar but only filters by title client-side |
| 41 | Build announcement attachment upload flow | Not started | Announcement model supports `attachments` list but CreateAnnouncementScreen has no file picker |
| 42 | Build read receipts UI for chat (who read the message) | Partial | Message model has `readBy` array and ChatBubble shows checkmarks, but no tap-to-see-readers |
| 43 | Build mark-messages-as-read logic | Not started | No service method to update `readBy` when a user views a message |
| 44 | Build unread message count/badge on chat list | Not started | ChatListScreen shows no unread indicators |
| 45 | Build typing indicators in chat | Not started | No presence/typing state |
| 46 | Build password change flow (authenticated user) | Not started | PrivacySecurityScreen has no password change UI |
| 47 | Build account deletion flow | Not started | No self-service account deletion |
| 48 | Build deep link handling for notifications | Partial | MessagingService routes by notification type but no verification user can access target |
| 49 | Build error boundary / global error handler | Not started | Screens handle errors individually and inconsistently |
| 50 | Build offline mode / connectivity indicator | Not started | No offline detection or cached data handling |

---

## Part 2: Service-Layer Permission Enforcement

Every service method currently operates without any role or ownership verification. This entire layer needs to be built.

| # | Task | Notes |
|---|------|-------|
| 51 | Create a `PermissionService` or middleware that validates role + ownership before mutations | Central enforcement point for all write operations |
| 52 | Add role check to `createLeague`, `deleteLeague` | Only platformOwner, superAdmin |
| 53 | Add role check to `createHub`, `deleteHub` | platformOwner, superAdmin, managerAdmin (own leagues only) |
| 54 | Add role check to `createTeam`, `deleteTeam` | platformOwner, superAdmin, managerAdmin (own hubs only) |
| 55 | Add role check to `createAnnouncement`, `updateAnnouncement`, `deleteAnnouncement`, `togglePin` | platformOwner, superAdmin, managerAdmin (scoped) |
| 56 | Add role check to `createDocument`, `updateDocument`, `deleteDocument` | platformOwner, superAdmin, managerAdmin (scoped) |
| 57 | Add role check to `deactivateUser`, `reactivateUser`, `updateUserFields` | platformOwner, superAdmin only (managerAdmin for own hub staff) |
| 58 | Add role check to `createInvitation` | platformOwner, superAdmin, managerAdmin (scoped to own hubs) |
| 59 | Add role check to `archiveChatRoom` | platformOwner, superAdmin, managerAdmin |
| 60 | Add ownership verification to `sendMessage` — validate senderId matches authenticated user | Prevent impersonation |
| 61 | Add scope filtering to `getChatRooms` — staff/managerAdmin only see rooms for their leagues/hubs | Currently returns all org rooms |
| 62 | Add scope filtering to `documentsStream` — staff only see docs for their assigned leagues/hubs | Currently fetches all org docs |
| 63 | Add scope filtering to `getAnnouncements` — staff only see announcements for their scope | Currently returns all org announcements |
| 64 | Add Firestore Security Rules file (`firestore.rules`) | No rules file exists in the repo |

---

## Part 3: Route-Level Guards

| # | Task | Notes |
|---|------|-------|
| 65 | Add role-based redirect logic in `router.dart` | Currently only checks authenticated vs. unauthenticated |
| 66 | Guard `/settings/users` — platformOwner, superAdmin, managerAdmin only | Staff should not access user management |
| 67 | Guard `/settings/roles` — platformOwner, superAdmin only | Manager Admins and Staff should not see role config |
| 68 | Guard `/settings/branding` — platformOwner, superAdmin only | |
| 69 | Guard `/settings/app-icon` — platformOwner, superAdmin only | |
| 70 | Guard `/documents/upload` — block staff at route level | Currently only hides FAB |
| 71 | Guard `/announcements/create` and `/announcements/:id/edit` — block staff at route level | Currently only hides FAB |
| 72 | Add "unauthorized" screen/redirect for role-blocked routes | No 403-style screen exists |

---

## Part 4: Test Coverage — What's Missing

### 4.1 Service Tests Needed

| # | Test Target | What to Test |
|---|-------------|--------------|
| 73 | `FirestoreService` — Organizations | `getOrganization`, `createOrganization`, `updateOrganization` |
| 74 | `FirestoreService` — Leagues | `getLeagues`, `createLeague`, `deleteLeague`, stream behavior |
| 75 | `FirestoreService` — Hubs | `getHubs`, `createHub`, `deleteHub`, `getAllHubsCount` |
| 76 | `FirestoreService` — Teams | `getTeams`, `createTeam`, `deleteTeam`, `getAllTeamsCount` |
| 77 | `FirestoreService` — Users | `getUser`, `updateUser`, `getOrgUsers`, `deactivateUser`, `reactivateUser`, `updateUserFields` |
| 78 | `FirestoreService` — Chat Rooms | `createChatRoom`, `archiveChatRoom`, `getChatRooms`, `getOrCreateDMRoom`, `createLeagueChatRooms` |
| 79 | `FirestoreService` — Messages | `getMessages`, `sendMessage` (including lastMessage update atomicity) |
| 80 | `FirestoreService` — Documents | `documentsStream`, `createDocument`, `updateDocument`, `deleteDocument`, `addDocumentVersion`, `getDocumentsByLeague`, `getDocumentsByCategory` |
| 81 | `FirestoreService` — Announcements | `getAnnouncements`, `getAnnouncementsByLeague`, `createAnnouncement`, `updateAnnouncement`, `deleteAnnouncement`, `togglePin` |
| 82 | `FirestoreService` — Invitations | `createInvitation`, `getInvitations`, `getInvitationByToken`, `acceptInvitation`, token generation |
| 83 | `AuthService` — Sign in | `signInWithEmail` including auto user doc creation |
| 84 | `AuthService` — Account creation | `createAccount`, verify no Firestore doc created |
| 85 | `AuthService` — Invite flow | `createAccountFromInvite` with role/hub/team propagation |
| 86 | `AuthService` — Edge cases | `sendPasswordResetEmail`, `getCurrentAppUser`, `signOut` |
| 87 | `StorageService` — Upload | `uploadFile`, `uploadBytes`, `uploadDocument` with progress callback |
| 88 | `StorageService` — Delete | `deleteDocumentFile`, `deleteFile` (including silent error handling) |
| 89 | `StorageService` — Download | `getDownloadUrl` |
| 90 | `MessagingService` — Token management | `_registerToken`, `_saveToken`, `removeToken` |
| 91 | `MessagingService` — Topic subscriptions | `subscribeToTopic`, `unsubscribeFromTopic`, `syncPreferences` |
| 92 | `MessagingService` — Deep link routing | `_navigateFromNotification` for each notification type |
| 93 | `PermissionService` (once built) | Every role × every action combination |

### 4.2 Screen/Widget Tests Needed

| # | Screen | What to Test |
|---|--------|--------------|
| 94 | `LoginScreen` | Form validation, sign-in call, password reset flow, error display, navigation to create-org and accept-invite |
| 95 | `OrgCreationScreen` | 4-step wizard navigation, form validation at each step, league/hub/team creation calls, completion navigation |
| 96 | `AcceptInvitationScreen` | Token input, invitation lookup, account creation, error states (invalid/expired token) |
| 97 | `DashboardScreen` | Stats cards render with correct counts, league filter works, quick links navigate correctly, empty states |
| 98 | `ChatListScreen` | Room list rendering, search filtering, section grouping (league/event/DM), FAB actions, new room creation, new DM creation |
| 99 | `ChatConversationScreen` | Message list rendering, send message flow, auto-scroll, date dividers, empty state, error on send |
| 100 | `ChatRoomInfoScreen` | Room details display, participant list, archive action (role-conditional) |
| 101 | `DocumentsScreen` | Document list, league filter, category chips, search, FAB visibility by role, empty state |
| 102 | `UploadDocumentScreen` | File picker, category selection, league association, upload progress, success/error |
| 103 | `DocumentDetailScreen` | Document info display, version history, download action, edit/delete by role |
| 104 | `AnnouncementsScreen` | Announcement list, pinned-first ordering, FAB visibility by role, pin toggle, edit/delete actions, scope tags |
| 105 | `AnnouncementDetailScreen` | Full announcement display, attachments, edit/delete buttons by role |
| 106 | `CreateAnnouncementScreen` | Form validation, scope picker (role-restricted), league/hub selector, create vs edit mode, submission |
| 107 | `SettingsScreen` | All tiles render, role-based tile visibility (once implemented), sign-out flow, profile card |
| 108 | `UserManagementScreen` | User list, search, role filter, invite flow, deactivate/reactivate, pending invitations sheet |
| 109 | `UserDetailScreen` | Profile display, role editing (conditional), hub assignments, active toggle, save flow |
| 110 | `ManageLeaguesScreen` | League/hub/team CRUD, expansion tiles, delete confirmations, swipe-to-delete teams |

### 4.3 Provider Tests Needed

| # | Provider | What to Test |
|---|----------|--------------|
| 111 | `organizationProvider` | Fetches org from Firestore based on current user's orgId, handles null orgId |
| 112 | `hubCountProvider` / `teamCountProvider` | Correct counts returned, handles empty org |
| 113 | `activeUserCountProvider` | Counts only active users |
| 114 | `documentsProvider` | Filters by selectedLeague AND selectedCategory simultaneously |
| 115 | Auth providers (`currentUserProvider`, `authStateProvider`) | Auth state changes, null user handling |

### 4.4 Integration / E2E Tests Needed

| # | Flow | What to Test |
|---|------|--------------|
| 116 | Full sign-up → org creation → first login | End-to-end onboarding with Firebase emulator |
| 117 | Invite → accept → first login as Staff | Invitation token flow through to authenticated staff session |
| 118 | Create league → auto-create chat room → post message | Content creation pipeline |
| 119 | Upload document → view in list → open detail → download | Document lifecycle |
| 120 | Create announcement → push notification → deep link open | Announcement delivery pipeline |
| 121 | Role change → UI updates → permission enforcement | Admin changes staff to managerAdmin, verify access changes |
| 122 | Deactivate user → verify blocked access | Deactivated user should not be able to interact |
| 123 | Chat: send message → read receipt → unread count | Real-time messaging flow |
| 124 | DM: create DM room → send message → other user receives | Direct message lifecycle |

### 4.5 Edge Case & Error Tests Needed

| # | Scenario | What to Test |
|---|----------|--------------|
| 125 | Network failure during document upload | Progress callback, retry, error state |
| 126 | Concurrent message sends in same chat room | Firestore transaction atomicity on lastMessage |
| 127 | Duplicate invitation to same email | Prevention or handling |
| 128 | Expired invitation token acceptance | Graceful error message |
| 129 | User with no orgId tries to access org data | Null safety, redirect to onboarding |
| 130 | User removed from hub/team still has stale local state | Provider refresh after assignment change |
| 131 | Large message list performance (100+ messages in room) | Pagination, scroll performance |
| 132 | File upload exceeding size limits | Error handling, user feedback |
| 133 | Invalid file types on document upload | Validation before upload |
| 134 | Timestamp conversion edge cases in `_convertValue` | Null timestamps, invalid formats |

---

## Part 5: Priority Order (Recommended)

**Phase 1 — Security & Permissions (Critical)**
Tasks: 51–64 (PermissionService + Firestore rules), 65–72 (route guards), 60 (message impersonation fix)

**Phase 2 — Role-Scoped Views (High)**
Tasks: 18–19, 21–25, 26, 61–63 (scope filtering for Manager Admin and Staff)

**Phase 3 — Incomplete Flows (High)**
Tasks: 33–34 (invitation expiration), 14–15 (cascade deletes), 35–39 (chat media, doc versions, downloads), 16–17 (push notifications)

**Phase 4 — Missing Features (Medium)**
Tasks: 1–6 (Platform Owner), 40–50 (search, read receipts, typing indicators, password change, offline mode)

**Phase 5 — Test Coverage (Ongoing, parallel with above)**
Tasks: 73–134 (all test categories)
