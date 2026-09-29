import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/apple_bars.dart';
import '../../di.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../widgets/apple_dialogs.dart';
import '../../widgets/async_body.dart';
import '../../widgets/google_attribution.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/verdict_summary.dart';
import '../auth/login_screen.dart';
import '../review/report_dialog.dart';
import '../review/review_card.dart';
import '../review/write_review_screen.dart';

class _Detail {
  const _Detail({
    required this.place,
    required this.stats,
    required this.reviews,
    required this.mine,
  });
  final Place place;
  final PlaceStats stats;
  final List<Review> reviews;
  final Review? mine;
}

class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({super.key, required this.placeId, this.initial});

  final String placeId;

  /// 從搜尋列表帶進來的資料，讓畫面先有東西可顯示。
  final Place? initial;

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late Future<_Detail> _future = _load();

  Future<_Detail> _load() async {
    final results = await Future.wait<Object?>([
      _loadPlace(),
      reviewRepo.stats(widget.placeId),
      reviewRepo.reviewsFor(widget.placeId),
      reviewRepo.myReviewFor(widget.placeId),
    ]);
    return _Detail(
      place: results[0] as Place,
      stats: results[1] as PlaceStats,
      reviews: results[2] as List<Review>,
      mine: results[3] as Review?,
    );
  }

  Future<Place> _loadPlace() async {
    try {
      return await placesService.getDetails(widget.placeId);
    } catch (_) {
      if (widget.initial != null) return widget.initial!;
      rethrow;
    }
  }

  void _reload() => setState(() => _future = _load());

  Future<bool> _ensureSignedIn() async {
    if (reviewRepo.isSignedIn) return true;
    final ok = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
          builder: (_) => const LoginScreen(), fullscreenDialog: true),
    );
    return ok == true && reviewRepo.isSignedIn;
  }

  Future<void> _write(Place place, Review? existing) async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(CupertinoPageRoute(
      builder: (_) => WriteReviewScreen(place: place, existing: existing),
      fullscreenDialog: true,
    ));
    if (saved == true) _reload();
  }

  Future<void> _report(Review r) async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    final result = await showReportSheet(context);
    if (result == null) return;
    await reviewRepo.report(r.id, reason: result.reason, detail: result.detail);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已送出檢舉，我們會在 24 小時內處理')),
    );
  }

  Future<void> _block(Review r) async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    final ok = await showConfirm(
      context,
      title: '封鎖此使用者？',
      message: '之後將不會再看到「${r.authorName}」的任何評價。',
      confirmLabel: '封鎖',
      destructive: true,
    );
    if (!ok) return;
    await reviewRepo.blockUser(r.userId);
    _reload();
  }

  Future<void> _delete(Review r) async {
    final ok = await showConfirm(
      context,
      title: '刪除我的評價？',
      message: '刪除後無法復原。',
      confirmLabel: '刪除',
      destructive: true,
    );
    if (!ok) return;
    await reviewRepo.deleteReview(r.id);
    _reload();
  }

  Future<void> _open(String? url) async {
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody<_Detail>(
      future: _future,
      onRetry: _reload,
      builder: (context, d) {
        final p = d.place;
        final theme = Theme.of(context);
        final text = theme.textTheme;
        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: AppleAppBar(
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          // 主要動作放在底部材質列（iOS 慣例），而不是浮動按鈕
          bottomNavigationBar: AppleBottomBar(
            child: FilledButton.icon(
              onPressed: () => _write(p, d.mine),
              icon: Icon(d.mine == null
                  ? CupertinoIcons.square_pencil
                  : CupertinoIcons.pencil),
              label: Text(d.mine == null ? '寫評價' : '修改我的評價'),
            ),
          ),
          body: Builder(
            builder: (context) => RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _future;
              },
              child: ListView(
                padding: barInsets(context),
                children: [
                  if (p.photos.isNotEmpty) _HeaderPhoto(place: p),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(p.name, style: text.headlineLarge),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      [
                        if (p.primaryTypeLabel != null) p.primaryTypeLabel!,
                        if (p.priceLabel != null) p.priceLabel!,
                        if (p.isClosedPermanently) '已歇業',
                      ].join(' · '),
                      style: text.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  InsetGroup(
                    children: [
                      ListTile(
                        leading: const Icon(CupertinoIcons.location_solid),
                        title: Text(p.address),
                        trailing:
                            p.googleMapsUri == null ? null : const Chevron(),
                        onTap: () => _open(p.googleMapsUri),
                      ),
                      if (p.phone != null)
                        ListTile(
                          leading: const Icon(CupertinoIcons.phone_fill),
                          title: Text(p.phone!),
                          onTap: () => _open('tel:${p.phone}'),
                        ),
                      if (p.website != null)
                        ListTile(
                          leading: const Icon(CupertinoIcons.globe),
                          title: Text(p.website!,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _open(p.website),
                        ),
                      if (p.weekdayDescriptions.isNotEmpty)
                        ExpansionTile(
                          leading: const Icon(CupertinoIcons.clock_fill),
                          title: const Text('營業時間'),
                          children: [
                            for (final line in p.weekdayDescriptions)
                              ListTile(
                                  dense: true,
                                  title: Text(line, style: text.bodyMedium)),
                          ],
                        ),
                    ],
                  ),
                  const GoogleAttribution(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('這個 App 的評價', style: text.headlineMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('共 ${d.stats.total} 則，皆為本 App 使用者發表',
                        style: text.bodySmall),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                      child: VerdictSummary(d.stats),
                    ),
                  ),
                  if (d.reviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '還沒有人評價這家店，成為第一個吧！',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final r in d.reviews)
                    ReviewCard(
                      review: r,
                      isMine: r.userId == reviewRepo.currentUser?.id,
                      onReport: () => _report(r),
                      onBlock: () => _block(r),
                      onEdit: () => _write(p, r),
                      onDelete: () => _delete(r),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderPhoto extends StatelessWidget {
  const _HeaderPhoto({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    final photo = place.photos.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                placesService.photoUrl(photo, maxWidth: 1200),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            if (photo.attributions.isNotEmpty)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '照片：${photo.attributions.join('、')}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
