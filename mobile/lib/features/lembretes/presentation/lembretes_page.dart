import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../agendamento/presentation/agendamento_providers.dart';
import '../domain/notificacao.dart';
import 'lembretes_providers.dart';

/// Tela 06 — Lembretes: avisos de 24h/2h e da fila, com confirmação de presença (RF08).
class LembretesPage extends ConsumerWidget {
  const LembretesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificacoesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificacoesProvider.future),
        child: async.when(
          loading: () => const Carregando(),
          error: (e, _) => ErroView(erro: e, aoTentarNovamente: () => ref.invalidate(notificacoesProvider)),
          data: (lista) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (lista.isEmpty)
                const VazioView(
                  icone: Icons.notifications_none,
                  mensagem: 'Nenhum lembrete por enquanto.\nVocê será avisado 24h e 2h antes de cada consulta.',
                ),
              for (final n in lista) ...[_CartaoLembrete(n), const SizedBox(height: 10)],
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoLembrete extends ConsumerWidget {
  const _CartaoLembrete(this.n);
  final Notificacao n;

  IconData get _icone => switch (n.tipo) {
        TipoNotificacao.filaProximo || TipoNotificacao.filaChamado => Icons.campaign_outlined,
        _ => Icons.notifications_outlined,
      };

  Future<void> _confirmarPresenca(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(agendamentoAcoesProvider).confirmarPresenca(n.agendamentoId!);
      await ref.read(notificacaoRepositoryProvider).marcarLida(n.id);
      ref.invalidate(notificacoesProvider);
      if (context.mounted) mostrarMensagem(context, 'Presença confirmada. Até lá!');
    } catch (e) {
      if (context.mounted) mostrarMensagem(context, mensagemDe(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Card(
      color: n.lida ? Colors.white : AppColors.primarySoft,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: n.lida
            ? null
            : () async {
                await ref.read(notificacaoRepositoryProvider).marcarLida(n.id);
                ref.invalidate(notificacoesProvider);
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(_icone, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(n.titulo, style: t.titleMedium)),
                if (!n.lida) const StatusBadge('Novo', cor: Colors.white, fundo: AppColors.primary),
              ]),
              const SizedBox(height: 8),
              Text(n.mensagem, style: t.bodyMedium),
              if (n.pedeConfirmacao && !n.lida) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _confirmarPresenca(context, ref),
                      child: const Text('Confirmar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/agendamentos'),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
