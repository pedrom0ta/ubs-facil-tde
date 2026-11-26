import '../../../core/network/api_client.dart';
import '../domain/registro_historico.dart';

class HistoricoRepositoryImpl implements HistoricoRepository {
  HistoricoRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<List<RegistroHistorico>> listar({TipoRegistro? tipo}) async {
    final data = await _api.get('/historico', query: tipo == null ? null : {'tipo': tipo.api});
    return (data as List).cast<Map<String, dynamic>>().map((j) => RegistroHistorico(
          id: j['id'] as int,
          tipo: TipoRegistro.fromApi(j['tipo'] as String),
          descricao: j['descricao'] as String,
          dataHora: DateTime.parse(j['data_hora'] as String),
          unidade: (j['unidade'] as Map<String, dynamic>)['nome'] as String,
        )).toList();
  }
}
