import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/preferencias.dart';
import '../../core/widgets/common.dart';

/// Tela 01 — Onboarding: apresenta o app em três passos.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _Passo {
  const _Passo(this.icone, this.titulo, this.texto);
  final IconData icone;
  final String titulo;
  final String texto;
}

const _passos = [
  _Passo(Icons.local_hospital_outlined, 'Bem-vindo ao UBS Fácil',
      'Agende sua consulta, acompanhe a fila de atendimento e receba lembretes, tudo pelo seu celular.'),
  _Passo(Icons.timer_outlined, 'Acompanhe a fila de onde estiver',
      'Faça o check-in ao chegar e veja sua posição e o tempo estimado em tempo real.'),
  _Passo(Icons.notifications_active_outlined, 'Nunca mais esqueça uma consulta',
      'Você recebe um lembrete 24 horas e 2 horas antes, e confirma a presença com um toque.'),
];

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pagina = PageController();
  int _atual = 0;

  @override
  void dispose() {
    _pagina.dispose();
    super.dispose();
  }

  Future<void> _concluir() async {
    await ref.read(preferenciasProvider.notifier).concluirOnboarding();
    if (mounted) context.go('/login');
  }

  void _proximo() {
    if (_atual < _passos.length - 1) {
      _pagina.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _concluir();
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B1726);
    return Scaffold(
      backgroundColor: navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerLeft, child: UbsLogo(size: 32, claro: true)),
              Expanded(
                child: PageView.builder(
                  controller: _pagina,
                  itemCount: _passos.length,
                  onPageChanged: (i) => setState(() => _atual = i),
                  itemBuilder: (_, i) {
                    final p = _passos[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: const BoxDecoration(color: Color(0xFF16263D), shape: BoxShape.circle),
                            child: Icon(p.icone, size: 96, color: const Color(0xFF6EA4FA)),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(p.titulo,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2)),
                        const SizedBox(height: 12),
                        Text(p.texto, style: const TextStyle(color: Color(0xFFB4C3D9), fontSize: 16, height: 1.45)),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
              Semantics(
                label: 'Passo ${_atual + 1} de ${_passos.length}',
                child: Row(
                  children: List.generate(_passos.length, (i) {
                    final ativo = i == _atual;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      width: ativo ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ativo ? const Color(0xFF6EA4FA) : const Color(0xFF2C4466),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _proximo,
                child: Text(_atual < _passos.length - 1 ? 'Próximo' : 'Começar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _concluir,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFB4C3D9)),
                child: const Text('Já tenho conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
