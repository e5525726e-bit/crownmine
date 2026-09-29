import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/verdict.dart';

/// 地圖標記的圖示大小（邏輯像素）。之後要調整尺寸改這裡即可。
const double kMarkerIconSize = 34;

/// 把四種標記的 SVG 畫成地圖用的 [BitmapDescriptor]：白色圓底 + 圖示。
class VerdictMarkerIcons {
  VerdictMarkerIcons._();

  static final Map<Verdict, BitmapDescriptor> _cache = {};

  static Future<Map<Verdict, BitmapDescriptor>> load(double devicePixelRatio) async {
    if (_cache.length == Verdict.values.length) return _cache;
    for (final v in Verdict.values) {
      _cache[v] = await _render(v, devicePixelRatio);
    }
    return _cache;
  }

  static Future<BitmapDescriptor> _render(Verdict v, double dpr) async {
    final info = await vg.loadPicture(SvgAssetLoader(v.asset), null);
    const padding = kMarkerIconSize * 0.18;
    const logical = kMarkerIconSize + padding * 2;
    final px = (logical * dpr).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    const center = Offset(logical / 2, logical / 2);
    canvas.drawCircle(
      center,
      logical / 2,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawCircle(center + const Offset(0, -0.5), logical / 2 - 1, Paint()..color = Colors.white);
    canvas
      ..save()
      ..translate(padding, padding)
      ..scale(kMarkerIconSize / info.size.width, kMarkerIconSize / info.size.height)
      ..drawPicture(info.picture)
      ..restore();

    final image = await recorder.endRecording().toImage(px, px);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    info.picture.dispose();
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: logical,
      height: logical,
    );
  }
}
