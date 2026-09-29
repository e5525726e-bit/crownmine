import 'package:flutter/material.dart';

import '../utils/format.dart';

/// FutureBuilder 的常見三態（載入中／錯誤／完成）統一處理。
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
    this.empty,
  });

  final Future<T>? future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback? onRetry;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (future == null) return empty ?? const SizedBox.shrink();
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 8),
                  Text(friendlyError(snap.error!), textAlign: TextAlign.center),
                  if (onRetry != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: onRetry, child: const Text('重試')),
                  ],
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return builder(context, snap.data as T);
      },
    );
  }
}
