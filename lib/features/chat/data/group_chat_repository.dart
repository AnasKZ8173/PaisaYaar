import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

class GroupMessageModel {
  const GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.body,
    required this.isAnnouncement,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String body;
  final bool isAnnouncement;
  final DateTime createdAt;

  factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
    return GroupMessageModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String,
      isAnnouncement: (json['is_announcement'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class GroupChatRepository {
  GroupChatRepository(this._client);

  final SupabaseClient? _client;

  Stream<List<GroupMessageModel>> watchMessages(String groupId) {
    final client = _client;
    if (client == null) return const Stream.empty();
    return client
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .limit(100)
        .map(
          (rows) => rows
              .where((r) => r['is_deleted'] != true)
              .map(GroupMessageModel.fromJson)
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String groupId,
    required String body,
    bool isAnnouncement = false,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    await client.from('group_messages').insert({
      'group_id': groupId,
      'sender_id': uid,
      'body': body.trim(),
      'is_announcement': isAnnouncement,
    });
  }
}

final groupChatRepositoryProvider = Provider<GroupChatRepository>((ref) {
  return GroupChatRepository(ref.watch(supabaseClientProvider));
});

final groupMessagesStreamProvider =
    StreamProvider.family<List<GroupMessageModel>, String>((ref, groupId) {
  return ref.read(groupChatRepositoryProvider).watchMessages(groupId);
});
