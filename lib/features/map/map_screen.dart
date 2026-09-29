import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../di.dart';
import '../../models/review.dart';
import '../../models/verdict.dart';
import '../../utils/format.dart';
import '../../widgets/apple_bars.dart';
import '../../widgets/verdict_icon.dart';
import '../../widgets/verdict_summary.dart';
import '../place/place_detail_screen.dart';
import 'verdict_marker.dart';

/// 地圖分頁：把有評價的店家用四種標記顯示在 Google 地圖上。
/// 只顯示這個 App 有評價的店，標記取最多人給的那一種。
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _taipei = CameraPosition(target: LatLng(25.0418, 121.5436), zoom: 13);

  GoogleMapController? _controller;
  bool _iconsReady = false;
  Set<Marker> _markers = const {};
  Timer? _debounce;
  bool _loading = false;
  bool _myLocation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    await VerdictMarkerIcons.preload(dpr);
    _iconsReady = true;
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
      _myLocation = true;
      try {
        final pos = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition();
        await _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
        );
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _locateMe() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要定位權限才能移到目前位置')),
      );
      return;
    }
    setState(() => _myLocation = true);
    final pos = await Geolocator.getCurrentPosition();
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
    );
  }

  void _onCameraIdle() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null || !_iconsReady) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await controller.getVisibleRegion();
      final places = await reviewRepo.placesInBounds(
        minLat: b.southwest.latitude,
        minLng: b.southwest.longitude,
        maxLat: b.northeast.latitude,
        maxLng: b.northeast.longitude,
      );
      // 評價越多：圖示越大、浮在其他標記上面（zIndex）、顯示評價數
      final markers = <Marker>{};
      for (final p in places) {
        final dominant = p.stats.dominant;
        if (dominant == null) continue;
        markers.add(Marker(
          markerId: MarkerId(p.placeId),
          position: LatLng(p.lat!, p.lng!),
          icon: await VerdictMarkerIcons.icon(dominant, p.stats.total),
          anchor: VerdictMarkerIcons.anchor,
          zIndexInt: p.stats.total,
          onTap: () => _showPlace(p),
        ));
      }
      if (!mounted) return;
      setState(() {
        _markers = markers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  void _showPlace(ReviewedPlace p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VerdictIcon(p.stats.dominant!, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: Theme.of(ctx).textTheme.titleLarge),
                      Text(p.address, style: Theme.of(ctx).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            VerdictSummary(p.stats),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => PlaceDetailScreen(placeId: p.placeId),
                ));
              },
              icon: const Icon(CupertinoIcons.chevron_right_circle_fill),
              label: Text('查看店家與 ${p.stats.total} 則評價'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppleAppBar(
        title: const Text('評價地圖'),
        actions: [
          CupertinoButton(
            onPressed: _locateMe,
            child: const Icon(CupertinoIcons.location_fill),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _taipei,
            myLocationEnabled: _myLocation,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            onMapCreated: (c) {
              _controller = c;
              _reload();
            },
            onCameraIdle: _onCameraIdle,
          ),
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.paddingOf(context).top + 12,
            child: _Legend(loading: _loading, error: _error),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.loading, this.error});
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.labelSmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final v in Verdict.values)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        VerdictIcon(v, size: 18),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(v.label, style: text, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error!, style: text?.copyWith(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
