/// 餐飲種類（像外送平台那樣的分類列）。
///
/// 每個分類有兩種找法：
/// - [types]：Google Places 的類型，附近搜尋用 includedTypes 精準過濾
/// - [keyword]：Google 沒有對應類型時（例如火鍋、小吃），改用關鍵字文字搜尋
enum FoodCategory {
  all('全部', '🍽️', '', []),
  hotpot('火鍋', '🍲', '火鍋', []),
  japanese('日式', '🍣', '日式料理',
      ['japanese_restaurant', 'sushi_restaurant', 'ramen_restaurant']),
  korean('韓式', '🥘', '韓式料理', ['korean_restaurant']),
  chinese('中式', '🥟', '中式餐廳', ['chinese_restaurant']),
  snack('小吃', '🍢', '小吃', []),
  noodle('麵食', '🍜', '麵店', []),
  brunch('早午餐', '🍳', '早午餐', ['breakfast_restaurant', 'brunch_restaurant']),
  cafe('咖啡廳', '☕', '咖啡廳', ['cafe', 'coffee_shop']),
  dessert('甜點', '🍰', '甜點', [
    'dessert_shop',
    'dessert_restaurant',
    'bakery',
    'ice_cream_shop',
    'donut_shop'
  ]),
  drink('飲料', '🧋', '手搖飲料', []),
  bbq('燒烤', '🍖', '燒肉 燒烤', ['barbecue_restaurant']),
  steak('牛排', '🥩', '牛排', ['steak_house']),
  italian('義式', '🍕', '義式料理', ['italian_restaurant', 'pizza_restaurant']),
  burger('漢堡', '🍔', '漢堡', [
    'hamburger_restaurant',
    'american_restaurant',
    'fast_food_restaurant'
  ]),
  thai('泰越', '🍛', '泰式料理', ['thai_restaurant', 'vietnamese_restaurant']),
  veg('素食', '🥗', '素食', ['vegetarian_restaurant', 'vegan_restaurant']),
  seafood('海鮮', '🦐', '海鮮', ['seafood_restaurant']),
  bar('酒吧', '🍺', '酒吧', ['bar', 'wine_bar', 'pub']),
  bento('便當', '🍱', '便當', []);

  const FoodCategory(this.label, this.emoji, this.keyword, this.types);

  final String label;
  final String emoji;
  final String keyword;
  final List<String> types;

  bool get isAll => this == all;

  /// 有 Google 類型可以精準過濾；否則只能用關鍵字。
  bool get hasTypes => types.isNotEmpty;

  /// 文字搜尋時要問 Google 的字串：使用者輸入 + 分類關鍵字。
  String queryFor(String userText) {
    final t = userText.trim();
    if (isAll || t.contains(keyword)) return t;
    return t.isEmpty ? keyword : '$t $keyword';
  }

  /// 文字搜尋的 includedType：有精準類型就用第一個；關鍵字分類則不限類型。
  String? get searchType => isAll ? null : (hasTypes ? types.first : 'any');
}
