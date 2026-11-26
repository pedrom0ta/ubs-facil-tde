import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/common.dart';
import '../domain/entidades.dart';
import 'agendamento_providers.dart';

/// Tela 04 — Agendamento (e reagendamento) de consulta.
/// Fluxo: unidade → especialidade → data → horário → confirmação.
class AgendarPage extends ConsumerStatefulWidget {
  const AgendarPage({super.key, this.reagendar});

  /// Quando informado, a tela reagenda esta consulta (unidade e especialidade ficam fixas).
  final Agendamento? reagendar;

  @override
  ConsumerState<AgendarPage> createState() => _AgendarPageState();
}

class _AgendarPageState extends ConsumerState<AgendarPage> {
  Unidade? _unidade;
  Especialidade? _especialidade;
  DateTime? _dia;
  Horario? _horario;
  bool _enviando = false;

  bool get _reagendando => widget.reagendar != null;

  @override
  void initState() {
    super.initState();
    if (_reagendando) {
      _unidade = widget.reagendar!.unidade;
      _especialidade = widget.reagendar!.especialidade;
    }
  }

  Future<void> _confirmar() async {
    final horario = _horario!;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ResumoSheet(
        unidade: _unidade!.nome,
        especialidade: _especialidade!.nome,
        dataHora: horario.dataHora,
        reagendando: _reagendando,
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _enviando = true);
    final acoes = ref.read(agendamentoAcoesProvider);
    try {
      final ag = _reagendando
          ? await acoes.reagendar(widget.reagendar!, horario.dataHora)
          : await acoes.agendar(_unidade!, _especialidade!, horario.dataHora);
      if (!mounted) return;
      context.pushReplacement('/agendar/sucesso', extra: (ag, _reagendando));
    } catch (e) {
      if (!mounted) return;
      mostrarMensagem(context, mensagemDe(e), erro: true);
      // O horário pode ter sido ocupado por outra pessoa: recarrega a grade
      ref.invalidate(horariosProvider);
      setState(() => _horario = null);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pronto = _horario != null && !_enviando;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_reagendando ? 'Reagendar consulta' : 'Agendar consulta'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (_reagendando)
            Card(
              child: ListTile(
                leading: const IconeSuave(Icons.event_repeat_outlined),
                title: Text(_especialidade!.nome),
                subtitle: Text('${_unidade!.nome}\nAtual: ${Datas.consulta(widget.reagendar!.dataHora)}'),
                isThreeLine: true,
              ),
            )
          else ...[
            const _Rotulo('1. Unidade de saúde'),
            _SeletorUnidade(
              valor: _unidade,
              aoMudar: (u) => setState(() {
                _unidade = u;
                _dia = null;
                _horario = null;
              }),
            ),
            const SizedBox(height: 20),
            const _Rotulo('2. Especialidade'),
            _SeletorEspecialidade(
              valor: _especialidade,
              aoMudar: (e) => setState(() {
                _especialidade = e;
                _dia = null;
                _horario = null;
              }),
            ),
          ],
          if (_unidade != null && _especialidade != null) ...[
            const SizedBox(height: 20),
            _Rotulo(_reagendando ? 'Nova data' : '3. Data disponível'),
            _SeletorDia(
              chave: (_unidade!.id, _especialidade!.id),
              selecionado: _dia,
              aoEscolher: (d) => setState(() {
                _dia = d;
                _horario = null;
              }),
            ),
          ],
          if (_dia != null) ...[
            const SizedBox(height: 20),
            _Rotulo(_reagendando ? 'Novo horário' : '4. Horários disponíveis'),
            _GradeHorarios(
              chave: (_unidade!.id, _especialidade!.id, _dia!),
              selecionado: _horario,
              aoEscolher: (h) => setState(() => _horario = h),
            ),
            const SizedBox(height: 8),
            Text('Horários riscados já estão ocupados ou já passaram.', style: t.bodySmall),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: FilledButton(
            onPressed: pronto ? _confirmar : null,
            child: _enviando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(_horario == null ? 'Escolha um horário' : 'Continuar'),
          ),
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(header: true, child: Text(texto, style: Theme.of(context).textTheme.titleMedium)),
      );
}

class _SeletorUnidade extends ConsumerWidget {
  const _SeletorUnidade({required this.valor, required this.aoMudar});
  final Unidade? valor;
  final ValueChanged<Unidade?> aoMudar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(unidadesProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ErroView(erro: e, aoTentarNovamente: () => ref.invalidate(unidadesProvider)),
          data: (lista) => DropdownButtonFormField<Unidade>(
            value: valor,
            isExpanded: true,
            hint: const Text('Selecione a unidade'),
            items: [
              for (final u in lista)
                DropdownMenuItem(value: u, child: Text(u.nome, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: aoMudar,
          ),
        );
  }
}

class _SeletorEspecialidade extends ConsumerWidget {
  const _SeletorEspecialidade({required this.valor, required this.aoMudar});
  final Especialidade? valor;
  final ValueChanged<Especialidade?> aoMudar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(especialidadesProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ErroView(erro: e, aoTentarNovamente: () => ref.invalidate(especialidadesProvider)),
          data: (lista) => DropdownButtonFormField<Especialidade>(
            value: valor,
            isExpanded: true,
            hint: const Text('Selecione a especialidade'),
            items: [for (final e in lista) DropdownMenuItem(value: e, child: Text(e.nome))],
            onChanged: aoMudar,
          ),
        );
  }
}

class _SeletorDia extends ConsumerWidget {
  const _SeletorDia({required this.chave, required this.selecionado, required this.aoEscolher});
  final (int, int) chave;
  final DateTime? selecionado;
  final ValueChanged<DateTime> aoEscolher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(diasProvider(chave)).when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ErroView(erro: e, aoTentarNovamente: () => ref.invalidate(diasProvider(chave))),
          data: (dias) {
            if (dias.isEmpty) {
              return const Text('Não há vagas nos próximos dias para esta especialidade. Tente outra unidade.');
            }
            return SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = dias[i].data;
                  final sel = selecionado != null && Datas.mesmoDia(d, selecionado!);
                  return Semantics(
                    selected: sel,
                    button: true,
                    label: '${Datas.completa(d)}, ${dias[i].vagas} vagas',
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: () => aoEscolher(d),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 64,
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? AppColors.primary : AppColors.inputBorder, width: 1.5),
                          ),
                          child: DefaultTextStyle(
                            style: TextStyle(color: sel ? Colors.white : AppColors.text),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(Datas.diaSemanaCurto(d), style: const TextStyle(fontSize: 12)),
                                Text('${d.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                Text(Datas.mesCurto(d), style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
  }
}

class _GradeHorarios extends ConsumerWidget {
  const _GradeHorarios({required this.chave, required this.selecionado, required this.aoEscolher});
  final (int, int, DateTime) chave;
  final Horario? selecionado;
  final ValueChanged<Horario> aoEscolher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(horariosProvider(chave)).when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ErroView(erro: e, aoTentarNovamente: () => ref.invalidate(horariosProvider(chave))),
          data: (horarios) => GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              for (final h in horarios)
                _BotaoHorario(
                  horario: h,
                  selecionado: selecionado?.dataHora == h.dataHora,
                  aoEscolher: () => aoEscolher(h),
                ),
            ],
          ),
        );
  }
}

