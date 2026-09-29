import 'package:flutter/material.dart';

/// iOS 設定頁那種「分組圓角列表」：白色圓角容器 + 細分隔線 + 可選的小標題。
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(indent: 16, color: theme.dividerColor));
      }
      items.add(children[i]);
    }
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                header!.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.4),
              ),
            ),
          Material(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(children: items),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(footer!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// 列表右側的 iOS 式小箭頭。
class Chevron extends StatelessWidget {
  const Chevron({super.key});

  @override
  Widget build(BuildContext context) => Icon(
        Icons.chevron_right,
        color: Theme.of(context)
            .colorScheme
            .onSurfaceVariant
            .withValues(alpha: 0.6),
      );
}
