import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';

/// Logo do UBS Fácil (coração com cruz).
class UbsLogo extends StatelessWidget {
  const UbsLogo({super.key, this.size = 56, this.claro = false});

  final double size;
  final bool claro;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'UBS Fácil',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.favorite, size: size, color: claro ? const Color(0xFF4C8DF6) : AppColors.primary),
                Icon(Icons.add, size: size * 0.45, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'UBS ', style: TextStyle(color: claro ? Colors.white : AppColors.text)),
              TextSpan(text: 'Fácil', style: TextStyle(color: claro ? const Color(0xFF6EA4FA) : AppColors.primary)),
            ]),
            style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Selo de status (ex.: "Agendado", "Realizado").
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.texto, {super.key, required this.cor, required this.fundo});

  final String texto;
  final Color cor;
  final Color fundo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(99)),
      child: Text(texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Ícone dentro de um quadrado azul-claro.
class IconeSuave extends StatelessWidget {
  const IconeSuave(this.icone, {super.key, this.tamanho = 40});

  final IconData icone;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
        child: Icon(icone, color: AppColors.primary, size: tamanho * 0.55),
      ),
    );
  }
}

class Carregando extends StatelessWidget {
  const Carregando({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class ErroView extends StatelessWidget {
  const ErroView({super.key, required this.erro, this.aoTentarNovamente});

  final Object erro;
  final VoidCallback? aoTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final msg = erro is ApiException ? (erro as ApiException).message : 'Não foi possível carregar.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (aoTentarNovamente != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: aoTentarNovamente, child: const Text('Tentar novamente')),
            ],
          ],
        ),
      ),
    );
  }
}

class VazioView extends StatelessWidget {
  const VazioView({super.key, required this.icone, required this.mensagem, this.acao});

  final IconData icone;
  final String mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icone, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (acao != null) ...[const SizedBox(height: 16), acao!],
          ],
        ),
      ),
    );
  }
}

void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: erro ? AppColors.danger : AppColors.text,
    ));
}

String mensagemDe(Object e) => e is ApiException ? e.message : 'Algo deu errado. Tente novamente.';

/// Confirmação dupla para ações destrutivas (heurística "prevenção de erros").
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String confirmarTexto,
  String cancelarTexto = 'Voltar',
  bool destrutivo = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelarTexto)),
        FilledButton(
          style: destrutivo ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmarTexto),
        ),
      ],
    ),
  );
  return ok ?? false;
}
