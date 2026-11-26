import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import 'profile_model.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    return client;
  }

  Future<UserProfile?> fetchOwnProfile(String userId) async {
    final client = _client;
    if (client == null) return null;

    final data = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> upsertProfile(UserProfile profile) async {
    final client = _requireClient;
    final data = await client
        .from('profiles')
        .upsert(profile.toUpsertJson())
        .select()
        .single();

    await client.from('user_notification_settings').upsert({
      'user_id': profile.id,
    });

    return UserProfile.fromJson(data);
  }

  Future<bool> isPublicIdAvailable(String candidate) async {
    final client = _requireClient;
    final result = await client.rpc(
      'is_public_id_available',
      params: {'candidate': candidate.trim().toLowerCase()},
    );
    return result == true;
  }

  Future<List<PublicProfileSearchResult>> searchPublicProfiles(
    String query,
  ) async {
    final client = _requireClient;
    final trimmed = query.trim();
    if (trimmed.length < 4) return const [];

    final rows = await client.rpc(
      'search_public_profiles',
      params: {'search_query': trimmed},
    );

    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(PublicProfileSearchResult.fromJson)
        .toList();
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final client = _requireClient;
    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return client.storage.from('avatars').getPublicUrl(path);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});
