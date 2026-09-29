import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全 App 共用的定位：
/// - 一打開就定位（[warmUp]），並把結果記在本機，下次啟動地圖直接從上次位置開始
/// - 各頁面用 [last] 立刻拿到最近一次位置，用 [locate] 取得新位置
class LocationHub {
  LocationHub._();

  static const _kLat = 'last_lat';
  static const _kLng = 'last_lng';

  /// 最近一次已知位置（可能是上次啟動存下來的）。
  static ({double lat, double lng})? last;

  static final StreamController<({double lat, double lng})> _updates =
      StreamController.broadcast();

  /// 每次拿到新位置就通知（地圖用來把畫面移過去）。
  static Stream<({double lat, double lng})> get updates => _updates.stream;

  static Future<void>? _warming;

  /// App 啟動時呼叫：先讀本機存的上次位置，再實際定位一次（第一次會詢問權限）。
  static Future<void> warmUp() => _warming ??= _warmUp();

  static Future<void> _warmUp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_kLat);
      final lng = prefs.getDouble(_kLng);
      if (lat != null && lng != null) _set((lat: lat, lng: lng));
    } catch (_) {}
    await locate(silent: true);
  }

  /// 取得目前位置；成功會更新 [last] 並廣播。
  /// [silent] 為 true 時任何失敗都安靜略過（回傳 null）。
  static Future<({double lat, double lng})?> locate({
    bool silent = false,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (silent) return null;
        throw Exception('請先開啟手機的定位服務');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (silent) return null;
        throw Exception('需要定位權限才能移到目前位置，請到系統設定開啟');
      }
      // 先用系統快取的位置（很快），再取一次精確位置
      try {
        final known = await Geolocator.getLastKnownPosition();
        if (known != null) _set((lat: known.latitude, lng: known.longitude));
      } catch (_) {}
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
            accuracy: accuracy, timeLimit: const Duration(seconds: 15)),
      );
      final here = (lat: pos.latitude, lng: pos.longitude);
      _set(here);
      return here;
    } catch (e) {
      if (silent) return null;
      rethrow;
    }
  }

  static void _set(({double lat, double lng}) p) {
    last = p;
    _updates.add(p);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_kLat, p.lat);
      prefs.setDouble(_kLng, p.lng);
    }).catchError((_) {});
  }
}
