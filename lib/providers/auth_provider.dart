import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Messaging service — should be overridden at the ProviderScope level with the
/// router instance so deep linking works.
final messagingServiceProvider =
    Provider<MessagingService>((ref) => MessagingService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final firebaseUser = authState.valueOrNull;
  if (firebaseUser == null) return null;
  return ref.read(authServiceProvider).getCurrentAppUser();
});
