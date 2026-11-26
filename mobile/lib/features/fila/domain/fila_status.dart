import '../../agendamento/domain/entidades.dart';

/// Situação do paciente na fila da unidade.
class FilaStatus {
  const FilaStatus({
    required this.agendamentoId,
    required this.unidade,
    required this.especialidade,
    required this.status,
    this.senha,
    this.posicao,
    this.pessoasAFrente,
    this.tempoEstimadoMin,
    this.consultorio,
  });

  final int agendamentoId;
  final String unidade;
  final String especialidade;
  final StatusAgendamento status;
  final String? senha;
  final int? posicao;
  final int? pessoasAFrente;
  final int? tempoEstimadoMin;
  final String? consultorio;

  bool get foiChamado => status == StatusAgendamento.emAtendimento;
  bool get ehOProximo => posicao == 1;
}

abstract class FilaRepository {
  /// Situação atual (null = não está em nenhuma fila).
  Future<FilaStatus?> minha();

  /// Atualizações em tempo real (WebSocket, com polling como reserva).
  Stream<FilaStatus?> observar();
}
