import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

/// Initializes Supabase once at app startup when environment variables are set.
class SupabaseConfig {
  SupabaseConfig._();

  static bool _initialized = false;

  static bool get isReady => _initialized && Env.isConfigured;

  static Future<void> initialize() async {
    if (_initialized || !Env.isConfigured) return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    _initialized = true;
  }
}

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!SupabaseConfig.isReady) return null;
  return Supabase.instance.client;
});
