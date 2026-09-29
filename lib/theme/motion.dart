import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Apple 的彈簧參數：用「阻尼比」和「回應時間」思考，不用固定秒數。
/// - 阻尼比 1.0：不過衝，適合一般 UI
/// - 阻尼比 0.8：帶一點彈性，只用在有慣性的手勢（甩、拖放）
class AppSprings {
  AppSprings._();

  static SpringDescription _spring(
      {required double damping, required double response}) {
    const mass = 1.0;
    final stiffness = math.pow(2 * math.pi / response, 2) * mass;
    return SpringDescription.withDampingRatio(
        mass: mass, stiffness: stiffness.toDouble(), ratio: damping);
  }

  /// 預設：臨界阻尼、0.35 秒回應。
  static final SpringDescription standard =
      _spring(damping: 1.0, response: 0.35);

  /// 有慣性的互動用：略帶回彈。
  static final SpringDescription bouncy = _spring(damping: 0.8, response: 0.35);

  /// 按壓回饋用：更快。
  static final SpringDescription press = _spring(damping: 1.0, response: 0.18);
}

/// 使用者是否開啟「減少動態效果」。
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);
