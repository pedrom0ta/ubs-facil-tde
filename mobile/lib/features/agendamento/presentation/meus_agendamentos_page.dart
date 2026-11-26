import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/common.dart';
import '../domain/entidades.dart';
import 'agendamento_providers.dart';

/// Meus agendamentos: check-in, reagendar e cancelar (RF04, RF05, RF06).
class MeusAgendamentosPage extends ConsumerWidget {
  const MeusAgendamentosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(proximosAgendamentosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meus agendamentos')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(proximosAgendamentosProvider.future),
        child: async.when(
          loading: () => const Carregando(),
          error: (e, _) => ErroView(erro: e, aoTentarNovamente: () => ref.invalidate(proximosAgendamentosProvider)),
          data: (lista) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (lista.isEmpty)
                VazioView(
                  icone: Icons.event_available_outlined,
                  mensagem: 'Você não tem consultas agendadas.',
                  acao: FilledButton(onPressed: () => context.push('/agendar'), child: const Text('Agendar consulta')),
                ),
              for (final a in lista) ...[CartaoAgendamento(agendamento: a), const SizedBox(height: 12)],
              if (lista.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => context.push('/agendar'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova consulta'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CartaoAgendamento extends ConsumerStatefulWidget {
  const CartaoAgendamento({super.key, required this.agendamento});
  final Agendamento agendamento;

  @override
  ConsumerState<CartaoAgendamento> createState() => _CartaoAgendamentoState();
}

class _CartaoAgendamentoState extends ConsumerState<CartaoAgendamento> {
  bool _ocupado = false;

  Agendamento get a => widget.agendamento;

  Future<void> _executar(Future<void> Function() acao, String sucesso, {String? irPara}) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (!mounted) return;
      mostrarMensagem(context, sucesso);
      if (irPara != null) context.go(irPara);
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDe(e), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelar() async {
    final ok = await confirmar(
      context,
      titulo: 'Cancelar esta consulta?',
      mensagem: '${a.especialidade.nome} · ${Datas.consulta(a.dataHora)}.\n\n'
          'A vaga volta na hora para outro paciente do SUS.',
      confirmarTexto: 'Sim, cancelar',
      cancelarTexto: 'Manter consulta',
    );
    if (ok) {
      await _executar(() => ref.read(agendamentoAcoesProvider).cancelar(a), 'Consulta cancelada. A vaga foi liberada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (cor, fundo) = switch (a.status) {
      StatusAgendamento.confirmado || StatusAgendamento.checkin => (AppColors.success, AppColors.successSoft),
      _ => (AppColors.primary, AppColors.primarySoft),
    };
    final ehHoje = Datas.mesmoDia(a.dataHora, DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.especialidade.nome, style: Theme.of(context).textTheme.titleMedium),
                      Text(a.unidade.nome, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusBadge(a.status.rotulo, cor: cor, fundo: fundo),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(Datas.consulta(a.dataHora),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ]),
            if (a.status == StatusAgendamento.checkin) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: () => context.go('/fila'), child: const Text('Ver minha posição na fila')),
            ] else if (a.status.podeAlterar) ...[
              const SizedBox(height: 12),
              if (ehHoje)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: _ocupado
                        ? null
                        : () => _executar(() => ref.read(agendamentoAcoesProvider).checkin(a),
                            'Check-in feito! Você entrou na fila.', irPara: '/fila'),
                    icon: const Icon(Icons.how_to_reg_outlined),
                    label: const Text('Cheguei na UBS · fazer check-in'),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _ocupado ? null : () => context.push('/agendar', extra: a),
                    child: const Text('Reagendar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.dangerSoft, width: 1.5),
                      backgroundColor: AppColors.dangerSoft,
                    ),
                    onPressed: _ocupado ? null : _cancelar,
                    child: const Text('Cancelar'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
