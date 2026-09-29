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
    return Row(
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
    );
  }
}
