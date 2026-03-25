import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/authorized_firestore_service.dart';
import '../services/permission_service.dart';
import '../models/league.dart';
import '../models/hub.dart';
import '../models/team.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../models/document.dart';
import '../models/announcement.dart';
import '../models/organization.dart';
import '../models/app_user.dart';
import '../models/invitation.dart';
import 'auth_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

final permissionServiceProvider =
    Provider<PermissionService>((ref) => const PermissionService());

/// Authorized wrapper — use this for all write operations.
final authorizedFirestoreServiceProvider =
    Provider<AuthorizedFirestoreService>((ref) => AuthorizedFirestoreService(
          ref.read(firestoreServiceProvider),
          ref.read(permissionServiceProvider),
        ));

final selectedLeagueProvider = StateProvider<String?>((ref) => null);
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

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

final hubsProvider =
    StreamProvider.family<List<Hub>, String>((ref, leagueId) {
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
/// league/event rooms (further scoping by league→hub can be added later).
final chatRoomsProvider = StreamProvider<List<ChatRoom>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  final appUser = ref.watch(currentUserProvider).valueOrNull;
  final ps = ref.read(permissionServiceProvider);
  return ref.watch(firestoreServiceProvider).getChatRooms(orgId).map((rooms) {
    if (appUser == null) return rooms;
    return rooms.where((room) => ps.canViewChatRoom(appUser, room)).toList();
  });
});

/// Stream of a single chat room by ID.
final chatRoomProvider = StreamProvider.family<ChatRoom?, String>((ref, roomId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).getChatRoom(orgId, roomId);
});

/// Stream of messages for a given room ID.
final messagesProvider = StreamProvider.family<List<Message>, String>((ref, roomId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).getMessages(orgId, roomId);
});

/// Documents, scope-filtered by user role. superAdmin+ sees all.
/// managerAdmin/staff only see docs scoped to their hubs (or unscoped docs).
final documentsProvider = StreamProvider<List<Document>>((ref) {
  final leagueId = ref.watch(selectedLeagueProvider);
  final category = ref.watch(selectedCategoryProvider);
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  final appUser = ref.watch(currentUserProvider).valueOrNull;
  final ps = ref.read(permissionServiceProvider);
  return ref.watch(firestoreServiceProvider).documentsStream(
        orgId,
        leagueId: leagueId,
        category: category == 'All' ? null : category,
      ).map((docs) {
    if (appUser == null) return docs;
    return docs
        .where((d) =>
            ps.canViewDocument(appUser, leagueId: d.leagueId, hubId: d.hubId))
        .toList();
  });
});

/// Stream of a single document by ID.
final documentProvider =
    StreamProvider.family<Document?, String>((ref, docId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).getDocumentById(orgId, docId);
});

/// All announcements for the current org, pinned first then newest.
/// Scope-filtered: staff/managerAdmin only see announcements for their hubs.
final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  final appUser = ref.watch(currentUserProvider).valueOrNull;
  final ps = ref.read(permissionServiceProvider);
  return ref.watch(firestoreServiceProvider).getAnnouncements(orgId).map((list) {
    if (appUser == null) return list;
    return list
        .where((a) => ps.canViewAnnouncement(
              appUser,
              scope: a.scope,
              leagueId: a.leagueId,
              hubId: a.hubId,
            ))
        .toList();
  });
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

/// Stream of user names currently typing in a given room.
final typingUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (orgId == null || userId == null) return Stream.value([]);
  return ref.read(firestoreServiceProvider).typingUsersStream(orgId, roomId, userId);
});

/// Stream of unread message count for a given room, scoped to the current user.
final unreadCountProvider =
    StreamProvider.family<int, String>((ref, roomId) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (orgId == null || userId == null) return Stream.value(0);
  return ref.read(firestoreServiceProvider).unreadCountStream(orgId, roomId, userId);
});

final pendingInviteCountProvider = Provider<int>((ref) {
  final invitations = ref.watch(invitationsProvider).valueOrNull ?? [];
  return invitations.where((i) => i.status == InvitationStatus.pending).length;
});

final activeUserCountProvider = FutureProvider<int>((ref) async {
  final org = await ref.watch(organizationProvider.future);
  if (org == null) return 0;
  return ref.read(firestoreServiceProvider).getActiveUserCount(org.id);
});
