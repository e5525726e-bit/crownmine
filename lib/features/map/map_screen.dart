import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../di.dart';
import '../../models/food_category.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../models/tw_city.dart';
import '../../models/verdict.dart';
import '../../services/location_hub.dart';
import '../../utils/format.dart';
import '../../widgets/apple_bars.dart';
import '../../widgets/category_chips.dart';
import '../../widgets/google_attribution.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/photo_strip.dart';
import '../../widgets/place_thumbnail.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/verdict_icon.dart';
import '../../widgets/verdict_summary.dart';
import '../place/place_detail_screen.dart';
import 'map_style.dart';
import 'verdict_marker.dart';

/// 主畫面：地圖 + 搜尋 + 附近，全部在同一頁。
/// - 上方：搜尋框（限所在縣市）、餐飲種類
/// - 地圖：有評價的店＝彩色大頭針；放大後範圍內其他餐飲店＝灰色小針；搜尋結果也會標上去
/// - 下方可拉起的清單：附近（畫面範圍內的店，依距離）、熱門（評價最多）、搜尋結果
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _Sheet { nearby, hot }

class _MapScreenState extends State<MapScreen> {
  static const _taipei =
      CameraPosition(target: LatLng(25.0418, 121.5436), zoom: 13);

  /// 放大到這個等級以上才向 Google 查詢範圍內所有餐飲店。
  static const double _minZoomForAllPlaces = 15;

  GoogleMapController? _controller;
  bool _iconsReady = false;
  Set<Marker> _markers = const {};
  bool _zoomedOut = true;
  LatLng? _myPos;
  LatLng? _center;
  Timer? _debounce;
  bool _loading = false;
  bool _myLocation = false;
  String? _error;
  FoodCategory _category = FoodCategory.all;
  StreamSubscription<({double lat, double lng})>? _locSub;

  /// 地圖還沒建立好時先記著要移去的位置，建立後馬上移過去。
  LatLng? _pendingCenter;

  // ---- 搜尋
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  TwCity? _city;
  bool _cityAuto = true;

  /// 定位到了但不在台灣：搜尋改成以目前位置為中心，不限縣市。
  bool _abroad = false;
  List<Place>? _results;
  bool _searching = false;
  String? _searchError;
  String _lastQuery = '';

  // ---- 清單
  _Sheet _sheet = _Sheet.nearby;
  List<ReviewedPlace> _reviewedInView = const [];
  List<Place> _nearbyInView = const [];
  Future<List<ReviewedPlace>>? _hot;

  /// 已知的店家統計（地圖範圍內、搜尋比對到的），給搜尋結果列顯示用。
  final Map<String, PlaceStats> _statsById = {};

  @override
  void initState() {
    super.initState();
    final known = LocationHub.last;
    if (known != null) {
      _myPos = LatLng(known.lat, known.lng);
      _pendingCenter = _myPos;
    }
    _locSub = LocationHub.updates.listen((p) {
      if (!mounted) return;
      final here = LatLng(p.lat, p.lng);
      setState(() {
        _myLocation = true;
        _myPos = here;
      });
      _moveTo(here);
    });
    _hot = reviewRepo.searchReviewedPlaces('');
    _prepare();
    _detectCity();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locSub?.cancel();
    _searchCtl.dispose();
    _searchFocus.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    await VerdictMarkerIcons.preload(dpr);
    _iconsReady = true;
    if (mounted) setState(() {});
    await LocationHub.warmUp();
  }

  Future<void> _moveTo(LatLng here) async {
    final c = _controller;
    if (c == null) {
      _pendingCenter = here;
      return;
    }
    _pendingCenter = null;
    await c.animateCamera(CameraUpdate.newLatLngZoom(here, 16));
  }

