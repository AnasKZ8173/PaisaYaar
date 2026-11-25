import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authEvent = ref.watch(authStateStreamProvider).valueOrNull;
  return authEvent?.session?.user ?? ref.watch(authRepositoryProvider).currentUser;
});
