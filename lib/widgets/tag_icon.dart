import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/verdict.dart';

/// 附加標籤的圖示。
class TagIcon extends StatelessWidget {
  const TagIcon(this.tag, {super.key, this.size = 20});

  final ReviewTag tag;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        tag.asset,
        width: size,
        height: size,
        semanticsLabel: tag.label,
      );
}
