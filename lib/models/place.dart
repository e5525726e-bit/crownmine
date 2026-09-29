/// Places API (New) 的「餐飲」類型白名單（Table A: Food and Drink）。
/// 任何以 `_restaurant` 結尾的類型也視為餐飲。
const Set<String> kFoodTypes = {
  'restaurant',
  'cafe',
  'coffee_shop',
  'bakery',
  'bar',
  'pub',
  'wine_bar',
  'meal_takeaway',
  'meal_delivery',
  'food_court',
  'ice_cream_shop',
  'dessert_shop',
  'tea_house',
  'juice_shop',
  'sandwich_shop',
  'steak_house',
  'diner',
  'noodle_shop',
  'food',
  'bar_and_grill',
  'cafeteria',
  'food_store',
  'confectionery',
  'donut_shop',
  'bagel_shop',
  'acai_shop',
  'chocolate_shop',
  'candy_store',
  'snack_bar',
  'bistro',
  'tea_store',
  'dessert_restaurant',
};

bool isFoodPlace(List<String> types, String? primaryType) {
  bool ok(String t) => kFoodTypes.contains(t) || t.endsWith('_restaurant');
  if (primaryType != null && ok(primaryType)) return true;
  return types.any(ok);
}

class PlacePhoto {
  const PlacePhoto({required this.name, this.attributions = const []});

  /// 形如 `places/{placeId}/photos/{photoRef}`。
  final String name;
  final List<String> attributions;

  factory PlacePhoto.fromJson(Map<String, dynamic> j) => PlacePhoto(
        name: j['name'] as String,
        attributions: ((j['authorAttributions'] as List?) ?? const [])
            .map((a) => (a as Map<String, dynamic>)['displayName'] as String?)
            .whereType<String>()
            .toList(),
      );
}

/// 店家基本資料。刻意不包含 Google 的評分、評論數、評論內容。
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.primaryType,
    this.primaryTypeLabel,
    this.types = const [],
    this.googleMapsUri,
    this.businessStatus,
    this.priceLevel,
    this.photos = const [],
    this.weekdayDescriptions = const [],
    this.phone,
    this.website,
  });

  final String id;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final String? primaryType;
  final String? primaryTypeLabel;
  final List<String> types;
  final String? googleMapsUri;
  final String? businessStatus;
  final String? priceLevel;
  final List<PlacePhoto> photos;
  final List<String> weekdayDescriptions;
  final String? phone;
  final String? website;

  bool get isFood => isFoodPlace(types, primaryType);
  bool get isClosedPermanently => businessStatus == 'CLOSED_PERMANENTLY';

  /// 把 Google 的價位等級轉成 `$` 記號，null 表示 Google 沒提供。
  String? get priceLabel => switch (priceLevel) {
        'PRICE_LEVEL_FREE' => '免費',
        'PRICE_LEVEL_INEXPENSIVE' => r'$',
        'PRICE_LEVEL_MODERATE' => r'$$',
        'PRICE_LEVEL_EXPENSIVE' => r'$$$',
        'PRICE_LEVEL_VERY_EXPENSIVE' => r'$$$$',
        _ => null,
      };

  factory Place.fromPlacesApi(Map<String, dynamic> j) {
    final location = j['location'] as Map<String, dynamic>?;
    return Place(
      id: j['id'] as String,
      name: _text(j['displayName']) ?? '(未命名店家)',
      address: (j['formattedAddress'] as String?) ?? '',
      lat: (location?['latitude'] as num?)?.toDouble(),
      lng: (location?['longitude'] as num?)?.toDouble(),
      primaryType: j['primaryType'] as String?,
      primaryTypeLabel: _text(j['primaryTypeDisplayName']),
      types: ((j['types'] as List?) ?? const []).cast<String>(),
      googleMapsUri: j['googleMapsUri'] as String?,
      businessStatus: j['businessStatus'] as String?,
      priceLevel: j['priceLevel'] as String?,
      photos: ((j['photos'] as List?) ?? const [])
          .map((p) => PlacePhoto.fromJson(p as Map<String, dynamic>))
          .toList(),
      weekdayDescriptions: (((j['regularOpeningHours']
                  as Map<String, dynamic>?)?['weekdayDescriptions'] as List?) ??
              const [])
          .cast<String>(),
      phone: j['nationalPhoneNumber'] as String?,
      website: j['websiteUri'] as String?,
    );
  }

  /// 從 App 自己的快取（Supabase `places` 表）還原。
  factory Place.fromCacheRow(Map<String, dynamic> r) => Place(
        id: r['place_id'] as String,
        name: r['name'] as String,
        address: (r['address'] as String?) ?? '',
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
        primaryType: r['primary_type'] as String?,
        types: ((r['types'] as List?) ?? const []).cast<String>(),
        googleMapsUri: r['google_maps_uri'] as String?,
      );

  static String? _text(Object? localized) =>
      (localized as Map<String, dynamic>?)?['text'] as String?;
}
