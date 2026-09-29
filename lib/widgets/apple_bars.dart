import 'dart:ui';

import 'package:flutter/material.dart';

import 'apple_back_button.dart';

const double kBarBlur = 20;

/// 半透明毛玻璃導覽列：內容從底下滑過，用 hairline 分隔而非陰影。
/// 搭配 Scaffold 的 `extendBodyBehindAppBar: true` 使用。
class AppleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppleAppBar(
      {super.key, this.title, this.leading, this.actions, this.leadingWidth});

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final double? leadingWidth;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = (theme.cardTheme.color ?? theme.colorScheme.surface);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: kBarBlur, sigmaY: kBarBlur),
        child: AppBar(
          title: title,
          leading: leading ?? const AppleBackButton(),
          leadingWidth: leadingWidth,
          actions: actions,
          backgroundColor: bg.withValues(alpha: 0.75),
          shape:
              Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
        ),
      ),
    );
  }
}

/// 畫面底部的半透明材質列（例如主要動作按鈕）。搭配 `extendBody: true`。
class AppleBottomBar extends StatelessWidget {
  const AppleBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = (theme.cardTheme.color ?? theme.colorScheme.surface);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: kBarBlur, sigmaY: kBarBlur),
        child: Container(
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.75),
            border:
                Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 在 `extendBodyBehindAppBar` / `extendBody` 的畫面裡，捲動內容應使用的內距。
EdgeInsets barInsets(BuildContext context,
    {double top = 8, double bottom = 16}) {
  final p = MediaQuery.paddingOf(context);
  return EdgeInsets.only(top: p.top + top, bottom: p.bottom + bottom);
}
