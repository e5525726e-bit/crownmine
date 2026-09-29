import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    initRepositories();
  }
  runApp(const CrownMineApp());
}
