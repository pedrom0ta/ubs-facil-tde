import '../../fila/domain/fila_status.dart';
import 'entidades.dart';

abstract class AgendamentoRepository {
  Future<List<Unidade>> unidades();
  Future<List<Especialidade>> especialidades();
  Future<List<DiaDisponivel>> dias(int unidadeId, int especialidadeId);
  Future<List<Horario>> horarios(int unidadeId, int especialidadeId, DateTime dia);

  Future<List<Agendamento>> proximos();
  Future<Agendamento> agendar(int unidadeId, int especialidadeId, DateTime dataHora);
  Future<Agendamento> reagendar(int agendamentoId, DateTime dataHora);
  Future<Agendamento> cancelar(int agendamentoId);
  Future<Agendamento> confirmarPresenca(int agendamentoId);
  Future<FilaStatus> fazerCheckin(int agendamentoId);
}
