import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Preferências locais do aparelho (não sensíveis).
class Preferencias {
  const Preferencias({required this.onboardingVisto, required this.textoMaior});

  final bool onboardingVisto;
  final bool textoMaior;

  /// Fator extra de escala de texto, somado à configuração de acessibilidade do sistema.
  double get escalaTexto => textoMaior ? 1.2 : 1.0;

  Preferencias copyWith({bool? onboardingVisto, bool? textoMaior}) => Preferencias(
        onboardingVisto: onboardingVisto ?? this.onboardingVisto,
        textoMaior: textoMaior ?? this.textoMaior,
      );
}

class PreferenciasController extends Notifier<Preferencias> {
  static const _kOnboarding = 'onboarding_visto';
  static const _kTextoMaior = 'texto_maior';

  @override
  Preferencias build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Preferencias(
      onboardingVisto: prefs.getBool(_kOnboarding) ?? false,
      textoMaior: prefs.getBool(_kTextoMaior) ?? false,
    );
  }

  Future<void> concluirOnboarding() async {
    state = state.copyWith(onboardingVisto: true);
    await ref.read(sharedPreferencesProvider).setBool(_kOnboarding, true);
  }

  Future<void> definirTextoMaior(bool valor) async {
    state = state.copyWith(textoMaior: valor);
    await ref.read(sharedPreferencesProvider).setBool(_kTextoMaior, valor);
  }
}

final preferenciasProvider =
    NotifierProvider<PreferenciasController, Preferencias>(PreferenciasController.new);
