import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/env.dart';
import 'features/home/config_missing_screen.dart';
import 'features/home/home_screen.dart';

class CrownMineApp extends StatelessWidget {
  const CrownMineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '皇冠與地雷',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFF6B800),
        brightness: Brightness.light,
        cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFF6B800),
        brightness: Brightness.dark,
        cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
      ),
      home: Env.isConfigured ? const HomeScreen() : const ConfigMissingScreen(),
    );
  }
}
