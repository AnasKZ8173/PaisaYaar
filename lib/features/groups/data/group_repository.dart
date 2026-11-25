import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import 'group_models.dart';

class GroupRepository {
  GroupRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  Future<List<GroupModel>> fetchMyGroups() async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await client
        .from('groups')
        .select('*, group_members!inner(user_id, status)')
        .eq('group_members.user_id', uid)
        .eq('group_members.status', 'active')
        .eq('is_archived', false)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GroupModel.fromJson)
        .toList();
  }

  Future<List<GroupInviteModel>> fetchPendingInvites() async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await client
        .from('group_invites')
        .select('*, groups(name, category)')
        .eq('invitee_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GroupInviteModel.fromJson)
        .toList();
  }

  Future<String> createGroup({
    required String name,
    String description = '',
    String category = 'General',
    String currency = 'PKR',
  }) async {
    final client = _requireClient;
    final id = await client.rpc('create_group_with_owner', params: {
      'p_name': name.trim(),
      'p_description': description.trim(),
      'p_category': category,
      'p_currency': currency,
    });
    return id as String;
  }

  Future<List<GroupMemberModel>> fetchMembers(String groupId) async {
    final client = _requireClient;
    final rows = await client.rpc(
      'get_group_members_with_profiles',
      params: {'p_group_id': groupId},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GroupMemberModel.fromJson)
        .toList();
  }

  Future<GroupSettingsModel> fetchSettings(String groupId) async {
    final client = _requireClient;
    final row = await client
        .from('group_settings')
        .select()
        .eq('group_id', groupId)
        .single();
    return GroupSettingsModel.fromJson(row);
  }

  Future<void> updateSettings(GroupSettingsModel settings) async {
    final client = _requireClient;
    await client
        .from('group_settings')
        .update(settings.toUpdateJson())
        .eq('group_id', settings.groupId);
  }

  Future<void> inviteUser({
    required String groupId,
    required String inviteeUserId,
  }) async {
    final client = _requireClient;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    await client.from('group_invites').insert({
      'group_id': groupId,
      'inviter_id': uid,
      'invitee_id': inviteeUserId,
    });
  }

  Future<void> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final client = _requireClient;
    await client.rpc('respond_to_group_invite', params: {
      'p_invite_id': inviteId,
      'p_accept': accept,
    });
  }

  Future<void> updateMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    final client = _requireClient;
    await client
        .from('group_members')
        .update({'role': role})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final client = _requireClient;
    await client
        .from('group_members')
        .update({'status': 'removed'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> deleteGroup(String groupId) async {
    final client = _requireClient;
    await client.from('groups').delete().eq('id', groupId);
  }

  Future<List<GroupActivityModel>> fetchActivity(String groupId) async {
    final client = _requireClient;
    final rows = await client
        .from('group_activity')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GroupActivityModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchDashboardSummary() async {
    final client = _requireClient;
    final res = await client.rpc('get_my_group_dashboard_summary');
    if (res is Map<String, dynamic>) return res;
    return const {};
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(ref.watch(supabaseClientProvider));
});
