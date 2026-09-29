import 'package:flutter/material.dart';

import '../../di.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../widgets/async_body.dart';
import '../../widgets/google_attribution.dart';
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
        if (q.isNotEmpty) _googleFuture = placesService.searchText(q);
      } else {
        _lastAppQuery = q;
        _appFuture = reviewRepo.searchReviewedPlaces(q);
      }
    });
  }

  void _open(String placeId, {Place? initial}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceDetailScreen(placeId: placeId, initial: initial),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('找餐廳')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(
                    value: _Mode.google,
                    icon: Icon(Icons.storefront),
                    label: Text('找店家')),
                ButtonSegment(
                    value: _Mode.app,
                    icon: Icon(Icons.rate_review),
                    label: Text('找評價')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: _mode == _Mode.google
                    ? '店名或地區，例如「台中 火鍋」'
                    : '搜尋已有評價的店家',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _submit,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _mode == _Mode.google ? _googleResults() : _appResults(),
          ),
          if (_mode == _Mode.google) const GoogleAttribution(),
        ],
      ),
    );
  }

  Widget _googleResults() => AsyncBody<List<Place>>(
        future: _googleFuture,
        onRetry: _submit,
        empty: const _Hint(
          icon: Icons.storefront,
          text: '輸入店名或地區開始找店家。\n只會列出餐飲業，不會顯示 Google 的評價。',
        ),
        builder: (context, places) {
          if (places.isEmpty) {
            return const _Hint(icon: Icons.search_off, text: '找不到符合的餐飲店家');
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
                    if (p.priceLabel != null) p.priceLabel!,
                    p.address,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: p.isClosedPermanently
                    ? const Chip(label: Text('已歇業'))
                    : null,
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
              icon: Icons.rate_review_outlined,
              text: _lastAppQuery.isEmpty
                  ? '還沒有任何評價。\n到「找店家」找到餐廳後，寫下第一則吧！'
                  : '沒有符合「$_lastAppQuery」且已有評價的店家',
            );
          }
          return ListView.builder(
            itemCount: items.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    _lastAppQuery.isEmpty ? '評價最多的店家' : '搜尋結果',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                );
              }
              final r = items[i - 1];
              return ListTile(
                title: Text(r.name),
                subtitle: Text(r.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: VerdictSummary(r.stats, compact: true),
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
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}
