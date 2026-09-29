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

  @override
  Widget build(BuildContext context) {
    final r = review;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VerdictIcon(r.verdict, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.verdict.label,
                          style: text.titleSmall?.copyWith(
                              color: r.verdict.color,
                              fontWeight: FontWeight.bold)),
                      Text(
                        '${r.authorName} · ${fmtRelative(r.createdAt)}'
                        '${isMine ? '（我）' : ''}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => switch (v) {
                    'edit' => onEdit?.call(),
                    'delete' => onDelete?.call(),
                    'report' => onReport?.call(),
                    'block' => onBlock?.call(),
                    _ => null,
                  },
                  itemBuilder: (_) => isMine
                      ? const [
                          PopupMenuItem(value: 'edit', child: Text('修改')),
                          PopupMenuItem(value: 'delete', child: Text('刪除')),
                        ]
                      : const [
                          PopupMenuItem(value: 'report', child: Text('檢舉這則評價')),
                          PopupMenuItem(value: 'block', child: Text('封鎖此使用者')),
                        ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(r.body, style: text.bodyMedium),
            ),
            if (r.pricePaid != null || r.visitedOn != null || r.hasReceipt)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: -8,
                  children: [
                    if (r.pricePaid != null)
                      Chip(
                        avatar: const Icon(Icons.payments_outlined, size: 16),
                        label: Text('每人約 \$${r.pricePaid}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (r.visitedOn != null)
                      Chip(
                        avatar: const Icon(Icons.event, size: 16),
                        label: Text('${fmtDate(r.visitedOn!)} 造訪'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (r.hasReceipt)
                      Chip(
                        avatar: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('附消費證明'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            if (r.photoUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: r.photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(r.photoUrls[i],
                          width: 96, height: 96, fit: BoxFit.cover),
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
