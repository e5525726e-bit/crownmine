import 'package:flutter/material.dart';

import '../di.dart';
import '../models/place.dart';

class PlaceThumbnail extends StatelessWidget {
  const PlaceThumbnail(this.place, {super.key, this.size = 56});

  final Place place;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.restaurant, color: scheme.onSurfaceVariant),
    );
    if (place.photos.isEmpty) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(8), child: placeholder);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        placesService.photoUrl(place.photos.first, maxWidth: 240),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
