import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_model.dart';
import '../data/profile_repository.dart';

final currentProfileProvider =
    AsyncNotifierProvider<CurrentProfileNotifier, UserProfile?>(
  CurrentProfileNotifier.new,
);

class CurrentProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return ref.read(profileRepositoryProvider).fetchOwnProfile(user.id);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final saved =
        await ref.read(profileRepositoryProvider).upsertProfile(profile);
    state = AsyncData(saved);
  }

  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    return ref.read(profileRepositoryProvider).uploadAvatar(
          userId: user.id,
          bytes: bytes,
          fileExtension: fileExtension,
        );
  }
}

final publicUserSearchProvider = FutureProvider.family<
    List<PublicProfileSearchResult>, String>((ref, query) async {
  if (query.trim().length < 4) return const [];
  return ref.read(profileRepositoryProvider).searchPublicProfiles(query);
});
