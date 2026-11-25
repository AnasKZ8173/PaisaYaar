import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';

final myGroupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(groupRepositoryProvider).fetchMyGroups();
});

final pendingInvitesProvider =
    FutureProvider<List<GroupInviteModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(groupRepositoryProvider).fetchPendingInvites();
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMemberModel>, String>((ref, groupId) async {
  return ref.read(groupRepositoryProvider).fetchMembers(groupId);
});

final groupSettingsProvider =
    FutureProvider.family<GroupSettingsModel, String>((ref, groupId) async {
  return ref.read(groupRepositoryProvider).fetchSettings(groupId);
});

final groupActivityProvider =
    FutureProvider.family<List<GroupActivityModel>, String>(
        (ref, groupId) async {
  return ref.read(groupRepositoryProvider).fetchActivity(groupId);
});

final groupDashboardSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const {};
  return ref.read(groupRepositoryProvider).fetchDashboardSummary();
});

/// Keeps group members synchronized in real time when someone accepts an invite or is updated.
final groupMembersRealtimeSyncProvider =
    StreamProvider.family<void, String>((ref, groupId) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const Stream.empty();
  return client
      .from('group_members')
      .stream(primaryKey: ['id'])
      .eq('group_id', groupId)
      .map((_) {
        ref.invalidate(groupMembersProvider(groupId));
      });
});

/// Keeps group settings synchronized in real time.
final groupSettingsRealtimeSyncProvider =
    StreamProvider.family<void, String>((ref, groupId) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const Stream.empty();
  return client
      .from('group_settings')
      .stream(primaryKey: ['group_id'])
      .eq('group_id', groupId)
      .map((_) {
        ref.invalidate(groupSettingsProvider(groupId));
      });
});
