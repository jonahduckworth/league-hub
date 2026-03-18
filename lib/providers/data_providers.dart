import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/league.dart';
import '../models/chat_room.dart';
import '../models/document.dart';
import '../models/announcement.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

final selectedLeagueProvider = StateProvider<String?>((ref) => null);
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

// Mock org id for demo - replace with actual user's orgId after auth
const mockOrgId = 'demo-org-1';

final leaguesProvider = StreamProvider<List<League>>((ref) {
  return ref.watch(firestoreServiceProvider).leaguesStream(mockOrgId);
});

final chatRoomsProvider = StreamProvider<List<ChatRoom>>((ref) {
  return ref.watch(firestoreServiceProvider).chatRoomsStream(mockOrgId);
});

final documentsProvider = StreamProvider<List<Document>>((ref) {
  final leagueId = ref.watch(selectedLeagueProvider);
  final category = ref.watch(selectedCategoryProvider);
  return ref.watch(firestoreServiceProvider).documentsStream(
        mockOrgId,
        leagueId: leagueId,
        category: category == 'All' ? null : category,
      );
});

final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final leagueId = ref.watch(selectedLeagueProvider);
  return ref.watch(firestoreServiceProvider).announcementsStream(mockOrgId, leagueId: leagueId);
});
