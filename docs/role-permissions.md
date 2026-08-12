# League Hub roles and platform ownership

This is the canonical product and engineering policy for League Hub. UI gates,
`PermissionService`, Cloud Functions, Firestore rules, and Storage rules should
all implement this model.

## Core rules

- Every permission requires an active account.
- Platform Owner is the only role that can create a new league.
- Admin controls an existing organization, but cannot create a league or manage
  another Admin.
- Manager permissions are limited to explicitly assigned leagues, hubs, and
  teams. Missing assignments fail closed.
- Invitation records persist the exact league, hub, and team scope that the
  accepted account receives. Pending invitations created before this schema
  must be reissued (or backfilled) before acceptance.
- Staff can view and participate in assigned content and can start direct
  messages, but cannot create managed group rooms or publish content.
- Nobody manages their own account through User Management. Personal details
  are edited through Profile.

## Permission matrix

| Capability | Platform Owner | Admin | Manager | Staff |
| --- | --- | --- | --- | --- |
| Access web admin | Any organization | Own organization | No | No |
| Manage organization settings | Any organization | Own organization | No | No |
| Delete organization | Yes | No | No | No |
| Create league | Yes | No | No | No |
| Update or delete league | Yes | Own organization | No | No |
| Create hub | Yes | Own organization | No | No |
| Update hub | Yes | Own organization | Assigned hubs | No |
| Delete hub | Yes | Own organization | No | No |
| Create, update, or delete team | Yes | Own organization | Assigned hubs | No |
| Manage users | Admin, Manager, Staff | Manager and Staff | Staff fully inside assigned hubs and teams | No |
| Change a user's role | Admin, Manager, Staff | Manager or Staff | No | No |
| Invite users | Admin, Manager, Staff | Manager or Staff | Staff into assigned hubs and teams | No |
| Create announcement | Any valid scope | Any valid scope in org | Assigned scope | No |
| Edit announcement | Any | Any | Own, in assigned scope | No |
| Delete or pin announcement | Yes | Yes | No | No |
| Upload policy | Any valid scope | Any valid scope in org | Assigned scope | No |
| Edit policy | Any | Any | Own, in assigned scope | No |
| Delete policy | Yes | Yes | No | No |
| Create managed chat room | Any valid scope | Any valid scope in org | Assigned scope | No |
| Edit or archive managed room | Any | Any | Assigned scope | No |
| Start direct message | Yes | Yes | Yes | Yes |
| Send messages | Visible rooms | Visible rooms | Visible rooms | Visible rooms |
| Edit/delete own message | Yes | Yes | Yes | Yes |
| Delete another user's message | Yes | Yes | No | No |
| View schedule | All | All in org | Assigned scope | Assigned scope |
| Configure or run schedule sync | Yes | Yes | No | No |
| Change app icon | Own device | Own device | Own device | Own device |

Organization creation during first-time onboarding is a bootstrap flow that
creates the organization's first Platform Owner. Once an organization exists,
only Platform Owner can delete it.

## Web versus mobile

The platforms are intentionally complementary rather than exact copies.

### Web-first administration

- Organization-wide people management and invitations
- League, hub, and team structure changes
- Schedule source configuration, sync controls, and sync health
- Bulk review of announcements and policies
- Destructive organization and structure actions

### Mobile-first operations

- Upcoming games, results, and game detail
- Reading and posting scoped announcements
- Reading and uploading scoped policies
- Direct messages and managed chat-room participation
- Team rosters and assigned-team operations
- Personal profile, notifications, privacy, and device app icon

Useful overlap is intentional: Admins and Managers may need to make a scoped
announcement, update a roster, or inspect structure from the rink. A feature is
not removed from mobile merely because it is also available on web.

## Known parity and privacy follow-up

- Web should eventually add managed chat-room administration (create, edit,
  archive, and membership review). Chat participation and direct messaging
  should remain mobile-first.
- Mobile does not need schedule-source configuration or organization deletion;
  those are safer and clearer in the web admin.
- Firestore list queries for chat-room, policy, announcement, and schedule
  metadata currently load the organization collection and apply assignment
  visibility in the client. Writes, messages, files, and individual content
  access are scope-checked, but fully server-filtered metadata requires adding a
  queryable visibility field and backfilling existing records.
