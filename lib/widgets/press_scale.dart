import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// 按下去的那一刻就縮小、放開用彈簧回來；動畫可在任何時刻被打斷並從當下值接續。
/// 開啟「減少動態」時改用透明度變化，不縮放。
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  /// 點擊成功時是否給一個輕微的觸覺回饋（只用在「選擇」這類有意義的動作）。
  final bool haptic;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 1);

  void _animateTo(double target) {
    // 從目前的呈現值與速度出發，不是從邏輯目標值
    _c.animateWith(SpringSimulation(AppSprings.press, _c.value, target, _c.velocity));
  }

  void _down(TapDownDetails _) => _animateTo(widget.scale);
  void _up() => _animateTo(1);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : _down,
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // 減少動態：用透明度取代縮放
          if (reduce) {
            final t = ((1 - _c.value) / (1 - widget.scale)).clamp(0.0, 1.0);
            return Opacity(opacity: 1 - 0.35 * t, child: child);
          }
          return Transform.scale(scale: _c.value.clamp(0.9, 1.05), child: child);
        },
        child: widget.child,
      ),
    );
  }
}
