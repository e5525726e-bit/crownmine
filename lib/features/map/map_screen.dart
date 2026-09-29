import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../di.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../models/verdict.dart';
import '../../utils/format.dart';
import '../../widgets/apple_bars.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/verdict_icon.dart';
import '../../widgets/verdict_summary.dart';
import '../place/place_detail_screen.dart';
import 'map_style.dart';
import 'verdict_marker.dart';

/// 地圖分頁：底圖只留道路與地名，餐飲店由 App 自己標出。
/// - 有評價的店：彩色大頭針，取最多人給的那一種判斷
/// - 放大到街區等級後，範圍內其他餐飲店：灰色小針，點了可以直接寫評價
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _taipei = CameraPosition(target: LatLng(25.0418, 121.5436), zoom: 13);

  /// 放大到這個等級以上才向 Google 查詢範圍內所有餐飲店。
  static const double _minZoomForAllPlaces = 15;

  GoogleMapController? _controller;
  bool _iconsReady = false;
  Set<Marker> _markers = const {};
  bool _zoomedOut = true;
  LatLng? _myPos;
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
    if (mounted) setState(() {});
    // 一打開就定位（第一次會跳出權限詢問）；拒絕就留在預設位置，不吵使用者
    await _locateMe(silent: true);
  }

  Future<void> _locateMe({bool silent = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!silent) _toast('請先開啟手機的定位服務');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!silent) _toast('需要定位權限才能移到目前位置，請到系統設定開啟');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _myLocation = true;
        _myPos = here;
      });
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(here, 16));
    } catch (e) {
      if (!silent) _toast(friendlyError(e));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      final zoom = await controller.getZoomLevel();
      final reviewedFuture = reviewRepo.placesInBounds(
        minLat: b.southwest.latitude,
        minLng: b.southwest.longitude,
        maxLat: b.northeast.latitude,
        maxLng: b.northeast.longitude,
      );
      // 放大到街區等級時，向 Google 找範圍內所有餐飲店（尚無評價的也標出來）
      final zoomedOut = zoom < _minZoomForAllPlaces;
      final nearbyFuture = zoomedOut ? Future.value(<Place>[]) : _nearbyIn(b);
      final places = await reviewedFuture;
      final nearby = await nearbyFuture;

      final markers = <Marker>{};
      final reviewedIds = {for (final p in places) p.placeId};
      final plain = await VerdictMarkerIcons.plainIcon();
      for (final p in nearby) {
        if (reviewedIds.contains(p.id) || p.lat == null || p.lng == null) continue;
        markers.add(Marker(
          markerId: MarkerId('plain-${p.id}'),
          position: LatLng(p.lat!, p.lng!),
          icon: plain,
          anchor: VerdictMarkerIcons.anchor,
          zIndexInt: 0,
          onTap: () => _showUnreviewed(p),
        ));
      }
      // 評價越多：圖示越大、浮在其他標記上面（zIndex）、顯示評價數
      for (final p in places) {
        final dominant = p.stats.dominant;
        if (dominant == null) continue;
        markers.add(Marker(
          markerId: MarkerId(p.placeId),
          position: LatLng(p.lat!, p.lng!),
          icon: await VerdictMarkerIcons.icon(dominant, p.stats.total,
              igBadge: p.stats.isTagged(ReviewTag.ig)),
          anchor: VerdictMarkerIcons.anchor,
          zIndexInt: 1 + p.stats.total,
          onTap: () => _showPlace(p),
        ));
      }
      if (_myPos != null) {
        markers.add(Marker(
          markerId: const MarkerId('me'),
          position: _myPos!,
          icon: await VerdictMarkerIcons.myLocationIcon(),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 100000,
          consumeTapEvents: true,
        ));
      }
      if (!mounted) return;
      setState(() {
        _markers = markers;
        _zoomedOut = zoomedOut;
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

  /// 以畫面中心為圓心、涵蓋可視範圍的半徑（最多 1.5 公里）找餐飲店。
  Future<List<Place>> _nearbyIn(LatLngBounds b) {
    final lat = (b.southwest.latitude + b.northeast.latitude) / 2;
    final lng = (b.southwest.longitude + b.northeast.longitude) / 2;
    final dLat = (b.northeast.latitude - b.southwest.latitude) * 111320 / 2;
    final dLng = (b.northeast.longitude - b.southwest.longitude) *
        111320 * math.cos(lat * math.pi / 180) / 2;
    final radius = math.sqrt(dLat * dLat + dLng * dLng).clamp(200.0, 1500.0);
    return placesService.searchNearby(lat: lat, lng: lng, radiusMeters: radius);
  }

  void _showUnreviewed(Place p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: Theme.of(ctx).textTheme.titleLarge),
            Text(
              [if (p.primaryTypeLabel != null) p.primaryTypeLabel!, p.address].join(' · '),
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text('還沒有人評價這家店', style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => PlaceDetailScreen(placeId: p.id, initial: p),
                ));
              },
              icon: const Icon(CupertinoIcons.square_pencil),
              label: const Text('查看店家並寫第一則評價'),
            ),
          ],
        ),
      ),
    );
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
            onPressed: () => _locateMe(),
            child: const Icon(CupertinoIcons.location_fill),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _taipei,
            style: kFoodOnlyMapStyle,
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
            child: _Legend(loading: _loading, error: _error, zoomedOut: _zoomedOut),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: _LocateButton(onPressed: _locateMe),
          ),
        ],
      ),
    );
  }
}

/// 右下角的定位按鈕：白色圓形、系統藍圖示，按下即縮小回饋。
class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressScale(
      onTap: onPressed,
      scale: 0.92,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Icon(CupertinoIcons.location_fill, color: theme.colorScheme.primary, size: 24),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.loading, this.error, required this.zoomedOut});
  final bool loading;
  final String? error;
  final bool zoomedOut;

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
              ],
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                zoomedOut ? '放大地圖可顯示範圍內所有餐飲店（灰色小針＝尚無評價）' : '灰色小針＝尚無評價的餐飲店，點一下就能寫第一則',
                style: text,
              ),
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
