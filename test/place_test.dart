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

  test('標籤對應資料庫值', () {
    expect(ReviewTag.listFromDb(['ig', 'x', 'photogenic', 'rich', 'date', 'poop']),
        [ReviewTag.ig, ReviewTag.photogenic, ReviewTag.date, ReviewTag.poop]);
    expect(ReviewTag.ig.asset, 'assets/icons/ig.svg');
  });

  test('Verdict 對應資料庫值', () {
    for (final v in Verdict.values) {
      expect(Verdict.fromDb(v.dbValue), v);
    }
    expect(Verdict.mine.isNegative, isTrue);
    expect(Verdict.crown.isNegative, isFalse);
    expect(Verdict.green.isNegative, isFalse);
    expect(Verdict.rich.isNegative, isFalse);
    expect(Verdict.values.length, 4);
  });

  test('PlaceStats 四種計數與標籤', () {
    final s = PlaceStats.fromRow({'crowns': 3, 'greens': 2, 'mines': 1, 'poops': 5, 'igs': 4, 'photogenics': 1, 'richs': 2, 'dates': 0, 'fires': 6});
    expect(s.total, 8);
    expect(s.tagCount(ReviewTag.ig), 4);
    expect(s.isTagged(ReviewTag.ig), isTrue);
    expect(s.isTagged(ReviewTag.photogenic), isFalse);
    expect(s.isTagged(ReviewTag.date), isFalse);
    expect(s.hasTags, isTrue);
    expect(s.count(Verdict.crown), 3);
    expect(s.count(Verdict.rich), 2);
    expect(s.count(Verdict.green), 2);
    expect(s.count(Verdict.mine), 1);
    expect(s.tagCount(ReviewTag.poop), 5);
    expect(s.tagCount(ReviewTag.fire), 6);
    expect(s.isTagged(ReviewTag.poop), isTrue);
  });
}

void _dominantTests() {
  test('PlaceStats.dominant 取最多的標記，平手時皇冠優先', () {
    expect(const PlaceStats().dominant, isNull);
    expect(const PlaceStats(crowns: 1, mines: 4).dominant, Verdict.mine);
    expect(const PlaceStats(richs: 3, greens: 1).dominant, Verdict.rich);
    expect(const PlaceStats(crowns: 2, mines: 2).dominant, Verdict.crown);
    expect(const PlaceStats(greens: 3, mines: 1).dominant, Verdict.green);
  });
}
