import 'package:flutter/material.dart';

/// Google Maps Platform 條款要求：顯示 Places 資料時必須標示來源。
/// 正式上架前請換成 Google 官方提供的「Powered by Google」圖檔。
class GoogleAttribution extends StatelessWidget {
  const GoogleAttribution({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '店家資料由 Google 提供（Powered by Google）。評價皆為本 App 使用者發表，與 Google 無關。',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
}
