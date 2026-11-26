import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/common.dart';
import '../domain/registro_historico.dart';
import 'historico_providers.dart';

/// Tela 07 — Histórico de atendimentos (RF09).
class HistoricoPage extends ConsumerStatefulWidget {
  const HistoricoPage({super.key});

  @override
  ConsumerState<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends ConsumerState<HistoricoPage> {
  TipoRegistro? _filtro;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(historicoProvider(_filtro));
    final opcoes = <(String, TipoRegistro?)>[('Todos', null), for (final t in TipoRegistro.values) (t.rotulo, t)];

    return Scaffold(
      appBar: AppBar(title: const Text('Meus atendimentos')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                for (final (rotulo, tipo) in opcoes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(rotulo),
                      selected: _filtro == tipo,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _filtro == tipo ? Colors.white : AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _filtro = tipo),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Carregando(),
              error: (e, _) => ErroView(erro: e, aoTentarNovamente: () => ref.invalidate(historicoProvider(_filtro))),
              data: (lista) => lista.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: VazioView(icone: Icons.history, mensagem: 'Nenhum registro nesta categoria.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ItemHistorico(lista[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemHistorico extends StatelessWidget {
  const _ItemHistorico(this.r);
  final RegistroHistorico r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconeSuave(_icone(r.tipo)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.descricao, style: t.titleMedium),
                  Text(r.unidade, style: t.bodySmall),
                  Text('${Datas.completa(r.dataHora)} · ${Datas.hora(r.dataHora)}', style: t.bodySmall),
                ],
              ),
            ),
            const StatusBadge('Realizado', cor: AppColors.success, fundo: AppColors.successSoft),
          ],
        ),
      ),
    );
  }
}

IconData _icone(TipoRegistro t) => switch (t) {
      TipoRegistro.consulta => Icons.medical_services_outlined,
      TipoRegistro.exame => Icons.science_outlined,
      TipoRegistro.vacina => Icons.vaccines_outlined,
    };
