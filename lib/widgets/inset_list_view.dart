import 'package:flutter/material.dart';

/// 可延遲建構（lazy）的分組圓角列表，用在搜尋結果這類長清單。
class InsetListView extends StatelessWidget {
  const InsetListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    this.padding,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? header;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView.separated(
      padding: padding ?? EdgeInsets.fromLTRB(16, 8, 16, 24 + bottom),
      itemCount: itemCount + (header == null ? 0 : 1),
      separatorBuilder: (_, i) {
        if (header != null && i == 0) return const SizedBox.shrink();
        return Container(
          color: theme.cardTheme.color,
          child: Divider(indent: 16, color: theme.dividerColor),
        );
      },
      itemBuilder: (context, i) {
        if (header != null) {
          if (i == 0) return header!;
          i -= 1;
        }
        final first = i == 0;
        final last = i == itemCount - 1;
        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: first ? const Radius.circular(12) : Radius.zero,
            bottom: last ? const Radius.circular(12) : Radius.zero,
          ),
          child: Material(
              color: theme.cardTheme.color, child: itemBuilder(context, i)),
        );
      },
    );
  }
}
