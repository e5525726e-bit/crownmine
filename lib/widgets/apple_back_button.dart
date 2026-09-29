import 'package:flutter/cupertino.dart';

/// iOS 樣式的返回鍵（chevron + 文字）。沒有上一頁時不顯示。
class AppleBackButton extends StatelessWidget {
  const AppleBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(ModalRoute.of(context)?.canPop ?? false)) return const SizedBox.shrink();
    return const CupertinoNavigationBarBackButton();
  }
}
