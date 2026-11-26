import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network/api_client.dart';
import 'push/push_service.dart';
import 'storage/token_storage.dart';

/// Injetado em main.dart (precisa ser carregado antes do app abrir).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));

final pushServiceProvider = Provider<PushService>((ref) => NoopPushService());
