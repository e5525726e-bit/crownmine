/// 執行期設定。全部透過 `--dart-define-from-file=dart_defines.json` 帶入，
/// 不把任何金鑰寫進程式碼或 git。
class Env {
  Env._();

  static const googlePlacesApiKey =
      String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@example.com',
  );

  static bool get isConfigured =>
      googlePlacesApiKey.isNotEmpty &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
