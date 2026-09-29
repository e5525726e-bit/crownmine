import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place.dart';

class PlacesException implements Exception {
  PlacesException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Google Places API (New) 的最小封裝。
///
/// 兩個刻意的限制：
/// 1. FieldMask 完全不要求 `rating`、`userRatingCount`、`reviews`，
///    所以 Google 的評價資料從頭到尾不會進到 App。
/// 2. 搜尋結果一律再用 [isFoodPlace] 過濾，只留下餐飲業。
class PlacesService {
  PlacesService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _base = 'https://places.googleapis.com/v1';

  static const searchFieldMask = 'places.id,places.displayName,'
      'places.formattedAddress,places.location,places.types,'
      'places.primaryType,places.primaryTypeDisplayName,places.photos,'
      'places.businessStatus,places.googleMapsUri,places.priceLevel';

  static const detailFieldMask = 'id,displayName,formattedAddress,location,'
      'types,primaryType,primaryTypeDisplayName,photos,businessStatus,'
      'googleMapsUri,priceLevel,regularOpeningHours,nationalPhoneNumber,'
      'websiteUri';

  /// 台灣本島加離島的大致範圍，沒有定位時用來偏向台灣的結果。
  static const _taiwanBias = {
    'rectangle': {
      'low': {'latitude': 21.8, 'longitude': 118.2},
      'high': {'latitude': 26.4, 'longitude': 122.1},
    },
  };

  /// 沒有位置時只能靠 Nearby Search 的類型清單。
  static const nearbyTypes = [
    'restaurant',
    'cafe',
    'bakery',
    'bar',
    'meal_takeaway',
    'meal_delivery',
  ];

  Map<String, String> _headers(String fieldMask) => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': fieldMask,
      };

  Future<List<Place>> searchText(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{
      'textQuery': query,
      'includedType': 'restaurant',
      'regionCode': 'TW',
      'languageCode': 'zh-TW',
      'pageSize': 20,
      'locationBias': (lat != null && lng != null)
          ? {
              'circle': {
                'center': {'latitude': lat, 'longitude': lng},
                'radius': 5000.0,
              },
            }
          : _taiwanBias,
    };
    final res = await _client.post(
      Uri.parse('$_base/places:searchText'),
      headers: _headers(searchFieldMask),
      body: jsonEncode(body),
    );
    return _parsePlaces(res);
  }

  Future<List<Place>> searchNearby({
    required double lat,
    required double lng,
    double radiusMeters = 1000,
  }) async {
    final body = {
      'includedTypes': nearbyTypes,
      'maxResultCount': 20,
      'languageCode': 'zh-TW',
      'regionCode': 'TW',
      'rankPreference': 'DISTANCE',
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radiusMeters,
        },
      },
    };
    final res = await _client.post(
      Uri.parse('$_base/places:searchNearby'),
      headers: _headers(searchFieldMask),
      body: jsonEncode(body),
    );
    return _parsePlaces(res);
  }

  Future<Place> getDetails(String placeId) async {
    final res = await _client.get(
      Uri.parse('$_base/places/$placeId?languageCode=zh-TW&regionCode=TW'),
      headers: _headers(detailFieldMask),
    );
    _throwIfError(res);
    return Place.fromPlacesApi(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// 店家照片網址。Google 會回 302 轉到實際圖片，`Image.network` 會自動跟隨。
  String photoUrl(PlacePhoto photo, {int maxWidth = 800}) =>
      '$_base/${photo.name}/media?maxWidthPx=$maxWidth&key=$apiKey';

  List<Place> _parsePlaces(http.Response res) {
    _throwIfError(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (json['places'] as List?) ?? const [];
    return list
        .map((p) => Place.fromPlacesApi(p as Map<String, dynamic>))
        .where((p) => p.isFood)
        .toList();
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String detail = res.body;
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      detail = ((j['error'] as Map<String, dynamic>?)?['message'] as String?) ??
          detail;
    } catch (_) {}
    throw PlacesException('Google Places 錯誤 (${res.statusCode})：$detail');
  }
}
