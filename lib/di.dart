import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'data/review_repository.dart';
import 'services/places_service.dart';

/// 極簡的依賴管理：整個 App 共用一份服務物件。
final PlacesService placesService =
    PlacesService(apiKey: Env.googlePlacesApiKey);

late final ReviewRepository reviewRepo;

void initRepositories() {
  reviewRepo = ReviewRepository(Supabase.instance.client);
}
