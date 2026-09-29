import 'dart:math' as math;

/// 台灣 22 個縣市的粗略範圍，用來把搜尋限制在使用者所在的縣市。
/// 範圍是外接矩形，會互相重疊；判斷所在縣市時取「包含該點且面積最小」的那個。
class TwCity {
  const TwCity(this.name, this.aliases, this.minLat, this.minLng, this.maxLat,
      this.maxLng);

  final String name;

  /// 地址裡可能出現的寫法（台／臺）。
  final List<String> aliases;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;
  double get _area => (maxLat - minLat) * (maxLng - minLng);

  bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  /// 地址是否屬於這個縣市。
  bool inAddress(String address) => aliases.any(address.contains);

  /// 文字裡是否提到這個縣市（例如使用者輸入「台中 火鍋」）。
  bool mentionedIn(String text) =>
      aliases.any((a) => text.contains(a.replaceAll(RegExp(r'[縣市]$'), '')));

  @override
  String toString() => name;
}

const List<TwCity> kTwCities = [
  TwCity('基隆市', ['基隆市'], 25.05, 121.62, 25.20, 121.80),
  TwCity('台北市', ['台北市', '臺北市'], 24.96, 121.48, 25.21, 121.67),
  TwCity('新北市', ['新北市'], 24.67, 121.28, 25.30, 122.01),
  TwCity('桃園市', ['桃園市'], 24.58, 120.98, 25.12, 121.48),
  TwCity('新竹市', ['新竹市'], 24.73, 120.88, 24.85, 121.03),
  TwCity('新竹縣', ['新竹縣'], 24.46, 120.90, 24.93, 121.40),
  TwCity('苗栗縣', ['苗栗縣'], 24.28, 120.62, 24.75, 121.20),
  TwCity('台中市', ['台中市', '臺中市'], 23.99, 120.45, 24.45, 121.45),
  TwCity('彰化縣', ['彰化縣'], 23.78, 120.25, 24.20, 120.72),
  TwCity('南投縣', ['南投縣'], 23.43, 120.60, 24.20, 121.35),
  TwCity('雲林縣', ['雲林縣'], 23.50, 120.10, 23.85, 120.70),
  TwCity('嘉義市', ['嘉義市'], 23.44, 120.40, 23.51, 120.50),
  TwCity('嘉義縣', ['嘉義縣'], 23.20, 120.10, 23.65, 120.95),
  TwCity('台南市', ['台南市', '臺南市'], 22.88, 120.03, 23.42, 120.70),
  TwCity('高雄市', ['高雄市'], 22.45, 120.15, 23.47, 121.05),
  TwCity('屏東縣', ['屏東縣'], 21.89, 120.40, 22.90, 120.95),
  TwCity('宜蘭縣', ['宜蘭縣'], 24.30, 121.30, 24.98, 122.00),
  TwCity('花蓮縣', ['花蓮縣'], 23.10, 120.95, 24.38, 121.78),
  TwCity('台東縣', ['台東縣', '臺東縣'], 21.90, 120.70, 23.45, 121.62),
  TwCity('澎湖縣', ['澎湖縣'], 23.18, 119.30, 23.80, 119.75),
  TwCity('金門縣', ['金門縣'], 24.15, 118.15, 24.55, 118.55),
  TwCity('連江縣', ['連江縣'], 25.93, 119.85, 26.40, 120.55),
];

/// 地址所屬的縣市（Google 回的地址會寫「臺中市西區…」）。
TwCity? cityOfAddress(String address) {
  for (final c in kTwCities) {
    if (c.inAddress(address)) return c;
  }
  return null;
}

/// 座標所在的縣市（粗略：外接矩形，重疊時取面積最小者）；不在台灣回傳 null。
/// 邊界附近可能判錯，App 會優先用附近店家的地址來判斷，這只是備用。
TwCity? cityAt(double lat, double lng) {
  TwCity? best;
  for (final c in kTwCities) {
    if (c.contains(lat, lng) && (best == null || c._area < best._area)) {
      best = c;
    }
  }
  return best;
}

/// 文字裡提到的縣市（「新北」要先於「台北」判斷，取最長的別名）。
TwCity? cityInText(String text) {
  TwCity? best;
  var bestLen = 0;
  for (final c in kTwCities) {
    for (final a in c.aliases) {
      final short = a.replaceAll(RegExp(r'[縣市]$'), '');
      final hit = text.contains(a) ? a.length : (text.contains(short) ? short.length : 0);
      if (hit > bestLen) {
        best = c;
        bestLen = hit;
      }
    }
  }
  return best;
}

/// 離座標最近的縣市中心（不在任何範圍內時用）。
TwCity nearestCity(double lat, double lng) {
  var best = kTwCities.first;
  var bestD = double.infinity;
  for (final c in kTwCities) {
    final d = math.pow(c.centerLat - lat, 2) + math.pow(c.centerLng - lng, 2);
    if (d < bestD) {
      bestD = d.toDouble();
      best = c;
    }
  }
  return best;
}
