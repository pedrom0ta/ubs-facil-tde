import '../../../core/network/api_client.dart';
import '../../../core/utils/documentos.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../auth/domain/usuario.dart';
import '../domain/perfil_repository.dart';

class PerfilRepositoryImpl implements PerfilRepository {
  PerfilRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Usuario> atualizar({String? nome, String? celular, bool? notificacoesAtivas}) async {
    final j = await _api.patch('/perfil', body: {
      if (nome != null) 'nome': nome,
      if (celular != null) 'celular': somenteDigitos(celular),
      if (notificacoesAtivas != null) 'notificacoes_ativas': notificacoesAtivas,
    });
    return usuarioFromJson(j as Map<String, dynamic>);
  }

  @override
  Future<void> excluirConta() => _api.delete('/perfil');
}
