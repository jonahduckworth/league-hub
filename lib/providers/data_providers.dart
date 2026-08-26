import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/authorized_firestore_service.dart';
import '../services/chat_room_functions_service.dart';

import 'permission_provider.dart';
export 'permission_provider.dart';
import '../models/league.dart';
import '../models/hub.dart';
import '../models/team.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../models/policy.dart';
import '../models/announcement.dart';
import '../models/organization.dart';
import '../models/app_user.dart';
import '../models/invitation.dart';
import '../models/schedule_event.dart';
import '../models/schedule_team_logos.dart';
import 'auth_provider.dart';

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// Authorized wrapper — use this for all write operations.
final authorizedFirestoreServiceProvider =
    Provider<AuthorizedFirestoreService>((ref) => AuthorizedFirestoreService(
          ref.read(firestoreServiceProvider),
          ref.read(permissionServiceProvider),
        ));

final chatRoomFunctionsServiceProvider =
    Provider<ChatRoomFunctionsClient>((ref) => ChatRoomFunctionsService());

final selectedLeagueProvider = StateProvider<String?>((ref) => null);
final selectedPolicyCategoryProvider = StateProvider<String>((ref) => 'All');

final organizationProvider = FutureProvider<Organization?>((ref) async {
  final appUser = await ref.watch(currentUserProvider.future);
  if (appUser?.orgId == null) return null;
  return ref.read(firestoreServiceProvider).getOrganization(appUser!.orgId!);
});

final leaguesProvider = StreamProvider<List<League>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.read(firestoreServiceProvider).getLeagues(orgId);
});

// --- Hubs (per league) ---

final hubsProvider = StreamProvider.family<List<Hub>, String>((ref, leagueId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.read(firestoreServiceProvider).getHubs(orgId, leagueId);
});

// --- Teams (per hub) ---

typedef TeamsParams = ({String leagueId, String hubId});

final teamsProvider =
    StreamProvider.family<List<Team>, TeamsParams>((ref, params) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref
      .read(firestoreServiceProvider)
      .getTeams(orgId, params.leagueId, params.hubId);
});

/// All teams in the signed-in user's organization.
///
/// Used when a manager is assigned directly to teams so scoped forms can
/// resolve the parent hubs without exposing unrelated Structure choices.
final organizationTeamsProvider = FutureProvider<List<Team>>((ref) async {
  final org = await ref.watch(organizationProvider.future);
  if (org == null) return const [];
  return ref.read(firestoreServiceProvider).getAllTeamsFlat(org.id);
});

// --- Counts ---

final hubCountProvider = FutureProvider<int>((ref) async {
  final org = await ref.watch(organizationProvider.future);
  if (org == null) return 0;
  return ref.read(firestoreServiceProvider).getAllHubsCount(org.id);
});

final teamCountProvider = FutureProvider<int>((ref) async {
  final org = await ref.watch(organizationProvider.future);
  if (org == null) return 0;
  return ref.read(firestoreServiceProvider).getAllTeamsCount(org.id);
});

/// Chat rooms, scope-filtered by the current user's role and hub assignments.
/// superAdmin+ sees all rooms. managerAdmin/staff see DMs they're in, plus
/// league rooms for leagues they belong to (via denormalized leagueIds on
/// AppUser) and event rooms for the entire org.
final chatRoomsProvider = StreamProvider<List<ChatRoom>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  final appUser = ref.watch(currentUserProvider).valueOrNull;
  final ps = ref.read(permissionServiceProvider);
  if (appUser == null) return Stream.value([]);
  return ref
      .watch(firestoreServiceProvider)
      .getVisibleChatRooms(orgId, appUser)
      .map((rooms) {
    return rooms.where((room) {
      if (!ps.canViewChatRoom(appUser, room)) return false;
      if (room.type != ChatRoomType.direct) return true;
      return !room.participants.any(
        (id) => id != appUser.id && appUser.blockedUserIds.contains(id),
      );
    }).toList();
  });
});

/// Stream of a single chat room by ID.
final chatRoomProvider =
    StreamProvider.family<ChatRoom?, String>((ref, roomId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).getChatRoom(orgId, roomId);
});

/// Stream of messages for a given room ID.
final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, roomId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  final blockedUserIds =
      ref.watch(currentUserProvider).valueOrNull?.blockedUserIds.toSet() ??
          const <String>{};
  return ref.watch(firestoreServiceProvider).getMessages(orgId, roomId).map(
        (messages) => messages
            .where((message) => !blockedUserIds.contains(message.senderId))
            .toList(),
      );
});

