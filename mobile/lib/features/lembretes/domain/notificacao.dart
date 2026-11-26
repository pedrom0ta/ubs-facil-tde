enum TipoNotificacao { lembrete24h, lembrete2h, filaProximo, filaChamado }

class Notificacao {
  const Notificacao({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensagem,
    required this.lida,
    this.agendamentoId,
    this.enviadaEm,
  });
  final int id;
  final TipoNotificacao tipo;
  final String titulo;
  final String mensagem;
  final bool lida;
  final int? agendamentoId;
  final DateTime? enviadaEm;

  bool get pedeConfirmacao => tipo == TipoNotificacao.lembrete24h && agendamentoId != null;
}

abstract class NotificacaoRepository {
  Future<List<Notificacao>> listar();
  Future<void> marcarLida(int id);
}
