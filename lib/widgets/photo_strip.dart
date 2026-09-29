import 'package:flutter/material.dart';

import '../di.dart';
import '../models/place.dart';

/// 一排可橫向滑動的照片：使用者上傳的評價照片在前、Google 店家照片在後。
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    this.userPhotoUrls = const [],
    this.googlePhotos = const [],
    this.height = 150,
    this.loading = false,
  });

  final List<String> userPhotoUrls;
  final List<PlacePhoto> googlePhotos;
  final double height;

  /// 還在載入照片時顯示灰色占位。
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <Widget>[
      for (final url in userPhotoUrls) _tile(context, url, badge: '食客照片'),
      for (final p in googlePhotos.take(8))
        _tile(context, placesService.photoUrl(p, maxWidth: 600),
            badge: p.attributions.isNotEmpty ? '照片：${p.attributions.first}' : null),
    ];
    if (items.isEmpty) {
      if (!loading) return const SizedBox.shrink();
      return SizedBox(
        height: height,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: height * 1.3,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          ],
        ),
      );
    }
    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: items,
      ),
    );
  }

  Widget _tile(BuildContext context, String url, {String? badge}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: height * 1.3,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(color: scheme.surfaceContainerHighest),
                errorBuilder: (_, __, ___) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant),
                ),
              ),
              if (badge != null)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
