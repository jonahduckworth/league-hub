import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
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

final chatRoomsProvider = StreamProvider<List<ChatRoom>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).getChatRooms(orgId);
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

final documentsProvider = StreamProvider<List<Document>>((ref) {
  final leagueId = ref.watch(selectedLeagueProvider);
  final category = ref.watch(selectedCategoryProvider);
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).documentsStream(
        orgId,
        leagueId: leagueId,
        category: category == 'All' ? null : category,
      );
});

/// All announcements for the current org, pinned first then newest.
final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).getAnnouncements(orgId);
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

final pendingInviteCountProvider = Provider<int>((ref) {
  final invitations = ref.watch(invitationsProvider).valueOrNull ?? [];
  return invitations.where((i) => i.status == InvitationStatus.pending).length;
});

final activeUserCountProvider = FutureProvider<int>((ref) async {
  final org = await ref.watch(organizationProvider.future);
  if (org == null) return 0;
  return ref.read(firestoreServiceProvider).getActiveUserCount(org.id);
});
