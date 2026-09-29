import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/review.dart';
import '../../utils/format.dart';
import '../../widgets/verdict_icon.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.isMine,
    this.onReport,
    this.onBlock,
    this.onEdit,
    this.onDelete,
  });

  final Review review;
  final bool isMine;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  void _showActions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: isMine
            ? [
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onEdit?.call();
                  },
                  child: const Text('修改'),
                ),
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                  child: const Text('刪除'),
                ),
              ]
            : [
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onReport?.call();
                  },
                  child: const Text('檢舉這則評價'),
                ),
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    onBlock?.call();
                  },
                  child: const Text('封鎖此使用者'),
                ),
              ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = review;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VerdictIcon(r.verdict, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.verdict.label,
                          style: text.titleMedium?.copyWith(color: r.verdict.color)),
                      Text(
                        '${r.authorName} · ${fmtRelative(r.createdAt)}'
                        '${isMine ? '（我）' : ''}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => _showActions(context),
                  child: Icon(CupertinoIcons.ellipsis, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(r.body, style: text.bodyLarge),
            ),
            if (r.pricePaid != null || r.visitedOn != null || r.hasReceipt)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (r.pricePaid != null) _Tag(CupertinoIcons.money_dollar_circle, '每人約 \$${r.pricePaid}'),
                    if (r.visitedOn != null) _Tag(CupertinoIcons.calendar, '${fmtDate(r.visitedOn!)} 造訪'),
                    if (r.hasReceipt) _Tag(CupertinoIcons.checkmark_seal_fill, '附消費證明', accent: true),
                  ],
                ),
              ),
            if (r.photoUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: r.photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(r.photoUrls[i], width: 96, height: 96, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label, {this.accent = false});
  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}
