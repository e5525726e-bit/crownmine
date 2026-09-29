import 'verdict.dart';

class Review {
  const Review({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.authorName,
    required this.verdict,
    required this.body,
    required this.createdAt,
    this.pricePaid,
    this.visitedOn,
    this.hasReceipt = false,
    this.photoUrls = const [],
    this.tags = const [],
  });

  final String id;
  final String placeId;
  final String userId;
  final String authorName;
  final Verdict verdict;
  final String body;
  final DateTime createdAt;
  final int? pricePaid;
  final DateTime? visitedOn;

  /// 使用者有附上消費證明（收據照片）。
  final bool hasReceipt;
  final List<String> photoUrls;

  /// 附加標籤（IG 網紅店、網美店）。
  final List<ReviewTag> tags;

  factory Review.fromRow(
    Map<String, dynamic> r, {
    required String Function(String storagePath) photoUrl,
  }) {
    final profile = r['profiles'] as Map<String, dynamic>?;
    final photos = (r['review_photos'] as List?) ?? const [];
    return Review(
      id: r['id'] as String,
      placeId: r['place_id'] as String,
      userId: r['user_id'] as String,
      authorName: (profile?['display_name'] as String?) ?? '匿名食客',
      verdict: Verdict.fromDb(r['verdict'] as String),
      body: r['body'] as String,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      pricePaid: r['price_paid'] as int?,
      visitedOn: r['visited_on'] == null
          ? null
          : DateTime.parse(r['visited_on'] as String),
      hasReceipt: r['receipt_path'] != null,
      tags: ReviewTag.listFromDb(r['tags']),
      photoUrls: photos
          .map((p) =>
              photoUrl((p as Map<String, dynamic>)['storage_path'] as String))
          .toList(),
    );
  }
}

/// App 內搜尋評價時的結果：店家 + 皇冠/地雷數。
class ReviewedPlace {
  const ReviewedPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.stats,
    this.lat,
    this.lng,
    this.primaryType,
    this.types = const [],
  });

  final String placeId;
  final String name;
  final String address;
  final PlaceStats stats;
  final double? lat;
  final double? lng;
  final String? primaryType;
  final List<String> types;

  bool get hasLocation => lat != null && lng != null;

  factory ReviewedPlace.fromRow(Map<String, dynamic> r) => ReviewedPlace(
        placeId: r['place_id'] as String,
        name: r['name'] as String,
        address: (r['address'] as String?) ?? '',
        stats: PlaceStats.fromRow(r),
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
        primaryType: r['primary_type'] as String?,
        types: ((r['types'] as List?) ?? const []).cast<String>(),
      );
}

/// 一家店的四種核心判斷各有幾個，以及各種附加標籤各被標了幾次。
class PlaceStats {
  const PlaceStats({
    this.crowns = 0,
    this.greens = 0,
    this.mines = 0,
    this.poops = 0,
    this.richs = 0,
    this.fires = 0,
    this.igs = 0,
    this.photogenics = 0,
    this.dates = 0,
  });

  final int crowns;
  final int greens;
  final int mines;
  final int poops;
  final int richs;
  final int fires;
  final int igs;
  final int photogenics;
  final int dates;

  int get total => crowns + richs + greens + mines;

  /// 最多人給的標記；平手時依 [Verdict.values] 的順序（皇冠優先）。
  Verdict? get dominant {
    if (total == 0) return null;
    var best = Verdict.values.first;
    for (final v in Verdict.values) {
      if (count(v) > count(best)) best = v;
    }
    return best;
  }

  int count(Verdict v) => switch (v) {
        Verdict.crown => crowns,
        Verdict.rich => richs,
        Verdict.green => greens,
        Verdict.mine => mines,
      };

  int tagCount(ReviewTag t) => switch (t) {
        ReviewTag.fire => fires,
        ReviewTag.ig => igs,
        ReviewTag.photogenic => photogenics,
        ReviewTag.date => dates,
        ReviewTag.poop => poops,
      };

  /// 至少三分之一的評價標了這個標籤，就算是這家店的特徵（地圖徽章用）。
  bool isTagged(ReviewTag t) => tagCount(t) > 0 && tagCount(t) * 3 >= total;

  /// 這家店的特徵標籤（達到 [isTagged] 門檻者，依 [ReviewTag.values] 順序）。
  List<ReviewTag> get featureTags =>
      [for (final t in ReviewTag.values) if (isTagged(t)) t];

  /// 有任何一種標籤被標過。
  bool get hasTags => ReviewTag.values.any((t) => tagCount(t) > 0);

  factory PlaceStats.fromRow(Map<String, dynamic>? r) => PlaceStats(
        crowns: (r?['crowns'] as num?)?.toInt() ?? 0,
        greens: (r?['greens'] as num?)?.toInt() ?? 0,
        mines: (r?['mines'] as num?)?.toInt() ?? 0,
        poops: (r?['poops'] as num?)?.toInt() ?? 0,
        igs: (r?['igs'] as num?)?.toInt() ?? 0,
        photogenics: (r?['photogenics'] as num?)?.toInt() ?? 0,
        richs: (r?['richs'] as num?)?.toInt() ?? 0,
        fires: (r?['fires'] as num?)?.toInt() ?? 0,
        dates: (r?['dates'] as num?)?.toInt() ?? 0,
      );
}
