/// Notificações push (Firebase Cloud Messaging).
///
/// O app funciona sem Firebase: os lembretes também aparecem na tela "Lembretes"
/// (GET /notificacoes). Para ativar o push real:
///   1. `flutterfire configure` no projeto (gera firebase_options.dart);
///   2. descomente firebase_core e firebase_messaging no pubspec.yaml;
///   3. troque `NoopPushService` por `FcmPushService` em core/providers.dart;
///   4. configure FIREBASE_CREDENCIAIS no backend.
///
/// Implementação de referência:
/// ```dart
/// class FcmPushService implements PushService {
///   @override
///   Future<String?> obterToken() async {
///     await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
///     final fcm = FirebaseMessaging.instance;
///     final perm = await fcm.requestPermission();
///     if (perm.authorizationStatus == AuthorizationStatus.denied) return null;
///     return fcm.getToken();
///   }
/// }
/// ```
abstract class PushService {
  /// Pede permissão ao usuário e devolve o token do dispositivo (ou null).
  Future<String?> obterToken();
}

class NoopPushService implements PushService {
  @override
  Future<String?> obterToken() async => null;
}
