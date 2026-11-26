import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/documentos.dart';
import '../../../core/widgets/common.dart';
import 'auth_controller.dart';

/// Tela 02 — Primeiro acesso (cadastro com CPF e CNS + consentimento LGPD).
class CadastroPage extends ConsumerStatefulWidget {
  const CadastroPage({super.key});

  @override
  ConsumerState<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends ConsumerState<CadastroPage> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _cpf = TextEditingController();
  final _cns = TextEditingController();
  final _celular = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _aceite = false;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    for (final c in [_nome, _cpf, _cns, _celular, _senha, _confirmacao]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cadastrar() async {
    final valido = _form.currentState!.validate();
    if (!_aceite) {
      setState(() => _erro = 'Para continuar, aceite os Termos de Uso e a Política de Privacidade.');
      return;
    }
    if (!valido) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).cadastrar(
            nome: _nome.text,
            cpf: _cpf.text,
            cns: _cns.text,
            celular: _celular.text,
            senha: _senha.text,
            aceiteTermos: _aceite,
          );
    } catch (e) {
      setState(() => _erro = mensagemDe(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _verTermos() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Termos de Uso e Privacidade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              Text(
                'O UBS Fácil usa seu nome, CPF, Cartão Nacional de Saúde e celular apenas para '
                'agendar consultas, organizar a fila de atendimento e enviar lembretes.\n\n'
                'Seus dados de saúde são protegidos com criptografia e só você tem acesso ao seu histórico. '
                'Não vendemos nem compartilhamos seus dados com terceiros.\n\n'
                'Conforme a Lei Geral de Proteção de Dados (Lei 13.709/2018), você pode, a qualquer momento, '
                'consultar, corrigir, exportar ou excluir seus dados pela tela Perfil.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Primeiro acesso')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Crie sua conta com CPF e Cartão Nacional de Saúde (CNS).', style: t.bodySmall),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nome,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Digite seu nome completo.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cpf,
                  decoration: const InputDecoration(labelText: 'CPF', hintText: '000.000.000-00'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [MascaraInputFormatter.cpf()],
                  textInputAction: TextInputAction.next,
                  validator: (v) => cpfValido(v ?? '') ? null : 'CPF inválido. Confira os números.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cns,
                  decoration: const InputDecoration(
                    labelText: 'Cartão Nacional de Saúde (CNS)',
                    hintText: '000 0000 0000 0000',
                    helperText: 'Os 15 números do seu Cartão do SUS.',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [MascaraInputFormatter.cns()],
                  textInputAction: TextInputAction.next,
                  validator: (v) => cnsValido(v ?? '') ? null : 'Número do cartão inválido.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _celular,
                  decoration: const InputDecoration(labelText: 'Celular (opcional)', hintText: '(00) 00000-0000'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [MascaraInputFormatter.celular()],
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final d = somenteDigitos(v ?? '');
                    return d.isEmpty || d.length >= 10 ? null : 'Celular incompleto.';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senha,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Crie uma senha', helperText: 'Mínimo de 8 caracteres.'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').length < 8 ? 'A senha precisa ter pelo menos 8 caracteres.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmacao,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Repita a senha'),
                  validator: (v) => v != _senha.text ? 'As senhas não são iguais.' : null,
                ),
                const SizedBox(height: 16),
                MergeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Checkbox(
                          value: _aceite,
                          onChanged: (v) => setState(() {
                            _aceite = v ?? false;
                            _erro = null;
                          }),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            children: [
                              const Text('Li e aceito os '),
                              InkWell(
                                onTap: _verTermos,
                                child: const Text(
                                  'Termos de Uso e a Política de Privacidade',
                                  style: TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
                                ),
                              ),
                              const Text(' (LGPD).'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                      child: Text(_erro!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _enviando ? null : _cadastrar,
                  child: _enviando
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Criar conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
