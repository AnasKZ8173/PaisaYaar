import 'package:flutter_riverpod/flutter_riverpod.dart';
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