/// Policy, scope-filtered by user role. superAdmin+ sees all.
/// managerAdmin/staff see organization-wide policies plus assigned hub/team policies.
final policiesProvider = StreamProvider<List<Policy>>((ref) {
  final leagueId = ref.watch(selectedLeagueProvider);
  final category = ref.watch(selectedPolicyCategoryProvider);
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  final appUser = ref.watch(currentUserProvider).valueOrNull;
  final ps = ref.read(permissionServiceProvider);
  return ref
      .watch(firestoreServiceProvider)
      .policiesStream(
        orgId,
        leagueId: leagueId,
        category: category == 'All' ? null : category,
      )
      .map((policies) {
    if (appUser == null) return policies;
    return policies
        .where((d) => ps.canViewPolicy(appUser,
            leagueId: d.leagueId, hubId: d.hubId, teamId: d.teamId))
        .toList();
  });
});

/// Stream of a single policy by ID.
final policyProvider = StreamProvider.family<Policy?, String>((ref, policyId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).getPolicyById(orgId, policyId);
});

/// All announcements for the current org, pinned first then newest.
/// Scope-filtered: staff/managerAdmin only see announcements for their hubs.
final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  final appUser = ref.watch(currentUserProvider).valueOrNull;
  final ps = ref.read(permissionServiceProvider);
  return ref
      .watch(firestoreServiceProvider)
      .getAnnouncements(orgId)
      .map((list) {
    if (appUser == null) return list;
    return list
        .where((a) => ps.canViewAnnouncement(
              appUser,
              scope: a.scope,
              leagueId: a.leagueId,
              hubId: a.hubId,
              teamId: a.teamId,
            ))
        .toList();
  });
});

/// Games from RAMP, scoped to the user's assigned teams, hubs, or legacy
/// league assignment. Elevated admins can see the full organization schedule.
final scheduleEventsProvider = StreamProvider<List<ScheduleEvent>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  final appUser = ref.watch(currentUserProvider).valueOrNull;
  final permissions = ref.read(permissionServiceProvider);
  return ref
      .watch(firestoreServiceProvider)
      .getScheduleEvents(orgId)
      .map((events) {
    if (appUser == null) return events;
    return events
        .where((event) => permissions.canViewScheduleEvent(
              appUser,
              teamIds: event.teamIds,
              hubIds: event.hubIds,
              leagueIds: event.leagueIds,
            ))
        .toList();
  });
});

final upcomingScheduleEventsProvider = Provider<List<ScheduleEvent>>((ref) {
  final now = DateTime.now();
  return (ref.watch(scheduleEventsProvider).valueOrNull ?? [])
      .where((event) => event.isUpcomingAt(now))
      .toList();
});

final scheduleTeamLogosProvider = FutureProvider<ScheduleTeamLogos>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return const ScheduleTeamLogos();
  return ref.watch(firestoreServiceProvider).getScheduleTeamLogos(orgId);
});

// --- User Management ---

final orgUsersProvider = StreamProvider<List<AppUser>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).getOrgUsers(orgId);
});

final invitationsProvider = StreamProvider<List<Invitation>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).getInvitations(orgId);
});

final activePendingInvitationsProvider = Provider<List<Invitation>>((ref) {
  final invitations = ref.watch(invitationsProvider).valueOrNull ?? [];
  final users = ref.watch(orgUsersProvider).valueOrNull ?? [];
  final activeEmails = users
      .map((user) => user.email.trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toSet();

  return invitations.where((invite) {
    if (invite.status != InvitationStatus.pending) return false;
    final inviteEmail = invite.email.trim().toLowerCase();
    return inviteEmail.isEmpty || !activeEmails.contains(inviteEmail);
  }).toList();
});

/// Stream of user names currently typing in a given room.
final typingUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (orgId == null || userId == null) return Stream.value([]);
  return ref
      .read(firestoreServiceProvider)
      .typingUsersStream(orgId, roomId, userId);
});

/// Stream of unread message count for a given room, scoped to the current user.
final unreadCountProvider = StreamProvider.family<int, String>((ref, roomId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (orgId == null || currentUser == null) return Stream.value(0);
  return ref.read(firestoreServiceProvider).unreadCountStream(
        orgId,
        roomId,
        currentUser.id,
        blockedUserIds: currentUser.blockedUserIds.toSet(),
      );
});

final pendingInviteCountProvider = Provider<int>((ref) {
  return ref.watch(activePendingInvitationsProvider).length;
});

final activeUserCountProvider = FutureProvider<int>((ref) async {
  final org = await ref.watch(organizationProvider.future);
  if (org == null) return 0;
  return ref.read(firestoreServiceProvider).getActiveUserCount(org.id);
});
