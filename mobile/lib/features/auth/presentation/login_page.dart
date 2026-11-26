import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/documentos.dart';
import '../../../core/widgets/common.dart';
import 'auth_controller.dart';

/// Tela 02 — Login (CPF + senha).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _cpf = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultar = true;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _cpf.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).entrar(_cpf.text, _senha.text);
    } catch (e) {
      setState(() => _erro = mensagemDe(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: UbsLogo(size: 56)),
                  const SizedBox(height: 32),
                  Text('Entrar na sua conta', style: t.titleLarge),
                  const SizedBox(height: 4),
                  Text('Use seu CPF e a senha cadastrada.', style: t.bodySmall),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _cpf,
                    decoration: const InputDecoration(labelText: 'CPF', hintText: '000.000.000-00'),
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.username],
                    inputFormatters: [MascaraInputFormatter.cpf()],
                    textInputAction: TextInputAction.next,
                    validator: (v) => cpfValido(v ?? '') ? null : 'Digite um CPF válido.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senha,
                    obscureText: _ocultar,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      suffixIcon: IconButton(
                        tooltip: _ocultar ? 'Mostrar senha' : 'Ocultar senha',
                        icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _ocultar = !_ocultar),
                      ),
                    ),
                    onFieldSubmitted: (_) => _entrar(),
                    validator: (v) => (v ?? '').isEmpty ? 'Digite sua senha.' : null,
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_erro!, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _enviando ? null : _entrar,
                    child: _enviando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 16),
                  const _Divisor(),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.push('/cadastro'),
                    child: const Text('Primeiro acesso'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divisor extends StatelessWidget {
  const _Divisor();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Row(children: [
        Expanded(child: Divider()),
        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('ou')),
        Expanded(child: Divider()),
      ]),
    );
  }
}

