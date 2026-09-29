import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place.dart';
import '../models/tw_city.dart';

class PlacesException implements Exception {
  PlacesException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 店家資料的存取層。
///
/// 所有請求都走 Supabase 的後端函式 `places`（見 supabase/functions/places），
/// Google 金鑰只存在伺服器；後端負責快取（最多 30 天）與每日用量限制。
/// 回傳格式與 Google Places API (New) 相同，後端也已只留餐飲業，
/// 前端再用 [isFoodPlace] 過濾一次當保險。
class PlacesService {
  PlacesService({
    required this.baseUrl,
    required this.headers,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// 例：https://xxxx.supabase.co/functions/v1/places
  final String baseUrl;

  /// 每次請求的標頭（帶 Supabase 的 apikey 與使用者登入權杖，用來計算用量）。
  final Map<String, String> Function() headers;
  final http.Client _client;

  Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json',
        ...headers(),
      };

  /// 文字搜尋。[type] 是 Google 類型（限定該類型）、'any' 表示不限、null 則預設餐廳。
  /// [city] 有給時嚴格限制在該縣市範圍內（並再用地址過濾一次）；
  /// 否則有座標時以該點為中心（[radiusMeters] 內優先）。
  Future<List<Place>> searchText(
    String query, {
    double? lat,
    double? lng,
    double? radiusMeters,
    String? type,
    TwCity? city,
  }) async {
    // 關鍵字搜尋（type 為 any，例如手搖飲料）：Google 沒有給這類店餐飲類型，不再過濾
    final loose = type == 'any';
    final res = await _client.post(
      Uri.parse('$baseUrl/search'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'query': query,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusMeters != null) 'radius': radiusMeters,
        if (type != null) 'type': type,
        if (city != null)
          'bounds': {
            'minLat': city.minLat,
            'minLng': city.minLng,
            'maxLat': city.maxLat,
            'maxLng': city.maxLng,
          },
      }),
    );
    final places = _parsePlaces(res, loose: loose);
    if (city == null) return places;
    return places.where((p) => city.inAddress(p.address)).toList();
  }

  /// 附近搜尋。[types] 為 Google 類型清單；空的話由後端用預設的餐飲類型。
  Future<List<Place>> searchNearby({
    required double lat,
    required double lng,
    double radiusMeters = 1000,
    List<String> types = const [],
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/nearby'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        'radius': radiusMeters,
        if (types.isNotEmpty) 'types': types,
      }),
    );
    return _parsePlaces(res);
  }

  Future<Place> getDetails(String placeId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/details?id=${Uri.encodeQueryComponent(placeId)}'),
      headers: headers(),
    );
    _throwIfError(res);
    return Place.fromPlacesApi(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// 店家照片網址：後端會轉址到實際圖片，網址裡沒有任何金鑰。
  String photoUrl(PlacePhoto photo, {int maxWidth = 800}) =>
      '$baseUrl/photo?name=${Uri.encodeQueryComponent(photo.name)}&w=$maxWidth';

  List<Place> _parsePlaces(http.Response res, {bool loose = false}) {
    _throwIfError(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (json['places'] as List?) ?? const [];
    return list
        .map((p) => Place.fromPlacesApi(p as Map<String, dynamic>))
        .where((p) => loose || p.isFood)
        .toList();
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String detail = res.body;
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      detail = ((j['error'] as Map<String, dynamic>?)?['message'] as String?) ?? detail;
    } catch (_) {}
    if (res.statusCode == 429 || res.statusCode == 401) throw PlacesException(detail);
    throw PlacesException('店家資料讀取失敗 (${res.statusCode})：$detail');
  }
}
