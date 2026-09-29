import 'package:flutter/material.dart';

class ReportResult {
  const ReportResult(this.reason, this.detail);
  final String reason;
  final String? detail;
}

const _reasons = {
  'fake': '不實或惡意評價',
  'spam': '廣告、垃圾訊息',
  'harassment': '騷擾、人身攻擊、仇恨言論',
  'privacy': '洩漏個資（照片、電話、姓名等）',
  'other': '其他',
};

Future<ReportResult?> showReportDialog(BuildContext context) {
  String reason = 'fake';
  final detail = TextEditingController();
  return showDialog<ReportResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('檢舉這則評價'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => setState(() => reason = v!),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in _reasons.entries)
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.value),
                        value: e.key,
                      ),
                  ],
                ),
              ),
              TextField(
                controller: detail,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '補充說明（選填）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              ReportResult(
                reason,
                detail.text.trim().isEmpty ? null : detail.text.trim(),
              ),
            ),
            child: const Text('送出檢舉'),
          ),
        ],
      ),
    ),
  );
}
