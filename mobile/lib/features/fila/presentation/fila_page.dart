import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/common.dart';
import '../../agendamento/domain/entidades.dart';
import '../../agendamento/presentation/agendamento_providers.dart';
import '../domain/fila_status.dart';
import 'fila_providers.dart';

/// Tela 05 — Fila em tempo real (RF07) e check-in digital (RF06).
class FilaPage extends ConsumerWidget {
  const FilaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fila = ref.watch(filaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Fila em tempo real')),
      body: fila.when(
        loading: () => const Carregando(),
        error: (e, _) => ErroView(erro: e, aoTentarNovamente: () => ref.invalidate(filaProvider)),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (s == null)
              const _SemCheckin()
            else if (s.foiChamado)
              _Chamado(s)
            else
              _Aguardando(s),
          ],
        ),
      ),
    );
  }
}

class _Aguardando extends StatelessWidget {
  const _Aguardando(this.s);
  final FilaStatus s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pos = s.posicao ?? 1;
    final progresso = 1 / pos;
    final tempo = s.tempoEstimadoMin ?? 0;
    final tempoTexto = tempo < 5 ? 'menos de 5 min' : '$tempo min';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.unidade, style: t.titleMedium),
                Text(s.especialidade, style: t.bodyMedium),
              ]),
            ),
            StatusBadge('Senha ${s.senha ?? '-'}', cor: AppColors.success, fundo: Colors.white),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Semantics(
              liveRegion: true,
              label: 'Você é o $posº da fila. Tempo estimado de espera: $tempoTexto.',
              child: ExcludeSemantics(
                child: Column(children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(fit: StackFit.expand, children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progresso),
                        duration: const Duration(milliseconds: 600),
                        builder: (_, v, __) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.border,
                          color: AppColors.ring,
                        ),
                      ),
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Sua posição', style: t.bodySmall),
                        Text('$posº', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, height: 1.1)),
                        Text('na fila', style: t.bodySmall),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Text('Tempo estimado de espera', style: t.bodySmall),
                  const SizedBox(height: 4),
                  Text(tempoTexto, style: t.headlineSmall),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Aviso(
          proximo: s.ehOProximo,
          texto: s.ehOProximo
              ? 'Você é o próximo! Fique perto do consultório e atento ao painel.'
              : 'Você será notificado quando estiver próximo do atendimento. Pode aguardar com tranquilidade.',
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.proximo, required this.texto});
  final bool proximo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cor = proximo ? AppColors.warning : const Color(0xFF1B4FA8);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: proximo ? AppColors.warningSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(proximo ? Icons.campaign_outlined : Icons.info_outline, color: cor),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: TextStyle(color: cor))),
      ]),
    );
  }
}

class _Chamado extends StatelessWidget {
  const _Chamado(this.s);
  final FilaStatus s;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          const Text('SUA SENHA FOI CHAMADA',
              style: TextStyle(color: Colors.white, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(s.senha ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Dirija-se ao ${s.consultorio ?? 'consultório'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${s.especialidade} · ${s.unidade}', style: const TextStyle(color: Color(0xFFD5F2E5))),
        ]),
      ),
    );
  }
}

/// Sem check-in: mostra as consultas de hoje com o botão de check-in.
class _SemCheckin extends ConsumerStatefulWidget {
  const _SemCheckin();

  @override
  ConsumerState<_SemCheckin> createState() => _SemCheckinState();
}

class _SemCheckinState extends ConsumerState<_SemCheckin> {
  bool _enviando = false;

  Future<void> _checkin(Agendamento a) async {
    setState(() => _enviando = true);
    try {
      await ref.read(agendamentoAcoesProvider).checkin(a);
      if (mounted) mostrarMensagem(context, 'Check-in feito! Você entrou na fila.');
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDe(e), erro: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hoje = ref.watch(proximosAgendamentosProvider).valueOrNull
            ?.where((a) => Datas.mesmoDia(a.dataHora, DateTime.now()) && a.status.podeAlterar)
            .toList() ??
        const <Agendamento>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: IconeSuave(Icons.place_outlined, tamanho: 48)),
            const SizedBox(height: 12),
            Text('Chegou na UBS?', style: t.titleLarge),
            const SizedBox(height: 6),
            Text(
              hoje.isEmpty
                  ? 'Você não tem consulta hoje. No dia da consulta, faça o check-in por aqui ao chegar na unidade.'
                  : 'Faça o check-in digital e entre na fila sem passar pela recepção.',
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            for (final a in hoje)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  onPressed: _enviando ? null : () => _checkin(a),
                  child: Text('Check-in · ${a.especialidade.nome} às ${Datas.hora(a.dataHora)}'),
                ),
              ),
            if (hoje.isEmpty)
              OutlinedButton(onPressed: () => context.go('/agendamentos'), child: const Text('Ver meus agendamentos')),
          ],
        ),
      ),
    );
  }
}
