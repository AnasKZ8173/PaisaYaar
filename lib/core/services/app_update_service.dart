import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isForceUpdate,
  });

  final int latestVersionCode;
  final String latestVersionName;
  final String downloadUrl;
  final String releaseNotes;
  final bool isForceUpdate;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersionCode: (json['latest_version_code'] as num).toInt(),
      latestVersionName: (json['latest_version_name'] as String?) ?? '',
      downloadUrl: (json['download_url'] as String?) ?? '',
      releaseNotes: (json['release_notes'] as String?) ?? '',
      isForceUpdate: (json['is_force_update'] as bool?) ?? false,
    );
  }
}

class AppUpdateService {
  AppUpdateService(this._client);

  final SupabaseClient? _client;

  Future<AppUpdateInfo?> checkForUpdate() async {
    final client = _client;
    if (client == null) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 1;

      final row = await client
          .from('app_updates')
          .select()
          .eq('is_active', true)
          .order('latest_version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      final update = AppUpdateInfo.fromJson(row);
      if (update.latestVersionCode > currentCode &&
          update.downloadUrl.isNotEmpty) {
        return update;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(ref.watch(supabaseClientProvider));
});

final availableAppUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  return ref.read(appUpdateServiceProvider).checkForUpdate();
});
