import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/league.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../models/document.dart';
import '../models/announcement.dart';
import '../models/organization.dart';
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
  return ref.watch(firestoreServiceProvider).leaguesStream(orgId);
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

final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final leagueId = ref.watch(selectedLeagueProvider);
  final orgId = ref.watch(organizationProvider).valueOrNull?.id;
  if (orgId == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).announcementsStream(orgId, leagueId: leagueId);
});
