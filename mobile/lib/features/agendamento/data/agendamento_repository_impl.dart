import '../../../core/network/api_client.dart';
import '../../../core/utils/datas.dart';
import '../../fila/data/fila_repository_impl.dart';
import '../../fila/domain/fila_status.dart';
import '../domain/agendamento_repository.dart';
import '../domain/entidades.dart';

Unidade unidadeFromJson(Map<String, dynamic> j) =>
    Unidade(id: j['id'] as int, nome: j['nome'] as String, endereco: j['endereco'] as String? ?? '');

Especialidade especialidadeFromJson(Map<String, dynamic> j) =>
    Especialidade(id: j['id'] as int, nome: j['nome'] as String);

Agendamento agendamentoFromJson(Map<String, dynamic> j) => Agendamento(
      id: j['id'] as int,
      dataHora: DateTime.parse(j['data_hora'] as String),
      status: StatusAgendamento.fromApi(j['status'] as String),
      unidade: unidadeFromJson(j['unidade'] as Map<String, dynamic>),
      especialidade: especialidadeFromJson(j['especialidade'] as Map<String, dynamic>),
      senha: j['senha'] as String?,
      consultorio: j['consultorio'] as String?,
    );

List<Map<String, dynamic>> _lista(dynamic data) => (data as List).cast<Map<String, dynamic>>();

class AgendamentoRepositoryImpl implements AgendamentoRepository {
  AgendamentoRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<Unidade>> unidades() async => _lista(await _api.get('/unidades')).map(unidadeFromJson).toList();

  @override
  Future<List<Especialidade>> especialidades() async =>
      _lista(await _api.get('/especialidades')).map(especialidadeFromJson).toList();

  @override
  Future<List<DiaDisponivel>> dias(int unidadeId, int especialidadeId) async {
    final data = await _api.get('/unidades/$unidadeId/dias', query: {'especialidade_id': especialidadeId});
    return _lista(data)
        .map((j) => DiaDisponivel(data: DateTime.parse(j['data'] as String), vagas: j['vagas'] as int))
        .toList();
  }

  @override
  Future<List<Horario>> horarios(int unidadeId, int especialidadeId, DateTime dia) async {
    final data = await _api.get('/unidades/$unidadeId/horarios',
        query: {'especialidade_id': especialidadeId, 'data': Datas.dataApi(dia)});
    return _lista(data)
        .map((j) => Horario(
              dataHora: DateTime.parse(j['data_hora'] as String),
              hora: j['hora'] as String,
              disponivel: j['disponivel'] as bool,
            ))
        .toList();
  }

  @override
  Future<List<Agendamento>> proximos() async =>
      _lista(await _api.get('/agendamentos', query: {'ativos': true})).map(agendamentoFromJson).toList();

  @override
  Future<Agendamento> agendar(int unidadeId, int especialidadeId, DateTime dataHora) async {
    final j = await _api.post('/agendamentos', body: {
      'unidade_id': unidadeId,
      'especialidade_id': especialidadeId,
      'data_hora': Datas.paraApi(dataHora),
    });
    return agendamentoFromJson(j as Map<String, dynamic>);
  }

  @override
  Future<Agendamento> reagendar(int agendamentoId, DateTime dataHora) async {
    final j = await _api.patch('/agendamentos/$agendamentoId', body: {'data_hora': Datas.paraApi(dataHora)});
    return agendamentoFromJson(j as Map<String, dynamic>);
  }

  @override
  Future<Agendamento> cancelar(int agendamentoId) async =>
      agendamentoFromJson(await _api.post('/agendamentos/$agendamentoId/cancelar') as Map<String, dynamic>);

  @override
  Future<Agendamento> confirmarPresenca(int agendamentoId) async =>
      agendamentoFromJson(await _api.post('/agendamentos/$agendamentoId/confirmar') as Map<String, dynamic>);

  @override
  Future<FilaStatus> fazerCheckin(int agendamentoId) async =>
      filaStatusFromJson(await _api.post('/agendamentos/$agendamentoId/checkin') as Map<String, dynamic>);
}
