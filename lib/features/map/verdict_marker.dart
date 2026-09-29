import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/verdict.dart';

/// 大頭針針頭的基準直徑（邏輯像素）。之後要調整尺寸改這裡即可。
const double kPinHeadSize = 26;

/// 評價越多，大頭針越大、越「浮」。
/// 放大倍率隨評價數連續變化（對數）：1 則 1.0、10 則 1.25、100 則 1.5，最大 1.75。
class MarkerTier {
  const MarkerTier._(this.scale, this.showCount);

  /// 針頭放大倍率
  final double scale;

  /// 是否顯示評價數徽章（3 則以上）
  final bool showCount;

  static const double minScale = 1.0;
  static const double maxScale = 1.75;

  static double scaleFor(int total) {
    if (total <= 1) return minScale;
    return (minScale + 0.25 * math.log(total) / math.ln10)
        .clamp(minScale, maxScale);
  }

  static MarkerTier forCount(int total) =>
      MarkerTier._(scaleFor(total), total >= 3);
}

/// 把四種標記畫成 Google 地圖那種「大頭針」：
/// 針頭是白色圓形放評價圖示、外框用該標記的顏色、下面有針尖與地面陰影。
/// 取代 Google 原本的紅色大頭針。
class VerdictMarkerIcons {
  VerdictMarkerIcons._();

  static final Map<String, BitmapDescriptor> _cache = {};
  static final Map<Verdict, PictureInfo> _pictures = {};
  static double _dpr = 2;

  /// 徽章數字的字型；預設用系統字型，只有產生預覽圖時會指定。
  static String? badgeFontFamily;

  /// 針尖在圖片底部正中央，Marker 的 anchor 要設成這個值。
  static const Offset anchor = Offset(0.5, 1.0);

  static Future<void> preload(double devicePixelRatio) async {
    _dpr = devicePixelRatio;
    for (final v in Verdict.values) {
      _pictures[v] ??= await vg.loadPicture(SvgAssetLoader(v.asset), null);
    }
  }

  static final Map<String, PictureInfo> _tagPictures = {};

  /// 最多疊幾個附加標籤徽章（右上角留給評價數）。
  static const int maxTagBadges = 3;

  /// 依標記種類、評價數、這家店的特徵標籤取得圖示（同一組合只畫一次）。
  static Future<BitmapDescriptor> icon(Verdict v, int total,
      {List<ReviewTag> tags = const []}) async {
    final tier = MarkerTier.forCount(total);
    final badges = tags.take(maxTagBadges).toList();
    final key =
        '${v.dbValue}-$total-${badges.map((t) => t.dbValue).join(',')}';
    return _cache[key] ??= await _render(v, tier, total, badges);
  }

  static Future<BitmapDescriptor> _render(
      Verdict v, MarkerTier tier, int total, List<ReviewTag> tags) async {
    final (bytes, size) = await renderPng(v, tier, total, tags: tags);
    return BitmapDescriptor.bytes(bytes,
        width: size.width, height: size.height);
  }

  static BitmapDescriptor? _plain;
  static BitmapDescriptor? _me;

