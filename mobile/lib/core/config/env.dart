/// Endereço da API. Defina na execução:
///   flutter run --dart-define=API_URL=http://192.168.0.10:8000
/// Padrão: 10.0.2.2 é o "localhost" do computador visto pelo emulador Android.
class Env {
  const Env._();

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static String get wsUrl => apiUrl.replaceFirst(RegExp(r'^http'), 'ws');
}
