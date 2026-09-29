import 'package:crownmine/models/place.dart';
import 'package:crownmine/models/review.dart';
import 'package:crownmine/models/verdict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _dominantTests();
  group('isFoodPlace', () {
    test('接受餐飲類型與 *_restaurant', () {
      expect(isFoodPlace(['restaurant', 'food'], 'restaurant'), isTrue);
      expect(isFoodPlace(['cafe'], 'cafe'), isTrue);
      expect(isFoodPlace(['ramen_restaurant'], 'ramen_restaurant'), isTrue);
    });

    test('拒絕非餐飲店家', () {
      expect(isFoodPlace(['convenience_store', 'store'], 'convenience_store'), isFalse);
      expect(isFoodPlace(['hair_salon'], null), isFalse);
    });
  });

  test('Place.fromPlacesApi 不會讀取任何 Google 評價欄位', () {
    final place = Place.fromPlacesApi({
      'id': 'abc',
      'displayName': {'text': '測試餐廳', 'languageCode': 'zh-TW'},
      'formattedAddress': '台北市中正區',
      'location': {'latitude': 25.03, 'longitude': 121.56},
      'types': ['restaurant'],
      'primaryType': 'restaurant',
      'priceLevel': 'PRICE_LEVEL_MODERATE',
      // 就算 Google 回了這些欄位（實際上 FieldMask 不會要求），也會被忽略
      'rating': 4.7,
      'userRatingCount': 999,
      'reviews': [{'text': {'text': '不該出現'}}],
    });
    expect(place.name, '測試餐廳');
    expect(place.priceLabel, r'$$');
    expect(place.isFood, isTrue);
    expect(place.toString().contains('不該出現'), isFalse);
  });

  test('Verdict 對應資料庫值', () {
    for (final v in Verdict.values) {
      expect(Verdict.fromDb(v.dbValue), v);
    }
    expect(Verdict.mine.isNegative, isTrue);
    expect(Verdict.igtrap.isNegative, isTrue);
    expect(Verdict.camera.isNegative, isFalse);
    expect(Verdict.poop.isNegative, isTrue);
    expect(Verdict.crown.isNegative, isFalse);
    expect(Verdict.green.isNegative, isFalse);
  });

  test('PlaceStats 六種計數', () {
    final s = PlaceStats.fromRow({'crowns': 3, 'greens': 2, 'mines': 1, 'poops': 0, 'cameras': 4, 'igtraps': 1});
    expect(s.total, 11);
    expect(s.count(Verdict.camera), 4);
    expect(s.count(Verdict.igtrap), 1);
    expect(s.count(Verdict.crown), 3);
    expect(s.count(Verdict.green), 2);
    expect(s.count(Verdict.mine), 1);
    expect(s.count(Verdict.poop), 0);
  });
}

void _dominantTests() {
  test('PlaceStats.dominant 取最多的標記，平手時皇冠優先', () {
    expect(const PlaceStats().dominant, isNull);
    expect(const PlaceStats(crowns: 1, poops: 4).dominant, Verdict.poop);
    expect(const PlaceStats(crowns: 2, mines: 2).dominant, Verdict.crown);
    expect(const PlaceStats(cameras: 5, crowns: 1).dominant, Verdict.camera);
    expect(const PlaceStats(greens: 3, mines: 1).dominant, Verdict.green);
  });
}
