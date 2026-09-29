import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../di.dart';
import '../../models/food_category.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../widgets/async_body.dart';
import '../../widgets/category_chips.dart';
import '../../widgets/google_attribution.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/inset_list_view.dart';
import '../../widgets/place_thumbnail.dart';
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
  final _controller = TextEditingController();
  Future<List<Place>>? _googleFuture;
  Future<List<ReviewedPlace>>? _appFuture;
  String _lastAppQuery = '';

  @override
  void initState() {
    super.initState();
    _appFuture = reviewRepo.searchReviewedPlaces('');
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

  /// 有分類時盡量以使用者附近為中心（只用上次已知的位置，不會跳出權限詢問）。
  Future<List<Place>> _searchGoogle(String query) async {
    double? lat, lng;
    if (!_category.isAll) {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        lat = pos?.latitude;
        lng = pos?.longitude;
      } catch (_) {}
    }
    return placesService.searchText(
      query,
      lat: lat,
      lng: lng,
      radiusMeters: lat == null ? null : 10000,
      type: _category.searchType,
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
          text: '輸入店名或地區，或點上面的種類開始找店家。\n只會列出餐飲業，不會顯示 Google 的評價。',
        ),
        builder: (context, places) {
          if (places.isEmpty) {
            return const _Hint(icon: CupertinoIcons.search, text: '找不到符合的餐飲店家');
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
