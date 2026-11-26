import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/settings/preferencias.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/documentos.dart';
import '../../../core/widgets/common.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/perfil_repository_impl.dart';
import '../domain/perfil_repository.dart';

final perfilRepositoryProvider =
    Provider<PerfilRepository>((ref) => PerfilRepositoryImpl(ref.watch(apiClientProvider)));

/// Tela 08 — Perfil (RF10), acessibilidade e direitos LGPD.
class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  Future<void> _atualizar(BuildContext context, WidgetRef ref,
      {String? nome, String? celular, bool? notificacoes}) async {
    try {
      final u = await ref
          .read(perfilRepositoryProvider)
          .atualizar(nome: nome, celular: celular, notificacoesAtivas: notificacoes);
      ref.read(authControllerProvider.notifier).atualizar(u);
      if (context.mounted) mostrarMensagem(context, 'Dados atualizados.');
    } catch (e) {
      if (context.mounted) mostrarMensagem(context, mensagemDe(e), erro: true);
    }
  }

  Future<void> _editarDados(BuildContext context, WidgetRef ref, Usuario u) async {
    final nome = TextEditingController(text: u.nome);
    final celular = TextEditingController(text: formatarCelular(u.celular ?? ''));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meus dados'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome completo')),
          const SizedBox(height: 12),
          TextField(
            controller: celular,
            keyboardType: TextInputType.phone,
            inputFormatters: [MascaraInputFormatter.celular()],
            decoration: const InputDecoration(labelText: 'Celular'),
          ),
          const SizedBox(height: 12),
          const Text('CPF e Cartão Nacional de Saúde não podem ser alterados pelo app.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _atualizar(context, ref, nome: nome.text.trim(), celular: celular.text);
    }
    nome.dispose();
    celular.dispose();
  }

  void _verCartao(BuildContext context, Usuario u) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cartão Nacional de Saúde'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SelectableText(formatarCns(u.cns),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Apresente este número na recepção se precisar.',
              style: TextStyle(color: AppColors.textMuted)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }

  void _ajuda(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajuda'),
        content: const Text(
          'Agendar: toque em "Agendar consulta" na tela inicial.\n\n'
          'Check-in: no dia da consulta, ao chegar na UBS, abra "Fila" e toque em "Check-in".\n\n'
          'Cancelar ou reagendar: em "Agendamentos".\n\n'
          'Dúvidas sobre sua saúde: procure a recepção da sua UBS.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
      ),
    );
  }

  Future<void> _excluirConta(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir sua conta?',
      mensagem: 'Seus agendamentos e o histórico salvos no UBS Fácil serão apagados. '
          'Esta ação não pode ser desfeita. Seu prontuário oficial no SUS não é afetado.',
      confirmarTexto: 'Excluir conta',
    );
    if (!ok) return;
    try {
      await ref.read(perfilRepositoryProvider).excluirConta();
      await ref.read(authControllerProvider.notifier).sair();
    } catch (e) {
      if (context.mounted) mostrarMensagem(context, mensagemDe(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authControllerProvider).valueOrNull;
    final prefs = ref.watch(preferenciasProvider);
    if (u == null) return const Scaffold(body: Carregando());
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(u.iniciais,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.nome, style: t.titleMedium),
                    Text('CPF: ${cpfOculto(u.cpf)}', style: t.bodySmall),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              _Item(Icons.person_outline, 'Meus dados', () => _editarDados(context, ref, u)),
              _Item(Icons.badge_outlined, 'Cartão Nacional de Saúde', () => _verCartao(context, u)),
              _Item(Icons.history, 'Histórico de atendimentos', () => context.push('/historico')),
              _Item(Icons.notifications_outlined, 'Lembretes', () => context.push('/lembretes')),
              _Item(Icons.help_outline, 'Ajuda', () => _ajuda(context), ultimo: true),
            ]),
          ),
          const SizedBox(height: 16),
          Semantics(header: true, child: Text('PREFERÊNCIAS', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.text_increase),
                title: const Text('Texto maior'),
                subtitle: const Text('Aumenta as letras em todo o app'),
                value: prefs.textoMaior,
                onChanged: (v) => ref.read(preferenciasProvider.notifier).definirTextoMaior(v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Lembretes por notificação'),
                subtitle: const Text('Avisos 24h e 2h antes da consulta'),
                value: u.notificacoesAtivas,
                onChanged: (v) => _atualizar(context, ref, notificacoes: v),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerSoft, foregroundColor: AppColors.danger),
            onPressed: () => ref.read(authControllerProvider.notifier).sair(),
            child: const Text('Sair'),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _excluirConta(context, ref),
            child: const Text('Excluir minha conta'),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icone, this.rotulo, this.aoTocar, {this.ultimo = false});
  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        minTileHeight: 56,
        leading: Icon(icone, color: const Color(0xFF3D4A5C)),
        title: Text(rotulo),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: aoTocar,
      ),
      if (!ultimo) const Divider(height: 1, indent: 56),
    ]);
  }
}
