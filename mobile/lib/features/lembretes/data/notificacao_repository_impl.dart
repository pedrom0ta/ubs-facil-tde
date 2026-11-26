import '../../../core/network/api_client.dart';
import '../domain/notificacao.dart';

class NotificacaoRepositoryImpl implements NotificacaoRepository {
  NotificacaoRepositoryImpl(this._api);
  final ApiClient _api;

  static TipoNotificacao _tipo(String v) => switch (v) {
        'LEMBRETE_24H' => TipoNotificacao.lembrete24h,
        'LEMBRETE_2H' => TipoNotificacao.lembrete2h,
        'FILA_PROXIMO' => TipoNotificacao.filaProximo,
        _ => TipoNotificacao.filaChamado,
      };

  @override
  Future<List<Notificacao>> listar() async {
    final data = await _api.get('/notificacoes');
    return (data as List).cast<Map<String, dynamic>>().map((j) => Notificacao(
          id: j['id'] as int,
          tipo: _tipo(j['tipo'] as String),
          titulo: j['titulo'] as String,
          mensagem: j['mensagem'] as String,
          lida: j['lida'] as bool,
          agendamentoId: j['agendamento_id'] as int?,
          enviadaEm: j['enviada_em'] == null ? null : DateTime.parse(j['enviada_em'] as String),
        )).toList();
  }

  @override
  Future<void> marcarLida(int id) => _api.post('/notificacoes/$id/lida');
}