  Future<void> _locateMe({bool silent = false}) async {
    try {
      final p = await LocationHub.locate(silent: silent);
      if (p == null || !mounted) return;
      final here = LatLng(p.lat, p.lng);
      setState(() {
        _myLocation = true;
        _myPos = here;
      });
      await _moveTo(here);
    } catch (e) {
      if (!silent) _toast(friendlyError(e));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------- 縣市
  Future<void> _detectCity() async {
    try {
      var pos = LocationHub.last;
      if (pos == null) {
        await LocationHub.warmUp();
        pos = LocationHub.last;
      }
      if (pos == null) return;
      final c = await _cityFromNearby(pos.lat, pos.lng) ??
          cityAt(pos.lat, pos.lng);
      if (!mounted || !_cityAuto) return;
      setState(() {
        _city = c;
        _abroad = c == null;
      });
    } catch (_) {}
  }

  Future<TwCity?> _cityFromNearby(double lat, double lng) async {
    try {
      final near = await placesService.searchNearby(
          lat: lat, lng: lng, radiusMeters: 500);
      for (final p in near) {
        final c = cityOfAddress(p.address);
        if (c != null) return c;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          ListTile(
            leading: const Icon(CupertinoIcons.location_fill),
            title: const Text('依目前定位'),
            trailing: _cityAuto ? const Icon(CupertinoIcons.checkmark) : null,
            onTap: () => Navigator.pop(context, 'auto'),
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.globe),
            title: const Text('全台灣'),
            trailing: !_cityAuto && _city == null
                ? const Icon(CupertinoIcons.checkmark)
                : null,
            onTap: () => Navigator.pop(context, 'all'),
          ),
          const Divider(height: 1),
          for (final c in kTwCities)
            ListTile(
              title: Text(c.name),
              trailing: !_cityAuto && _city == c
                  ? const Icon(CupertinoIcons.checkmark)
                  : null,
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked == 'auto') {
        _cityAuto = true;
        _city = null;
      } else if (picked == 'all') {
        _cityAuto = false;
        _city = null;
      } else {
        _cityAuto = false;
        _city = picked as TwCity;
      }
    });
    if (picked == 'auto') await _detectCity();
    if (_searchCtl.text.trim().isNotEmpty) _submitSearch();
  }

  // ------------------------------------------------------------- 搜尋
  Future<void> _submitSearch([String? _]) async {
    final q = _searchCtl.text.trim();
    _searchFocus.unfocus();
    if (q.isEmpty && _category.isAll) {
      _clearSearch();
      return;
    }
    final typed = cityInText(q);
    final city = typed ?? _city;
    var full = _category.queryFor(q);
    if (city != null && !city.mentionedIn(full)) full = '${city.name} $full';
    // 沒有縣市可限制（在國外、或定位失敗）時，以目前位置為中心找 30 公里內
    final here = city == null && _cityAuto ? LocationHub.last : null;
    setState(() {
      _searching = true;
      _searchError = null;
      _lastQuery = q.isEmpty ? _category.label : q;
    });
    try {
      final statsFuture = q.isEmpty
          ? Future.value(<ReviewedPlace>[])
          : reviewRepo.searchReviewedPlaces(q);
      final results = await placesService.searchText(
        full,
        type: _category.searchType,
        city: city,
        lat: here?.lat,
        lng: here?.lng,
        radiusMeters: here == null ? null : 30000,
      );
      for (final r in await statsFuture) {
        _statsById[r.placeId] = r.stats;
      }
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
      await _fitTo(results);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results ??= const [];
        _searching = false;
        _searchError = friendlyError(e);
      });
    }
  }

  void _clearSearch() {
    _searchCtl.clear();
    setState(() {
      _results = null;
      _searchError = null;
    });
    _reload();
  }

  Future<void> _fitTo(List<Place> places) async {
    final c = _controller;
    final pts = [
      for (final p in places)
        if (p.lat != null && p.lng != null) LatLng(p.lat!, p.lng!)
    ];
    if (c == null || pts.isEmpty) return;
    if (pts.length == 1) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 16));
      return;
    }
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    await c.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
          southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      70,
    ));
  }

  void _pickCategory(FoodCategory c) {
    setState(() => _category = c == _category ? FoodCategory.all : c);
    if (_searchCtl.text.trim().isNotEmpty || _results != null) {
      _submitSearch();
    } else {
      _reload();
    }
  }

  // ------------------------------------------------------------- 地圖標記
  void _onCameraIdle() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  bool _matches(List<String> types, String? primaryType, String name) =>
      _category.matches(types: types, primaryType: primaryType, name: name);

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
      _center = LatLng(
        (b.southwest.latitude + b.northeast.latitude) / 2,
        (b.southwest.longitude + b.northeast.longitude) / 2,
      );
      final reviewedFuture = reviewRepo.placesInBounds(
        minLat: b.southwest.latitude,
        minLng: b.southwest.longitude,
        maxLat: b.northeast.latitude,
        maxLng: b.northeast.longitude,
      );
      final zoomedOut = zoom < _minZoomForAllPlaces;
      final nearbyFuture = zoomedOut ? Future.value(<Place>[]) : _nearbyIn(b);
      final places = (await reviewedFuture)
          .where((p) => _matches(p.types, p.primaryType, p.name))
          .toList();
      final nearby = (await nearbyFuture)
          .where((p) => _matches(p.types, p.primaryType, p.name))
          .toList();
      for (final p in places) {
        _statsById[p.placeId] = p.stats;
      }

      // 搜尋結果一律標上去（不管放大程度）
      final unreviewed = <String, Place>{
        for (final p in nearby) p.id: p,
        for (final p in _results ?? const <Place>[]) p.id: p,
      };
      final markers = <Marker>{};
      final reviewedIds = {for (final p in places) p.placeId};
      final plain = await VerdictMarkerIcons.plainIcon();
      for (final p in unreviewed.values) {
        if (reviewedIds.contains(p.id) || p.lat == null || p.lng == null) {
          continue;
        }
        markers.add(Marker(
          markerId: MarkerId('plain-${p.id}'),
          position: LatLng(p.lat!, p.lng!),
          icon: plain,
          anchor: VerdictMarkerIcons.anchor,
          zIndexInt: 0,
          onTap: () => _showUnreviewed(p),
        ));
      }
      for (final p in places) {
        final dominant = p.stats.dominant;
        if (dominant == null) continue;
        markers.add(Marker(
          markerId: MarkerId(p.placeId),
          position: LatLng(p.lat!, p.lng!),
          icon: await VerdictMarkerIcons.icon(dominant, p.stats.total,
              tags: p.stats.featureTags),
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
        _reviewedInView = places;
        _nearbyInView = nearby;
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
        111320 *
        math.cos(lat * math.pi / 180) /
        2;
    final radius = math.sqrt(dLat * dLat + dLng * dLng).clamp(200.0, 1500.0);
    if (!_category.isAll && !_category.hasTypes) {
      return placesService.searchText(
        _category.keyword,
        lat: lat,
        lng: lng,
        radiusMeters: radius,
        type: _category.searchType,
      );
    }
    return placesService.searchNearby(
        lat: lat, lng: lng, radiusMeters: radius, types: _category.types);
  }

  // ------------------------------------------------------------- 距離
  double? _distanceTo(double? lat, double? lng) {
    final from = _myPos ?? _center;
    if (from == null || lat == null || lng == null) return null;
    const r = 6371000.0;
    final dLat = (lat - from.latitude) * math.pi / 180;
    final dLng = (lng - from.longitude) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(from.latitude * math.pi / 180) *
            math.cos(lat * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static String _fmtDistance(double m) =>
      m < 1000 ? '${m.round()} 公尺' : '${(m / 1000).toStringAsFixed(1)} 公里';

  // ------------------------------------------------------------- 開店家
  void _open(String placeId, {Place? initial}) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => PlaceDetailScreen(placeId: placeId, initial: initial),
    ));
  }

  /// 店家照片：Google 照片（搜尋結果自帶，沒有就再查一次詳細資料）＋食客上傳的評價照片。
  Future<({List<String> user, List<PlacePhoto> google})> _photosOf(
      String placeId, {List<PlacePhoto> known = const []}) async {
    final userFuture = reviewRepo
        .reviewsFor(placeId)
        .then((rs) => [for (final r in rs) ...r.photoUrls])
        .catchError((_) => <String>[]);
    final googleFuture = known.isNotEmpty
        ? Future.value(known)
        : placesService
            .getDetails(placeId)
            .then((d) => d.photos)
            .catchError((_) => <PlacePhoto>[]);
    return (user: await userFuture, google: await googleFuture);
  }

  Widget _photoSection(String placeId, {List<PlacePhoto> known = const []}) =>
      FutureBuilder<({List<String> user, List<PlacePhoto> google})>(
        future: _photosOf(placeId, known: known),
        builder: (context, snap) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PhotoStrip(
            loading: !snap.hasData,
            userPhotoUrls: snap.data?.user ?? const [],
            googlePhotos: snap.data?.google ?? const [],
            height: 140,
          ),
        ),
      );

  void _showUnreviewed(Place p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photoSection(p.id, known: p.photos),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: Theme.of(ctx).textTheme.titleLarge),
                  Text(
                    [
                      if (p.primaryTypeLabel != null) p.primaryTypeLabel!,
                      p.address
                    ].join(' · '),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text('還沒有人評價這家店',
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _open(p.id, initial: p);
                    },
                    icon: const Icon(CupertinoIcons.square_pencil),
                    label: const Text('查看店家並寫第一則評價'),
                  ),
                ],
              ),
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photoSection(p.placeId),
            Padding(
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
                            Text(p.name,
                                style: Theme.of(ctx).textTheme.titleLarge),
                            Text(p.address,
                                style: Theme.of(ctx).textTheme.bodySmall),
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
                      _open(p.placeId);
                    },
                    icon: const Icon(CupertinoIcons.chevron_right_circle_fill),
                    label: Text('查看店家與 ${p.stats.total} 則評價'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- 畫面
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppleAppBar(
        title: const Text('美食地圖'),
        actions: [
          CupertinoButton(
            onPressed: () => _locateMe(),
            child: const Icon(CupertinoIcons.location_fill),
          ),
        ],
      ),
      body: Builder(
        builder: (context) => Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _myPos == null
                  ? _taipei
                  : CameraPosition(target: _myPos!, zoom: 16),
              style: kFoodOnlyMapStyle,
              myLocationEnabled: _myLocation,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              markers: _markers,
              padding: const EdgeInsets.only(bottom: 120),
              onMapCreated: (c) {
                _controller = c;
                final pending = _pendingCenter;
                if (pending != null) {
                  _pendingCenter = null;
                  c.moveCamera(CameraUpdate.newLatLngZoom(pending, 16));
                }
                _reload();
              },
              onCameraIdle: _onCameraIdle,
              onTap: (_) => _searchFocus.unfocus(),
            ),
            // 上方：搜尋框 + 縣市 + 種類
            Positioned(
              left: 0,
              right: 0,
              top: barInsets(context).top + 6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoSearchTextField(
                            controller: _searchCtl,
                            focusNode: _searchFocus,
                            placeholder: _city != null
                                ? '搜尋${_city!.name}的店家'
                                : _abroad && _cityAuto
                                    ? '搜尋附近的店家'
                                    : '搜尋店名或種類',
                            onSubmitted: _submitSearch,
                            onSuffixTap: _clearSearch,
                            style: theme.textTheme.bodyLarge,
                            backgroundColor: theme.cardTheme.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CityChip(
                          label: _city?.name ??
                              (_cityAuto
                                  ? (_abroad ? '目前位置附近' : '定位中…')
                                  : '全台灣'),
                          auto: _cityAuto,
                          onTap: _pickCity,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  CategoryChips(selected: _category, onChanged: _pickCategory),
                ],
              ),
            ),
            // 下方可拉起的清單
            DraggableScrollableSheet(
              initialChildSize: 0.26,
              minChildSize: 0.11,
              maxChildSize: 0.88,
              snap: true,
              snapSizes: const [0.26, 0.55],
              builder: (context, scroll) => _sheetBody(context, scroll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetBody(BuildContext context, ScrollController scroll) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final items = _sheetItems(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -2)),
        ],
      ),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 80),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: _results != null || _searching
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          _searching
                              ? '搜尋「$_lastQuery」中…'
                              : '「$_lastQuery」找到 ${_results!.length} 家',
                          style: text.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        onPressed: _clearSearch,
                        child: const Text('清除'),
                      ),
                    ],
                  )
                : CupertinoSlidingSegmentedControl<_Sheet>(
                    groupValue: _sheet,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    thumbColor: theme.colorScheme.surface,
                    children: {
                      _Sheet.nearby: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text('附近', style: text.titleSmall),
                      ),
                      _Sheet.hot: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text('熱門評價', style: text.titleSmall),
                      ),
                    },
                    onValueChanged: (m) {
                      if (m != null) setState(() => _sheet = m);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                for (final v in Verdict.values) ...[
                  VerdictIcon(v, size: 16),
                  const SizedBox(width: 3),
                  Text(v.label, style: text.labelSmall),
                  const SizedBox(width: 10),
                ],
                if (_loading || _searching)
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          if (_error != null || _searchError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Text(_searchError ?? _error!,
                  style:
                      text.labelSmall?.copyWith(color: theme.colorScheme.error)),
            ),
          ...items,
          const GoogleAttribution(),
        ],
      ),
    );
  }

  List<Widget> _sheetItems(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget hint(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Text(s, style: text.bodySmall, textAlign: TextAlign.center),
        );

    if (_searching) return const [];
    if (_results != null) {
      if (_results!.isEmpty) {
        return [
          hint(_city != null
              ? '在${_city!.name}找不到符合的店家。點右上角的縣市可以換地區或改成全台灣。'
              : _abroad && _cityAuto
                  ? '目前位置 30 公里內找不到符合的店家。可以在搜尋文字加上城市名稱。'
                  : '找不到符合的餐飲店家')
        ];
      }
      return [
        InsetGroup(children: [
          for (final p in _results!) _placeTile(p),
        ]),
      ];
    }

    if (_sheet == _Sheet.hot) {
      return [
        FutureBuilder<List<ReviewedPlace>>(
          future: _hot,
          builder: (context, snap) {
            if (snap.hasError) return hint(friendlyError(snap.error!));
            if (!snap.hasData) return hint('載入中…');
            final list = snap.data!;
            if (list.isEmpty) return hint('還沒有任何評價，到地圖上點一家店寫第一則吧！');
            return InsetGroup(children: [
              for (final r in list) _reviewedTile(r),
            ]);
          },
        ),
      ];
    }

    // 附近：畫面範圍內的店，依距離
    final entries = <({double? d, Widget tile})>[
      for (final r in _reviewedInView)
        (d: _distanceTo(r.lat, r.lng), tile: _reviewedTile(r)),
      for (final p in _nearbyInView)
        if (!_reviewedInView.any((r) => r.placeId == p.id))
          (d: _distanceTo(p.lat, p.lng), tile: _placeTile(p)),
    ]..sort((a, b) => (a.d ?? 1e12).compareTo(b.d ?? 1e12));
    if (entries.isEmpty) {
      return [
        hint(_zoomedOut
            ? '這個範圍內還沒有評價。放大地圖會列出範圍內所有餐飲店，或用上方搜尋。'
            : (_category.isAll
                ? '這個範圍內沒有餐飲店家'
                : '這個範圍內沒有「${_category.label}」的店家'))
      ];
    }
    return [
      if (_zoomedOut) hint('放大地圖可以看到範圍內所有餐飲店（灰色小針＝尚無評價）'),
      InsetGroup(children: [for (final e in entries) e.tile]),
    ];
  }

  Widget _reviewedTile(ReviewedPlace r) {
    final d = _distanceTo(r.lat, r.lng);
    return ListTile(
      leading: VerdictIcon(r.stats.dominant ?? Verdict.green, size: 32),
      title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [if (d != null) _fmtDistance(d), r.address].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [VerdictSummary(r.stats, compact: true), const Chevron()],
      ),
      onTap: () => _open(r.placeId),
    );
  }

  Widget _placeTile(Place p) {
    final d = _distanceTo(p.lat, p.lng);
    final stats = _statsById[p.id];
    return ListTile(
      leading: PlaceThumbnail(p, size: 44),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (d != null) _fmtDistance(d),
          if (p.primaryTypeLabel != null) p.primaryTypeLabel!,
          p.address,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: p.isClosedPermanently
          ? const Chip(label: Text('已歇業'))
          : stats != null && stats.total > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VerdictSummary(stats, compact: true),
                    const Chevron()
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('尚無評價',
                        style: Theme.of(context).textTheme.labelSmall),
                    const Chevron(),
                  ],
                ),
      onTap: () => _open(p.id, initial: p),
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip(
      {required this.label, required this.auto, required this.onTap});
  final String label;
  final bool auto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressScale(
      onTap: onTap,
      haptic: true,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(auto ? CupertinoIcons.location_fill : CupertinoIcons.map_pin,
                size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(label,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(width: 2),
            Icon(CupertinoIcons.chevron_down,
                size: 11, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
