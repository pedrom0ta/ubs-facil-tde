import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/auth_repository_impl.dart';
import '../domain/usuario.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl(
      ref.watch(apiClientProvider),
      ref.watch(tokenStorageProvider),
      ref.watch(pushServiceProvider),
    ));

/// Estado da sessão: `null` = não autenticado.
class AuthController extends AsyncNotifier<Usuario?> {
  @override
  Future<Usuario?> build() async {
    // Token expirado em qualquer chamada → volta ao login
    ref.read(apiClientProvider).onSessaoExpirada = () {
      if (state.valueOrNull != null) sair();
    };
    return ref.read(authRepositoryProvider).usuarioLogado();
  }

  Future<void> entrar(String cpf, String senha) async {
    final u = await ref.read(authRepositoryProvider).entrar(cpf: cpf, senha: senha);
    state = AsyncData(u);
  }

  Future<void> cadastrar({
    required String nome,
    required String cpf,
    required String cns,
    String? celular,
    required String senha,
    required bool aceiteTermos,
  }) async {
    final u = await ref.read(authRepositoryProvider).cadastrar(
          nome: nome,
          cpf: cpf,
          cns: cns,
          celular: celular,
          senha: senha,
          aceiteTermos: aceiteTermos,
        );
    state = AsyncData(u);
  }

  void atualizar(Usuario u) => state = AsyncData(u);

  Future<void> sair() async {
    await ref.read(authRepositoryProvider).sair();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, Usuario?>(AuthController.new);
