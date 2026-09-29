import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../di.dart';
import '../../models/food_category.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../models/tw_city.dart';
import '../../services/location_hub.dart';
import '../../widgets/async_body.dart';
import '../../widgets/category_chips.dart';
import '../../widgets/google_attribution.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/inset_list_view.dart';
import '../../widgets/place_thumbnail.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/verdict_summary.dart';
import '../place/place_detail_screen.dart';

enum _Mode { google, app }

/// 兩種搜尋：
/// - 找店家：問 Google（只有店家基本資料，沒有 Google 評價）
/// - 找評價：只在這個 App 的評價資料庫裡找
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  _Mode _mode = _Mode.google;
  FoodCategory _category = FoodCategory.all;

  /// 搜尋限制在這個縣市；null 代表全台灣。
  TwCity? _city;

  /// 縣市是自動定位來的（true）還是使用者手動選的（false）。
  bool _cityAuto = true;
  final _controller = TextEditingController();
  Future<List<Place>>? _googleFuture;
  Future<List<ReviewedPlace>>? _appFuture;
  String _lastAppQuery = '';

  @override
  void initState() {
    super.initState();
    _appFuture = reviewRepo.searchReviewedPlaces('');
    _detectCity();
  }

  /// 用定位判斷所在縣市（App 啟動時的自動定位；有上次位置就先用）。
  Future<void> _detectCity() async {
    try {
      var pos = LocationHub.last;
      if (pos == null) {
        await LocationHub.warmUp();
        pos = LocationHub.last;
      }
      if (pos == null) return;
      // 先問附近任何一家店的地址（最準，後端有快取），不行再用粗略的範圍判斷
      final c = await _cityFromNearby(pos.lat, pos.lng) ??
          cityAt(pos.lat, pos.lng) ??
          nearestCity(pos.lat, pos.lng);
      if (!mounted || !_cityAuto) return;
      setState(() => _city = c);
    } catch (_) {
      // 定位失敗就維持全台灣
    }
  }

  Future<TwCity?> _cityFromNearby(double lat, double lng) async {
    try {
      final near =
          await placesService.searchNearby(lat: lat, lng: lng, radiusMeters: 500);
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
    if (picked == 'auto') {
      await _detectCity();
    }
    _submit();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? _]) {
    final q = _controller.text.trim();
    setState(() {
      if (_mode == _Mode.google) {
        final full = _category.queryFor(q);
        if (full.isNotEmpty) _googleFuture = _searchGoogle(full);
      } else {
        _lastAppQuery = q;
        _appFuture = reviewRepo.searchReviewedPlaces(q);
      }
    });
  }

  /// 只列出所在縣市的店：使用者文字裡有提到別的縣市就以文字為準，
  /// 否則用定位到（或手動選）的縣市；都沒有就找全台灣。
  Future<List<Place>> _searchGoogle(String query) async {
    final typed = cityInText(_controller.text);
    final city = typed ?? _city;
    final full = city != null && !city.mentionedIn(query)
        ? '${city.name} $query'
        : query;
    return placesService.searchText(
      full,
      type: _category.searchType,
      city: city,
    );
  }

  void _pickCategory(FoodCategory c) {
    setState(() => _category = c == _category ? FoodCategory.all : c);
    _submit();
  }

  void _open(String placeId, {Place? initial}) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => PlaceDetailScreen(placeId: placeId, initial: initial),
    ));
  }

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
                  Text('找餐廳', style: theme.textTheme.displayLarge),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSearchTextField(
                controller: _controller,
                placeholder:
                    _mode == _Mode.google ? '店名或地區，例如「台中 火鍋」' : '搜尋已有評價的店家',
                onSubmitted: _submit,
                onSuffixTap: () {
                  _controller.clear();
                  if (_mode == _Mode.app) _submit();
                },
                style: theme.textTheme.bodyLarge,
                backgroundColor: theme.cardTheme.color,
              ),
            ),
            if (_mode == _Mode.google)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _CityChip(
                      label: _city?.name ?? (_cityAuto ? '定位中…' : '全台灣'),
                      auto: _cityAuto,
                      onTap: _pickCity,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _city == null
                            ? '會列出全台灣的結果'
                            : '只列出${_city!.name}的店家',
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<_Mode>(
                  groupValue: _mode,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  thumbColor:
                      (theme.cardTheme.color ?? theme.colorScheme.surface),
                  children: {
                    _Mode.google: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('找店家', style: theme.textTheme.titleSmall),
                    ),
                    _Mode.app: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('找評價', style: theme.textTheme.titleSmall),
                    ),
                  },
                  onValueChanged: (m) {
                    if (m != null) setState(() => _mode = m);
                  },
                ),
              ),
            ),
            if (_mode == _Mode.google)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: CategoryChips(
                    selected: _category, onChanged: _pickCategory),
              ),
            Expanded(
              child: _mode == _Mode.google ? _googleResults() : _appResults(),
            ),
            if (_mode == _Mode.google) const GoogleAttribution(),
          ],
        ),
      ),
    );
  }

  Widget _googleResults() => AsyncBody<List<Place>>(
        future: _googleFuture,
        onRetry: _submit,
        empty: const _Hint(
          icon: CupertinoIcons.search,
          text: '輸入店名，或點上面的種類開始找店家。\n只會列出你所在縣市的餐飲業，不會顯示 Google 的評價。',
        ),
        builder: (context, places) {
          if (places.isEmpty) {
            return _Hint(
                icon: CupertinoIcons.search,
                text: _city == null
                    ? '找不到符合的餐飲店家'
                    : '在${_city!.name}找不到符合的店家。\n點上面的縣市可以換地區或改成全台灣。');
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
                    if (p.priceLabel != null) p.priceLabel!,
                    p.address,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: p.isClosedPermanently
                    ? const Chip(label: Text('已歇業'))
                    : const Chevron(),
                onTap: () => _open(p.id, initial: p),
              );
            },
          );
        },
      );

  Widget _appResults() => AsyncBody<List<ReviewedPlace>>(
        future: _appFuture,
        onRetry: _submit,
        builder: (context, items) {
          if (items.isEmpty) {
            return _Hint(
              icon: CupertinoIcons.chat_bubble_2,
              text: _lastAppQuery.isEmpty
                  ? '還沒有任何評價。\n到「找店家」找到餐廳後，寫下第一則吧！'
                  : '沒有符合「$_lastAppQuery」且已有評價的店家',
            );
          }
          return InsetListView(
            header: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                _lastAppQuery.isEmpty ? '評價最多的店家' : '搜尋結果',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[i];
              return ListTile(
                title: Text(r.name),
                subtitle: Text(r.address,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VerdictSummary(r.stats, compact: true),
                    const Chevron()
                  ],
                ),
                onTap: () => _open(r.placeId),
              );
            },
          );
        },
      );
}

class _CityChip extends StatelessWidget {
  const _CityChip({required this.label, required this.auto, required this.onTap});
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                size: 12, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 44,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
        ),
      );
}
