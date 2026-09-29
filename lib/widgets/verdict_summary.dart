import 'package:flutter/material.dart';

import '../models/review.dart';
import '../models/verdict.dart';
import 'tag_icon.dart';
import 'verdict_icon.dart';

/// 五種核心判斷的數量，加上附加標籤被標的次數。
/// compact 版用在列表右側，完整版用在店家頁。
class VerdictSummary extends StatelessWidget {
  const VerdictSummary(this.stats, {super.key, this.compact = false});

  final PlaceStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
                    Text('${stats.count(v)}', style: text.labelLarge),
                  ],
                ),
              ),
          for (final t in ReviewTag.values)
            if (stats.isTagged(t))
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TagIcon(t, size: 18),
              ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final v in Verdict.values)
              Expanded(
                child: Column(
                  children: [
                    VerdictIcon(v, size: 40),
                    const SizedBox(height: 4),
                    Text('${stats.count(v)}',
                        style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold, color: v.color)),
                    Text(v.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall),
                  ],
                ),
              ),
          ],
        ),
        if (stats.hasTags) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final t in ReviewTag.values)
                if (stats.tagCount(t) > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TagIcon(t, size: 22),
                      const SizedBox(width: 6),
                      Text('${stats.tagCount(t)} 人標記為${t.label}',
                          style: text.bodySmall),
                    ],
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
