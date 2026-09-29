import 'package:flutter/material.dart';

/// App 內唯一的評價方式：不是星等，只有五種核心判斷。
/// 皇冠、便宜又大碗、老子有錢不差錢、綠燈（紅綠燈亮綠燈）、地雷。順序即畫面顯示順序（由好到壞）。
/// 「超好吃／必吃」「IG 網紅店」「網美店」「適合約會」「難吃／態度環境很差」是附加標籤，見 [ReviewTag]。
enum Verdict {
  crown('crown', '真心推薦', '值得專程來吃', 'assets/icons/crown.svg', Color(0xFFB07E00)),
  rice('rice', '便宜又大碗', '吃得飽又划算，好不好吃看標籤', 'assets/icons/rice.svg',
      Color(0xFF1E88E5)),
  rich('rich', '老子有錢不差錢', '貴，但有錢就是任性', 'assets/icons/money_face.svg',
      Color(0xFFC79A00)),
  green('green', '普通中規中矩', '不好不壞，價格合理', 'assets/icons/green_light.svg',
      Color(0xFF2E7D32)),
  mine('mine', '普通又貴', '味道一般，價格偏高', 'assets/icons/landmine.svg',
      Color(0xFF212121));

  const Verdict(this.dbValue, this.label, this.hint, this.asset, this.color);

  /// 存進 Supabase 的值（對應 SQL 的 enum `verdict`）。
  final String dbValue;
  final String label;
  final String hint;
  final String asset;
  final Color color;

  /// 皇冠、大碗、有錢、綠燈算正面或中性，地雷算負面。
  bool get isNegative => this == mine;

  static Verdict fromDb(String value) =>
      values.firstWhere((v) => v.dbValue == value);
}

/// 附加標籤：描述店的屬性，可以疊在任何核心判斷上。
enum ReviewTag {
  fire('fire', '超好吃／必吃', '來這區一定要吃這家'),
  ig('ig', 'IG 網紅店', '社群上很紅的店'),
  photogenic('photogenic', '網美店', '拍照好看，重點不在吃'),
  date('date', '適合約會', '氣氛好，帶另一半來剛好'),
  poop('poop', '難吃／態度環境很差', '不推薦再來');

  const ReviewTag(this.dbValue, this.label, this.hint);

  final String dbValue;
  final String label;
  final String hint;

  String get asset => switch (this) {
        ReviewTag.fire => 'assets/icons/fire.svg',
        ReviewTag.ig => 'assets/icons/ig.svg',
        ReviewTag.photogenic => 'assets/icons/camera.svg',
        ReviewTag.date => 'assets/icons/cheers.svg',
        ReviewTag.poop => 'assets/icons/poop.svg',
      };

  Color get color => switch (this) {
        ReviewTag.fire => const Color(0xFFE65100),
        ReviewTag.ig => const Color(0xFF7B1FA2),
        ReviewTag.photogenic => const Color(0xFFC2185B),
        ReviewTag.date => const Color(0xFF8E1B3D),
        ReviewTag.poop => const Color(0xFF6D4C41),
      };

  static ReviewTag? fromDb(String value) {
    for (final t in values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  static List<ReviewTag> listFromDb(Object? raw) => ((raw as List?) ?? const [])
      .map((e) => fromDb(e as String))
      .whereType<ReviewTag>()
      .toList();
}
