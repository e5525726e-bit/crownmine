import 'package:flutter/material.dart';

import '../models/review.dart';
import '../models/verdict.dart';
import 'verdict_icon.dart';

/// 四種標記的數量。compact 版用在列表右側，完整版用在店家頁。
class VerdictSummary extends StatelessWidget {
  const VerdictSummary(this.stats, {super.key, this.compact = false});

  final PlaceStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in Verdict.values)
            if (stats.count(v) > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VerdictIcon(v, size: 18),
                    const SizedBox(width: 2),
                    Text('${stats.count(v)}',
                        style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
        ],
      );
    }

    final text = Theme.of(context).textTheme;
    // 六種標記：每列三個
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth / 3;
        return Wrap(
          runSpacing: 12,
          children: [
            for (final v in Verdict.values)
              SizedBox(
                width: w,
                child: Column(
                  children: [
                    VerdictIcon(v, size: 36),
                    const SizedBox(height: 4),
                    Text('${stats.count(v)}',
                        style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold, color: v.color)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(v.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
