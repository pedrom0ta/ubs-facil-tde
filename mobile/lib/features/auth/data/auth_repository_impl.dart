import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/push/push_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/documentos.dart';
import '../domain/usuario.dart';

Usuario usuarioFromJson(Map<String, dynamic> j) => Usuario(
      id: j['id'] as int,
      nome: j['nome'] as String,
      cpf: j['cpf'] as String,
      cns: j['cns'] as String,
      celular: j['celular'] as String?,
      notificacoesAtivas: j['notificacoes_ativas'] as bool? ?? true,
    );

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._tokens, this._push);

  final ApiClient _api;
  final TokenStorage _tokens;
  final PushService _push;

  @override
  Future<Usuario?> usuarioLogado() async {
    if (await _tokens.read() == null) return null;
    try {
      final j = await _api.get('/perfil') as Map<String, dynamic>;
      return usuarioFromJson(j);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<Usuario> entrar({required String cpf, required String senha}) async {
    final j = await _api.post('/auth/login', body: {'cpf': somenteDigitos(cpf), 'senha': senha});
    return _salvarSessao(j as Map<String, dynamic>);
  }

  @override
  Future<Usuario> cadastrar({
    required String nome,
    required String cpf,
    required String cns,
    String? celular,
    required String senha,
    required bool aceiteTermos,
  }) async {
    final j = await _api.post('/auth/cadastro', body: {
      'nome': nome.trim(),
      'cpf': somenteDigitos(cpf),
      'cns': somenteDigitos(cns),
      'celular': celular == null || celular.isEmpty ? null : somenteDigitos(celular),
      'senha': senha,
      'aceite_termos': aceiteTermos,
    });
    return _salvarSessao(j as Map<String, dynamic>);
  }

  Future<Usuario> _salvarSessao(Map<String, dynamic> j) async {
    await _tokens.save(j['access_token'] as String);
    _registrarDispositivo();
    return usuarioFromJson(j['usuario'] as Map<String, dynamic>);
  }

  /// Envia o token de push ao backend sem travar o login se falhar.
  Future<void> _registrarDispositivo() async {
    try {
      final token = await _push.obterToken();
      if (token != null) await _api.put('/perfil/fcm-token', body: {'token': token});
    } catch (_) {
      // push é opcional: falhar aqui não impede o uso do app
    }
  }

  @override
  Future<void> sair() => _tokens.clear();
}
