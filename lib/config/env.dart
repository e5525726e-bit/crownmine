/// 執行期設定。全部透過 `--dart-define-from-file=dart_defines.json` 帶入，
/// 不把任何金鑰寫進程式碼或 git。
class Env {
  Env._();

  /// 只用於地圖底圖（Maps SDK / Maps JavaScript）。店家資料一律經由後端函式，
  /// 前端不再直接呼叫 Places API。
  static const googlePlacesApiKey =
      String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@example.com',
  );

  /// 網頁版網址，用來產生店家分享連結。
  static const webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://e5525726e-bit.github.io/crownmine/',
  );

  static String placeShareUrl(String placeId) => '$webBaseUrl?place=$placeId';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