  /// 使用者目前位置：藍點 + 白邊 + 淡藍光暈（網頁版沒有內建藍點，所以自己畫）。
  static Future<BitmapDescriptor> myLocationIcon() async {
    if (_me != null) return _me!;
    const logical = 28.0;
    final px = (logical * _dpr).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_dpr);
    const c = Offset(logical / 2, logical / 2);
    canvas.drawCircle(c, logical / 2,
        Paint()..color = const Color(0xFF007AFF).withValues(alpha: 0.18));
    canvas.drawCircle(c, 9, Paint()..color = Colors.white);
    canvas.drawCircle(c, 7, Paint()..color = const Color(0xFF007AFF));
    final image = await recorder.endRecording().toImage(px, px);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return _me = BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        width: logical, height: logical);
  }

  /// 尚無評價的餐飲店：灰色小針、白色叉匙。
  static Future<BitmapDescriptor> plainIcon() async {
    if (_plain != null) return _plain!;
    final (bytes, size) = await renderPlainPng();
    return _plain =
        BitmapDescriptor.bytes(bytes, width: size.width, height: size.height);
  }

  static Future<(Uint8List, Size)> renderPlainPng() async {
    final food = _tagPictures['food'] ??= await vg.loadPicture(
        const SvgAssetLoader('assets/icons/food.svg'), null);
    const head = kPinHeadSize * 0.72;
    const tail = head * 0.55;
    const margin = 5.0;
    const width = head + margin * 2;
    const height = head + tail + margin;
    final px =
        Size((width * _dpr).ceilToDouble(), (height * _dpr).ceilToDouble());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_dpr);
    const headCenter = Offset(width / 2, margin + head / 2);
    const tip = Offset(width / 2, height);
    const r = head / 2;

    canvas.drawOval(
      Rect.fromCenter(
          center: tip - const Offset(0, 1),
          width: head * 0.5,
          height: head * 0.16),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
    );
    final body = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: r))
      ..moveTo(headCenter.dx - r * 0.55, headCenter.dy + r * 0.83)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(headCenter.dx + r * 0.55, headCenter.dy + r * 0.83)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFF8E8E93));
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
    const iconSize = head * 0.6;
    canvas
      ..save()
      ..translate(headCenter.dx - iconSize / 2, headCenter.dy - iconSize / 2)
      ..scale(iconSize / food.size.width, iconSize / food.size.height)
      ..drawPicture(food.picture)
      ..restore();

    final image = await recorder
        .endRecording()
        .toImage(px.width.toInt(), px.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return (bytes!.buffer.asUint8List(), const Size(width, height));
  }

  /// 畫出大頭針的 PNG（回傳位元組與邏輯尺寸）。獨立出來方便預覽與測試。
  /// [tags] 排在針頭左側，由上往下（最多 [maxTagBadges] 個）。
  static Future<(Uint8List, Size)> renderPng(
      Verdict v, MarkerTier tier, int total,
      {List<ReviewTag> tags = const []}) async {
    final info =
        _pictures[v] ??= await vg.loadPicture(SvgAssetLoader(v.asset), null);
    final badges = <PictureInfo>[];
    for (final t in tags.take(maxTagBadges)) {
      badges.add(_tagPictures[t.asset] ??=
          await vg.loadPicture(SvgAssetLoader(t.asset), null));
    }

    final head = kPinHeadSize * tier.scale; // 針頭直徑
    final ring = 3.0 * tier.scale; // 彩色外框寬
    final tail = head * 0.6; // 針尖長度
    final margin = 8.0 + 4 * (tier.scale - 1); // 留給徽章與陰影
    final width = head + ring * 2 + margin * 2;
    final height = head + ring * 2 + tail + margin;
    final px =
        Size((width * _dpr).ceilToDouble(), (height * _dpr).ceilToDouble());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_dpr);
    final headCenter = Offset(width / 2, margin + ring + head / 2);
    final tip = Offset(width / 2, height);
    final outerR = head / 2 + ring;

    // 地面陰影：越大的針陰影越明顯，看起來浮在地圖上
    canvas.drawOval(
      Rect.fromCenter(
          center: tip - const Offset(0, 1),
          width: head * 0.55,
          height: head * 0.18),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter =
            ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5 * tier.scale),
    );

    // 針身：圓形針頭 + 針尖（用標記顏色）
    final body = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: outerR))
      ..moveTo(headCenter.dx - outerR * 0.55, headCenter.dy + outerR * 0.83)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(headCenter.dx + outerR * 0.55, headCenter.dy + outerR * 0.83)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 2 * tier.scale),
    );
    canvas.drawPath(body, Paint()..color = v.color);

    // 白色針頭內圈 + 圖示
    canvas.drawCircle(headCenter, head / 2, Paint()..color = Colors.white);
    final iconSize = head * 0.72;
    canvas
      ..save()
      ..translate(headCenter.dx - iconSize / 2, headCenter.dy - iconSize / 2)
      ..scale(iconSize / info.size.width, iconSize / info.size.height)
      ..drawPicture(info.picture)
      ..restore();

    // 附加標籤徽章：統一排在針頭左側，由上往下一排（右上留給評價數）。
    // 標籤越多徽章越小，避免蓋住針頭。
    final badgeScale = switch (badges.length) { 0 || 1 => 0.5, 2 => 0.42, _ => 0.36 };
    final slots = switch (badges.length) {
      0 || 1 => const [Offset(-0.72, -0.72)],
      2 => const [Offset(-0.85, -0.6), Offset(-0.95, 0.28)],
      _ => const [Offset(-0.8, -0.78), Offset(-1.0, 0.0), Offset(-0.8, 0.78)],
    };
    for (var i = 0; i < badges.length; i++) {
      final pic = badges[i];
      final r = outerR * badgeScale;
      final c = headCenter + slots[i] * outerR;
      canvas.drawCircle(c, r + 1.5, Paint()..color = Colors.white);
      canvas.drawCircle(c, r, Paint()..color = Colors.white);
      canvas
        ..save()
        ..translate(c.dx - r * 0.8, c.dy - r * 0.8)
        ..scale(r * 1.6 / pic.size.width, r * 1.6 / pic.size.height)
        ..drawPicture(pic.picture)
        ..restore();
    }

    // 評價數徽章（右上角）
    if (tier.showCount) {
      final label = total >= 10000
          ? '${(total / 1000).floor()}k'
          : total >= 1000
              ? '${(total / 1000).toStringAsFixed(1)}k'
              : '$total';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: badgeFontFamily,
            color: Colors.white,
            fontSize: 9 + 2 * (tier.scale - 1),
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final badgeH = tp.height + 6;
      final badgeW = (tp.width + 10).clamp(badgeH, double.infinity);
      final badgeCenter =
          Offset(headCenter.dx + outerR * 0.72, headCenter.dy - outerR * 0.72);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: badgeCenter, width: badgeW, height: badgeH),
        Radius.circular(badgeH / 2),
      );
      canvas.drawRRect(rect.inflate(1.5), Paint()..color = Colors.white);
      canvas.drawRRect(rect, Paint()..color = const Color(0xFF1C1C1E));
      tp.paint(canvas, badgeCenter - Offset(tp.width / 2, tp.height / 2));
    }

    final image = await recorder
        .endRecording()
        .toImage(px.width.toInt(), px.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return (bytes!.buffer.asUint8List(), Size(width, height));
  }
}
