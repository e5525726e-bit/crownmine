import 'package:flutter/material.dart';

import '../di.dart';
import '../models/place.dart';

/// 一張店面照片（16:9、圓角），有 Google 照片就用第一張。
class StorefrontPhoto extends StatelessWidget {
  const StorefrontPhoto({
    super.key,
    this.photo,
    this.loading = false,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final PlacePhoto? photo;

  /// 還在查照片時顯示灰色占位。
  final bool loading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = photo;
    if (p == null && !loading) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: p == null
              ? Container(color: scheme.surfaceContainerHighest)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      placesService.photoUrl(p, maxWidth: 1200),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(color: scheme.surfaceContainerHighest),
                      errorBuilder: (_, __, ___) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(Icons.storefront_outlined,
                            color: scheme.onSurfaceVariant),
                      ),
                    ),
                    if (p.attributions.isNotEmpty)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '照片：${p.attributions.join('、')}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
