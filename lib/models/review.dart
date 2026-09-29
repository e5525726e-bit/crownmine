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
      photoUrls: photos
          .map((p) => photoUrl((p as Map<String, dynamic>)['storage_path'] as String))
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
  });

  final String placeId;
  final String name;
  final String address;
  final PlaceStats stats;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  factory ReviewedPlace.fromRow(Map<String, dynamic> r) => ReviewedPlace(
        placeId: r['place_id'] as String,
        name: r['name'] as String,
        address: (r['address'] as String?) ?? '',
        stats: PlaceStats.fromRow(r),
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
      );
}

/// 一家店的六種標記各有幾個。
class PlaceStats {
  const PlaceStats({
    this.crowns = 0,
    this.cameras = 0,
    this.greens = 0,
    this.mines = 0,
    this.igtraps = 0,
    this.poops = 0,
  });

  final int crowns;
  final int cameras;
  final int greens;
  final int mines;
  final int igtraps;
  final int poops;

  int get total => crowns + cameras + greens + mines + igtraps + poops;

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
        Verdict.camera => cameras,
        Verdict.green => greens,
        Verdict.mine => mines,
        Verdict.igtrap => igtraps,
        Verdict.poop => poops,
      };

  factory PlaceStats.fromRow(Map<String, dynamic>? r) => PlaceStats(
        crowns: (r?['crowns'] as num?)?.toInt() ?? 0,
        cameras: (r?['cameras'] as num?)?.toInt() ?? 0,
        greens: (r?['greens'] as num?)?.toInt() ?? 0,
        mines: (r?['mines'] as num?)?.toInt() ?? 0,
        igtraps: (r?['igtraps'] as num?)?.toInt() ?? 0,
        poops: (r?['poops'] as num?)?.toInt() ?? 0,
      );
}
