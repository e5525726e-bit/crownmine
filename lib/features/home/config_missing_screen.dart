import 'package:flutter/material.dart';

/// 沒帶 dart-define 時顯示，避免一片白畫面讓人不知所措。
class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_suggest, size: 48),
                const SizedBox(height: 16),
                Text('尚未設定 API 金鑰',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  '請複製 dart_defines.example.json 為 dart_defines.json，'
                  '填入 Google Places 與 Supabase 的設定，再用\n\n'
                  'flutter run --dart-define-from-file=dart_defines.json\n\n'
                  '啟動。詳見 README.md。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
