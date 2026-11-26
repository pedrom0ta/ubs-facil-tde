import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/datas.dart';
import '../domain/entidades.dart';

class AgendamentoSucessoPage extends StatelessWidget {
  const AgendamentoSucessoPage({super.key, required this.agendamento, required this.reagendado});

  final Agendamento agendamento;
  final bool reagendado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 52, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(reagendado ? 'Consulta reagendada!' : 'Consulta agendada!',
                    textAlign: TextAlign.center, style: t.headlineSmall),
              ),
              const SizedBox(height: 8),
              Text('${agendamento.especialidade.nome} · ${agendamento.unidade.nome}',
                  textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Text(
                '${Datas.completa(agendamento.dataHora)} às ${Datas.hora(agendamento.dataHora)}',
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(color: AppColors.primary, fontSize: 18),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notifications_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Você receberá lembretes 24 horas e 2 horas antes da consulta. '
                        'No dia, faça o check-in pelo app ao chegar na unidade.',
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              FilledButton(onPressed: () => context.go('/agendamentos'), child: const Text('Ver meus agendamentos')),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.go('/inicio'), child: const Text('Voltar ao início')),
            ],
          ),
        ),
      ),
    );
  }
}
