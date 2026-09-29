import 'package:flutter/cupertino.dart';

/// iOS 樣式的確認對話框。回傳 true 表示按下確認。
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '確定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6), child: Text(message)),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// iOS 樣式的單行文字輸入對話框。取消回傳 null。
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String initial = '',
  String placeholder = '',
  int? maxLength,
  String confirmLabel = '儲存',
}) {
  final controller = TextEditingController(text: initial);
  return showCupertinoDialog<String>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null)
            Padding(
                padding: const EdgeInsets.only(top: 6), child: Text(message)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            maxLength: maxLength,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
