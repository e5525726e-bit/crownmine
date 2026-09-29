import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../di.dart';
import '../../models/place.dart';
import '../../widgets/async_body.dart';
import '../../widgets/google_attribution.dart';
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
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('附近餐廳'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final r in const [500.0, 1000.0, 2000.0])
                  ChoiceChip(
                    label: Text(r >= 1000 ? '${(r / 1000).toStringAsFixed(0)} 公里' : '${r.toInt()} 公尺'),
                    selected: _radius == r,
                    onSelected: (_) {
                      _radius = r;
                      _refresh();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<List<Place>>(
              future: _future,
              onRetry: _refresh,
              empty: Center(
                child: FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.my_location),
                  label: const Text('用目前位置找餐廳'),
                ),
              ),
              builder: (context, places) {
                if (places.isEmpty) {
                  return const Center(child: Text('這個範圍內沒有餐飲店家'));
                }
                return ListView.separated(
                  itemCount: places.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
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
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            PlaceDetailScreen(placeId: p.id, initial: p),
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
    );
  }
}
