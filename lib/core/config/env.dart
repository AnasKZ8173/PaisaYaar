/// Environment configuration read from `--dart-define` flags,
/// with local project defaults for convenient `flutter run`.
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kkdibhhjyhurfknyfiwn.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_9l3Qu7H5ZHja3irqjLSWag_XIaeY82r',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
