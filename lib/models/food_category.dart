/// 餐飲種類（像外送平台那樣的分類列）。
///
/// 每個分類有兩種找法：
/// - [types]：Google Places 的類型，附近搜尋用 includedTypes 精準過濾
/// - [keyword]：Google 沒有對應類型時（例如火鍋、小吃），改用關鍵字文字搜尋
enum FoodCategory {
  all('全部', '🍽️', '', []),
  hotpot('火鍋', '🍲', '火鍋', ['hot_pot_restaurant']),
  japanese('日式', '🍣', '日式料理',
      ['japanese_restaurant', 'sushi_restaurant', 'ramen_restaurant']),
  korean('韓式', '🥘', '韓式料理', ['korean_restaurant']),
  taiwanese('台式', '🇹🇼', '台式餐廳', ['taiwanese_restaurant']),
  chinese('中式', '🥟', '中式餐廳', ['chinese_restaurant', 'dumpling_restaurant']),
  snack('小吃', '🍢', '小吃', ['snack_bar']),
  noodle('麵食', '🍜', '麵店',
      ['noodle_shop', 'chinese_noodle_restaurant', 'ramen_restaurant']),
  brunch('早午餐', '🍳', '早午餐', ['breakfast_restaurant', 'brunch_restaurant']),
  cafe('咖啡廳', '☕', '咖啡廳', ['cafe', 'coffee_shop']),
  dessert('甜點', '🍰', '甜點', [
    'dessert_shop',
    'dessert_restaurant',
    'bakery',
    'ice_cream_shop',
    'donut_shop'
  ]),
  drink('飲料', '🧋', '手搖飲料', ['tea_store', 'tea_house', 'juice_shop']),
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

  /// 店名裡出現這些字也算這個種類（給沒有 Google 類型的分類，以及已存的店用）。
  List<String> get nameHints => switch (this) {
        FoodCategory.all => const [],
        FoodCategory.hotpot => const ['火鍋', '鍋物', '涮', '麻辣鍋', '石頭鍋'],
        FoodCategory.japanese => const ['日式', '日本', '壽司', '拉麵', '丼', '居酒屋', '定食', '燒鳥'],
        FoodCategory.korean => const ['韓式', '韓國', '韓'],
        FoodCategory.taiwanese => const [
            '台式', '臺式', '台菜', '臺菜', '台灣料理', '熱炒', '快炒', '滷肉飯', '魯肉飯',
            '牛肉麵', '麵線', '蚵仔', '豬腳', '雞肉飯', '肉圓', '碗粿', '米糕', '排骨飯',
            '鵝肉', '羊肉爐', '薑母鴨', '土雞城', '客家', '辦桌', '海產店', '小吃部'
          ],
        FoodCategory.chinese => const ['中式', '餐館', '熱炒', '合菜', '川菜', '粵菜', '港式', '小籠包'],
        FoodCategory.snack => const ['小吃', '滷肉飯', '雞排', '鹽酥雞', '蚵仔', '肉圓', '碗粿', '滷味'],
        FoodCategory.noodle => const ['麵', '麵線', '米粉', '粄條'],
        FoodCategory.brunch => const ['早午餐', '早餐', 'Brunch', 'brunch'],
        FoodCategory.cafe => const ['咖啡', 'Cafe', 'Café', 'cafe', 'Coffee', 'coffee'],
        FoodCategory.dessert => const ['甜點', '蛋糕', '冰', '烘焙', '麵包', '甜品', '豆花', '布丁', '鬆餅'],
        FoodCategory.drink => const ['手搖', '茶', '飲', '果汁', 'Tea', 'tea'],
        FoodCategory.bbq => const ['燒肉', '燒烤', '烤肉', '串燒', '碳烤'],
        FoodCategory.steak => const ['牛排', 'Steak', 'steak'],
        FoodCategory.italian => const ['義式', '義大利', '披薩', 'Pizza', 'pizza', 'Pasta', 'pasta'],
        FoodCategory.burger => const ['漢堡', '速食', 'Burger', 'burger', '麥當勞', '肯德基'],
        FoodCategory.thai => const ['泰式', '泰國', '越南', '越式', '河粉', '打拋'],
        FoodCategory.veg => const ['素食', '蔬食', '素'],
        FoodCategory.seafood => const ['海鮮', '海產', '生蠔', '蝦', '魚'],
        FoodCategory.bar => const ['酒吧', 'Bar', 'bar', '啤酒', '居酒屋'],
        FoodCategory.bento => const ['便當', '餐盒', '自助餐'],
      };

  /// 已知類型與店名的店是否屬於這個種類（用來篩選已有評價的店）。
  bool matches({
    required List<String> types,
    String? primaryType,
    required String name,
  }) {
    if (isAll) return true;
    if (primaryType != null && this.types.contains(primaryType)) return true;
    if (types.any(this.types.contains)) return true;
    return nameHints.any(name.contains);
  }

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
