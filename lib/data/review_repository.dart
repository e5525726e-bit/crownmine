import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place.dart';
import '../models/review.dart';
import '../models/verdict.dart';

/// 所有「只屬於這個 App」的評價資料都走這裡（Supabase）。
class ReviewRepository {
  ReviewRepository(this._db);

  final SupabaseClient _db;

  static const _photoBucket = 'review-photos';
  static const _receiptBucket = 'receipts';

  /// Google 條款允許的快取期限。
  static const cacheTtl = Duration(days: 30);

  User? get currentUser => _db.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;

  String _photoUrl(String path) =>
      _db.storage.from(_photoBucket).getPublicUrl(path);

  // ------------------------------------------------------------------ auth

  Future<void> signIn({required String email, required String password}) =>
      _db.auth.signInWithPassword(email: email, password: password);

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _db.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

  Future<void> signOut() => _db.auth.signOut();

  Future<void> deleteAccount() async {
    await _db.rpc('delete_own_account');
    await _db.auth.signOut();
  }

  Future<String?> myDisplayName() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final row = await _db
        .from('profiles')
        .select('display_name')
        .eq('id', uid)
        .maybeSingle();
    return row?['display_name'] as String?;
  }

  Future<void> updateDisplayName(String name) async {
    final uid = currentUser!.id;
    await _db.from('profiles').update({'display_name': name}).eq('id', uid);
  }

  // ---------------------------------------------------------------- places

  /// 把 Google 店家基本資料寫進快取（評價需要以 place_id 為外鍵）。
  /// 只在店家還沒有資料時建立；已存在的由後端在查詳細資料時刷新（一般使用者不能改）。
  Future<void> cachePlace(Place p) => _db.from('places').upsert({
        'place_id': p.id,
        'name': p.name,
        'address': p.address,
        'lat': p.lat,
        'lng': p.lng,
        'primary_type': p.primaryType,
        'types': p.types,
        'google_maps_uri': p.googleMapsUri,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      }, ignoreDuplicates: true);

  Future<PlaceStats> stats(String placeId) async {
    final row = await _db
        .from('place_stats')
        .select()
        .eq('place_id', placeId)
        .maybeSingle();
    return PlaceStats.fromRow(row);
  }

  /// App 內搜尋評價。q 為空時等同排行榜。
  Future<List<ReviewedPlace>> searchReviewedPlaces(String q) async {
    final rows =
        await _db.rpc('search_reviewed_places', params: {'q': q.trim()});
    return (rows as List)
        .map((r) => ReviewedPlace.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// 地圖可視範圍內有評價的店家。
  Future<List<ReviewedPlace>> placesInBounds({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final rows = await _db.rpc('places_in_bounds', params: {
      'min_lat': minLat,
      'min_lng': minLng,
      'max_lat': maxLat,
      'max_lng': maxLng,
    });
    return (rows as List)
        .map((r) => ReviewedPlace.fromRow(r as Map<String, dynamic>))
        .where((p) => p.hasLocation)
        .toList();
  }

  // --------------------------------------------------------------- reviews

  static const _reviewSelect = 'id, place_id, user_id, verdict, body, '
      'price_paid, visited_on, receipt_path, tags, created_at, '
      'profiles(display_name), review_photos(storage_path)';

  Future<List<Review>> reviewsFor(String placeId) async {
    final rows = await _db
        .from('reviews')
        .select(_reviewSelect)
        .eq('place_id', placeId)
        .eq('status', 'visible')
        .order('created_at', ascending: false);
    return rows.map((r) => Review.fromRow(r, photoUrl: _photoUrl)).toList();
  }

  Future<Review?> myReviewFor(String placeId) async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final row = await _db
        .from('reviews')
        .select(_reviewSelect)
        .eq('place_id', placeId)
        .eq('user_id', uid)
        .maybeSingle();
    return row == null ? null : Review.fromRow(row, photoUrl: _photoUrl);
  }

  Future<List<(Review, Place)>> myReviews() async {
    final uid = currentUser?.id;
    if (uid == null) return const [];
    final rows = await _db
        .from('reviews')
        .select('$_reviewSelect, places(*)')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return rows
        .map((r) => (
              Review.fromRow(r, photoUrl: _photoUrl),
              Place.fromCacheRow(r['places'] as Map<String, dynamic>),
            ))
        .toList();
  }

  /// 新增或更新（同一人同一店只有一則）。
  Future<void> submitReview({
    required Place place,
    required Verdict verdict,
    required String body,
    int? pricePaid,
    DateTime? visitedOn,
    List<XFile> photos = const [],
    XFile? receipt,
    List<ReviewTag> tags = const [],
  }) async {
    final uid = currentUser!.id;
    await cachePlace(place);

    String? receiptPath;
    if (receipt != null) {
      receiptPath = '$uid/${place.id}/receipt_${_stamp()}.jpg';
      await _upload(_receiptBucket, receiptPath, await receipt.readAsBytes());
    }

    final row = <String, dynamic>{
      'place_id': place.id,
      'user_id': uid,
      'verdict': verdict.dbValue,
      'body': body.trim(),
      'price_paid': pricePaid,
      'visited_on': visitedOn?.toIso8601String().substring(0, 10),
      'tags': tags.map((t) => t.dbValue).toList(),
      'status': 'visible',
    };
    if (receiptPath != null) row['receipt_path'] = receiptPath;

    final saved = await _db
        .from('reviews')
        .upsert(row, onConflict: 'place_id,user_id')
        .select('id')
        .single();
    final reviewId = saved['id'] as String;

    for (final photo in photos) {
      final path = '$uid/$reviewId/${_stamp()}_${photos.indexOf(photo)}.jpg';
      await _upload(_photoBucket, path, await photo.readAsBytes());
      await _db
          .from('review_photos')
          .insert({'review_id': reviewId, 'storage_path': path});
    }
  }

  Future<void> deleteReview(String reviewId) =>
      _db.from('reviews').delete().eq('id', reviewId);

  // ------------------------------------------------------------ moderation

  Future<void> report(
    String reviewId, {
    required String reason,
    String? detail,
  }) =>
      _db.from('reports').upsert({
        'review_id': reviewId,
        'reporter_id': currentUser!.id,
        'reason': reason,
        'detail': detail,
      }, onConflict: 'review_id,reporter_id');

  Future<void> blockUser(String userId) => _db.from('blocks').upsert({
        'blocker_id': currentUser!.id,
        'blocked_id': userId,
      });

  // --------------------------------------------------------------- helpers

  Future<void> _upload(String bucket, String path, Uint8List bytes) =>
      _db.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

  String _stamp() => DateTime.now().millisecondsSinceEpoch.toString();
}
