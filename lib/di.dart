import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'data/review_repository.dart';
import 'services/places_service.dart';

/// 極簡的依賴管理：整個 App 共用一份服務物件。
late final PlacesService placesService;
late final ReviewRepository reviewRepo;

void initRepositories() {
  final client = Supabase.instance.client;
  reviewRepo = ReviewRepository(client);
  placesService = PlacesService(
    baseUrl: '${Env.supabaseUrl}/functions/v1/places',
    headers: () => {
      'apikey': Env.supabaseAnonKey,
      // 登入者帶自己的權杖，後端用來計算每日用量；未登入用 anon key
      'Authorization': 'Bearer ${client.auth.currentSession?.accessToken ?? Env.supabaseAnonKey}',
    },
  );
}
