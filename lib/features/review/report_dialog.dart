import 'package:flutter/cupertino.dart';

import '../../widgets/apple_dialogs.dart';

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

/// 先用 iOS 動作選單選原因，再用對話框補充說明（選填）。
Future<ReportResult?> showReportSheet(BuildContext context) async {
  final reason = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('檢舉這則評價'),
      message: const Text('請選擇原因，我們會在 24 小時內審核'),
      actions: [
        for (final e in _reasons.entries)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, e.key),
            child: Text(e.value),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: const Text('取消'),
      ),
    ),
  );
  if (reason == null || !context.mounted) return null;

  final detail = await showTextPrompt(
    context,
    title: '補充說明',
    message: '選填，最多 500 字',
    placeholder: '例如：這則評價提到的餐點店裡沒有賣',
    maxLength: 500,
    confirmLabel: '送出檢舉',
  );
  if (detail == null) return null;
  return ReportResult(reason, detail.isEmpty ? null : detail);
}
