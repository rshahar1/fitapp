/// Build-time configuration, passed with `--dart-define-from-file=env/dev.json`.
///
/// Empty values disable cloud backup; the app then works fully offline.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// True only when every cloud-sync key is set.
  static bool get isSyncConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      googleWebClientId.isNotEmpty;
}
