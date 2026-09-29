import 'package:flutter/material.dart';

/// App 內唯一的評價方式：不是星等，只有六種標記。
/// 皇冠、網美店、綠燈（紅綠燈亮綠燈）、地雷、IG 推薦但不推、大便。
/// 順序即畫面顯示順序（由好到壞）。
enum Verdict {
  crown('crown', '真心推薦', '值得專程來吃', 'assets/icons/crown.svg',
      Color(0xFFB07E00)),
  camera('camera', '網美店', '拍照好看，重點不在吃', 'assets/icons/camera.svg',
      Color(0xFFC2185B)),
  green('green', '普通中規中矩', '不好不壞，價格合理',
      'assets/icons/green_light.svg', Color(0xFF2E7D32)),
  mine('mine', '普通又貴', '味道一般，價格偏高', 'assets/icons/landmine.svg',
      Color(0xFF212121)),
  igtrap('igtrap', 'IG 推薦但不推', '網路很紅，實際普通', 'assets/icons/igtrap.svg',
      Color(0xFFC62828)),
  poop('poop', '難吃／態度環境很差', '不推薦再來', 'assets/icons/poop.svg',
      Color(0xFF6D4C41));

  const Verdict(
      this.dbValue, this.label, this.hint, this.asset, this.color);

  /// 存進 Supabase 的值（對應 SQL 的 enum `verdict`）。
  final String dbValue;
  final String label;
  final String hint;
  final String asset;
  final Color color;

  /// 皇冠、網美店、綠燈算正面或中性；地雷、IG 推薦但不推、大便算負面。
  bool get isNegative => this == mine || this == igtrap || this == poop;

  static Verdict fromDb(String value) =>
      values.firstWhere((v) => v.dbValue == value);
}
