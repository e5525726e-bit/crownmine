import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/verdict.dart';

/// 附加標籤的圖示。IG 的圖案會依核心判斷決定要不要加禁止斜線。
class TagIcon extends StatelessWidget {
  const TagIcon(this.tag, {super.key, this.verdict, this.size = 20});

  final ReviewTag tag;
  final Verdict? verdict;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        tag.assetFor(verdict),
        width: size,
        height: size,
        semanticsLabel: tag.label,
      );
}
