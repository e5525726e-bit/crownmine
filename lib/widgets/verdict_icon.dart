import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/verdict.dart';

class VerdictIcon extends StatelessWidget {
  const VerdictIcon(this.verdict, {super.key, this.size = 24});

  final Verdict verdict;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        verdict.asset,
        width: size,
        height: size,
        semanticsLabel: verdict.label,
      );
}
