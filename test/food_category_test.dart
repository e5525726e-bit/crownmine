import 'package:crownmine/models/food_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _matchTests();
  test('分類組合搜尋字串', () {
    expect(FoodCategory.all.queryFor(' 台中 '), '台中');
    expect(FoodCategory.hotpot.queryFor(''), '火鍋');
    expect(FoodCategory.hotpot.queryFor('台中'), '台中 火鍋');
    expect(FoodCategory.hotpot.queryFor('台中 火鍋'), '台中 火鍋');
  });

  test('分類的 Google 類型', () {
    expect(FoodCategory.all.searchType, isNull);
    expect(FoodCategory.hotpot.searchType, 'any');
    expect(FoodCategory.japanese.searchType, 'japanese_restaurant');
    for (final c in FoodCategory.values) {
      for (final t in c.types) {
        expect(RegExp(r'^[a-z_]+$').hasMatch(t), isTrue, reason: t);
      }
    }
  });
}

void _matchTests() {
  test('依類型或店名判斷種類', () {
    expect(FoodCategory.japanese.matches(types: ['ramen_restaurant', 'restaurant'], primaryType: 'ramen_restaurant', name: '一蘭'), isTrue);
    expect(FoodCategory.hotpot.matches(types: ['restaurant'], primaryType: 'restaurant', name: '這一鍋 麻辣鍋'), isTrue);
    expect(FoodCategory.hotpot.matches(types: ['restaurant'], primaryType: 'restaurant', name: '阿明牛肉麵'), isFalse);
    expect(FoodCategory.all.matches(types: const [], primaryType: null, name: 'x'), isTrue);
  });
}
