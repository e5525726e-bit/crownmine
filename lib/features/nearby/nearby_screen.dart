import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../di.dart';
import '../../models/place.dart';
import '../../widgets/async_body.dart';
import '../../widgets/google_attribution.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/inset_list_view.dart';
import '../../widgets/place_thumbnail.dart';
import '../place/place_detail_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  double _radius = 1000;
  Future<List<Place>>? _future;

  Future<List<Place>> _load() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('請先開啟手機的定位服務');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw Exception('需要定位權限才能找附近的餐廳，請到系統設定開啟');
    }
    final pos = await Geolocator.getCurrentPosition();
    return placesService.searchNearby(
      lat: pos.latitude,
      lng: pos.longitude,
      radiusMeters: _radius,
    );
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text('附近餐廳', style: theme.textTheme.displayLarge)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _refresh,
                    child: const Icon(CupertinoIcons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<double>(
                  groupValue: _radius,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  thumbColor: (theme.cardTheme.color ?? theme.colorScheme.surface),
                  children: {
                    for (final r in const [500.0, 1000.0, 2000.0])
                      r: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          r >= 1000 ? '${(r / 1000).toStringAsFixed(0)} 公里' : '${r.toInt()} 公尺',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                  },
                  onValueChanged: (r) {
                    if (r == null) return;
                    _radius = r;
                    _refresh();
                  },
                ),
              ),
            ),
            Expanded(
              child: AsyncBody<List<Place>>(
                future: _future,
                onRetry: _refresh,
                empty: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(CupertinoIcons.location_fill),
                      label: const Text('用目前位置找餐廳'),
                    ),
                  ),
                ),
                builder: (context, places) {
                  if (places.isEmpty) {
                    return const Center(child: Text('這個範圍內沒有餐飲店家'));
                  }
                  return InsetListView(
                    itemCount: places.length,
                    itemBuilder: (context, i) {
                      final p = places[i];
                      return ListTile(
                        leading: PlaceThumbnail(p),
                        title: Text(p.name),
                        subtitle: Text(
                          [
                            if (p.primaryTypeLabel != null) p.primaryTypeLabel!,
                            p.address,
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Chevron(),
                        onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                          builder: (_) => PlaceDetailScreen(placeId: p.id, initial: p),
                        )),
                      );
                    },
                  );
                },
              ),
            ),
            const GoogleAttribution(),
          ],
        ),
      ),
    );
  }
}
