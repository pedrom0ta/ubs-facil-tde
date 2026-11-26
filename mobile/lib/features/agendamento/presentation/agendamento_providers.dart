import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../fila/presentation/fila_providers.dart';
import '../data/agendamento_repository_impl.dart';
import '../domain/agendamento_repository.dart';
import '../domain/entidades.dart';

final agendamentoRepositoryProvider =
    Provider<AgendamentoRepository>((ref) => AgendamentoRepositoryImpl(ref.watch(apiClientProvider)));

final unidadesProvider =
    FutureProvider.autoDispose<List<Unidade>>((ref) => ref.watch(agendamentoRepositoryProvider).unidades());

final especialidadesProvider = FutureProvider.autoDispose<List<Especialidade>>(
    (ref) => ref.watch(agendamentoRepositoryProvider).especialidades());

final diasProvider = FutureProvider.autoDispose.family<List<DiaDisponivel>, (int, int)>(
    (ref, k) => ref.watch(agendamentoRepositoryProvider).dias(k.$1, k.$2));

final horariosProvider = FutureProvider.autoDispose.family<List<Horario>, (int, int, DateTime)>(
    (ref, k) => ref.watch(agendamentoRepositoryProvider).horarios(k.$1, k.$2, k.$3));

/// Próximas consultas do paciente (base das telas Início, Agendamentos e Fila).
final proximosAgendamentosProvider = FutureProvider<List<Agendamento>>(
    (ref) => ref.watch(agendamentoRepositoryProvider).proximos());

/// Ações que alteram agendamentos e atualizam as telas que dependem deles.
class AgendamentoAcoes {
  AgendamentoAcoes(this._ref);
  final Ref _ref;

  AgendamentoRepository get _repo => _ref.read(agendamentoRepositoryProvider);

  void _atualizar() {
    _ref.invalidate(proximosAgendamentosProvider);
    _ref.invalidate(filaProvider);
  }

  Future<Agendamento> agendar(Unidade u, Especialidade e, DateTime dataHora) async {
    final a = await _repo.agendar(u.id, e.id, dataHora);
    _atualizar();
    return a;
  }

  Future<Agendamento> reagendar(Agendamento a, DateTime dataHora) async {
    final r = await _repo.reagendar(a.id, dataHora);
    _atualizar();
    return r;
  }

  Future<void> cancelar(Agendamento a) async {
    await _repo.cancelar(a.id);
    _atualizar();
  }

  Future<void> confirmarPresenca(int agendamentoId) async {
    await _repo.confirmarPresenca(agendamentoId);
    _atualizar();
  }

  Future<void> checkin(Agendamento a) async {
    await _repo.fazerCheckin(a.id);
    _atualizar();
  }
}

final agendamentoAcoesProvider = Provider<AgendamentoAcoes>(AgendamentoAcoes.new);