class _BotaoHorario extends StatelessWidget {
  const _BotaoHorario({required this.horario, required this.selecionado, required this.aoEscolher});
  final Horario horario;
  final bool selecionado;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    final livre = horario.disponivel;
    final fundo = selecionado ? AppColors.primary : (livre ? Colors.white : const Color(0xFFF1F3F6));
    final cor = selecionado ? Colors.white : (livre ? AppColors.text : const Color(0xFF6B7587));
    return Semantics(
      button: true,
      enabled: livre,
      selected: selecionado,
      label: '${horario.hora}${livre ? '' : ', indisponível'}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: livre ? aoEscolher : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fundo,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selecionado ? AppColors.primary : (livre ? AppColors.inputBorder : fundo),
                width: 1.5,
              ),
            ),
            child: Text(
              horario.hora,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                decoration: livre ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResumoSheet extends StatelessWidget {
  const _ResumoSheet({
    required this.unidade,
    required this.especialidade,
    required this.dataHora,
    required this.reagendando,
  });

  final String unidade;
  final String especialidade;
  final DateTime dataHora;
  final bool reagendando;

  @override
  Widget build(BuildContext context) {
    Widget linha(String rotulo, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(rotulo, style: const TextStyle(color: AppColors.textMuted))),
              Expanded(
                flex: 2,
                child: Text(valor, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Confira os dados', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                linha('Unidade', unidade),
                linha('Especialidade', especialidade),
                linha('Data', Datas.completa(dataHora)),
                linha('Horário', Datas.hora(dataHora)),
              ]),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(reagendando ? 'Confirmar novo horário' : 'Confirmar agendamento'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar e alterar')),
          ],
        ),
      ),
    );
  }
}
