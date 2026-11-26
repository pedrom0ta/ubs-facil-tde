import '../../auth/domain/usuario.dart';

abstract class PerfilRepository {
  Future<Usuario> atualizar({String? nome, String? celular, bool? notificacoesAtivas});
  Future<void> excluirConta();
}
