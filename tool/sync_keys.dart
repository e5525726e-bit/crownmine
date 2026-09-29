// 把 dart_defines.json 裡的 GOOGLE_PLACES_API_KEY 同步到原生層需要的位置：
//   android/local.properties      → MAPS_API_KEY=...
//   ios/Flutter/Secrets.xcconfig  → MAPS_API_KEY=...
// 兩個檔案都在 .gitignore 裡。
//
// 用法（在專案根目錄）：dart run tool/sync_keys.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final defines = File('dart_defines.json');
  if (!defines.existsSync()) {
    stderr.writeln('找不到 dart_defines.json，請先複製 dart_defines.example.json 並填入設定。');
    exit(1);
  }
  final json = jsonDecode(defines.readAsStringSync()) as Map<String, dynamic>;
  final key = (json['GOOGLE_PLACES_API_KEY'] as String?)?.trim() ?? '';
  if (key.isEmpty || key.startsWith('你的')) {
    stderr.writeln('dart_defines.json 的 GOOGLE_PLACES_API_KEY 還沒填。');
    exit(1);
  }

  // Android
  final local = File('android/local.properties');
  final lines = local.existsSync()
      ? local.readAsLinesSync().where((l) => !l.startsWith('MAPS_API_KEY=')).toList()
      : <String>[];
  lines.add('MAPS_API_KEY=$key');
  local.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('已寫入 ${local.path}');

  // iOS
  final xcconfig = File('ios/Flutter/Secrets.xcconfig');
  xcconfig.writeAsStringSync('MAPS_API_KEY=$key\n');
  stdout.writeln('已寫入 ${xcconfig.path}');
}
