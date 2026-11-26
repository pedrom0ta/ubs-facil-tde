import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/datas.dart';
import '../../core/widgets/common.dart';
import '../agendamento/domain/entidades.dart';
import '../agendamento/presentation/agendamento_providers.dart';
import '../auth/presentation/auth_controller.dart';
import '../lembretes/presentation/lembretes_providers.dart';

/// Tela 03 — Início: atalhos para as principais funções.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).valueOrNull;
    final proximos = ref.watch(proximosAgendamentosProvider);
    final naoLidas = ref.watch(naoLidasProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificacoesProvider);
            await ref.refresh(proximosAgendamentosProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(usuario?.iniciais ?? '',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Olá, ${usuario?.primeiroNome ?? ''}', style: t.titleLarge),
                    Text('Como podemos te ajudar hoje?', style: t.bodySmall),
                  ]),
                ),
                IconButton(
                  tooltip: naoLidas > 0 ? 'Lembretes, $naoLidas novos' : 'Lembretes',
                  onPressed: () => context.push('/lembretes'),
                  style: IconButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(48, 48)),
                  icon: Badge(
                    isLabelVisible: naoLidas > 0,
                    label: Text('$naoLidas'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _CartaoAgendar(onTap: () => context.push('/agendar')),
              const SizedBox(height: 16),
              proximos.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const SizedBox.shrink(),
                data: (lista) => lista.isEmpty ? const SizedBox.shrink() : _ProximaConsulta(lista.first),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  _Atalho(Icons.timer_outlined, 'Fila em tempo real', 'Veja sua posição e o tempo estimado.',
                      () => context.go('/fila')),
                  _Atalho(Icons.calendar_month_outlined, 'Meus agendamentos', 'Consulte, cancele ou reagende.',
                      () => context.go('/agendamentos')),
                  _Atalho(Icons.notifications_outlined, 'Lembretes', 'Avisos antes da consulta.',
                      () => context.push('/lembretes')),
                  _Atalho(Icons.description_outlined, 'Histórico', 'Consultas, exames e vacinas.',
                      () => context.push('/historico')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoAgendar extends StatelessWidget {
  const _CartaoAgendar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Agendar consulta', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Escolha a unidade, a especialidade e o melhor horário para você.',
                    style: TextStyle(color: Color(0xFFE3ECFD))),
              ]),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward, color: AppColors.primary),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProximaConsulta extends StatelessWidget {
  const _ProximaConsulta(this.a);
  final Agendamento a;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final naFila = a.status == StatusAgendamento.checkin || a.status == StatusAgendamento.emAtendimento;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('PRÓXIMA CONSULTA', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
            StatusBadge(
              a.status.rotulo,
              cor: a.status == StatusAgendamento.agendado ? AppColors.primary : AppColors.success,
              fundo: a.status == StatusAgendamento.agendado ? AppColors.primarySoft : AppColors.successSoft,
            ),
          ]),
          const SizedBox(height: 8),
          Text(a.especialidade.nome, style: t.titleMedium),
          Text('${a.unidade.nome} · ${Datas.consulta(a.dataHora)}', style: t.bodySmall),
          const SizedBox(height: 12),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.successSoft,
              foregroundColor: AppColors.success,
              minimumSize: const Size(64, 48),
            ),
            onPressed: () => context.go(naFila ? '/fila' : '/agendamentos'),
            child: Text(naFila ? 'Ver minha posição na fila' : 'Ver detalhes e fazer check-in'),
          ),
        ]),
      ),
    );
  }
}

class _Atalho extends StatelessWidget {
  const _Atalho(this.icone, this.titulo, this.texto, this.onTap);
  final IconData icone;
  final String titulo;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconeSuave(icone),
            const SizedBox(height: 10),
            Text(titulo, style: t.titleMedium, maxLines: 2),
            const SizedBox(height: 4),
            Flexible(child: Text(texto, style: t.bodySmall, overflow: TextOverflow.fade)),
          ]),
        ),
      ),
    );
  }
}
