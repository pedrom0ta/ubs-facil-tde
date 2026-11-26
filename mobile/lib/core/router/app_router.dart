import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agendamento/domain/entidades.dart';
import '../../features/agendamento/presentation/agendamento_sucesso_page.dart';
import '../../features/agendamento/presentation/agendar_page.dart';
import '../../features/agendamento/presentation/meus_agendamentos_page.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/cadastro_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/fila/presentation/fila_page.dart';
import '../../features/historico/presentation/historico_page.dart';
import '../../features/home/home_page.dart';
import '../../features/lembretes/presentation/lembretes_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/perfil/presentation/perfil_page.dart';
import '../settings/preferencias.dart';
import '../widgets/common.dart';

const _rotasPublicas = {'/onboarding', '/login', '/cadastro'};

final routerProvider = Provider<GoRouter>((ref) {
  // Reavalia os redirecionamentos quando a sessão muda (login, logout, token expirado)
  final atualizar = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => atualizar.value++);
  ref.onDispose(atualizar.dispose);

  return GoRouter(
    initialLocation: '/inicio',
    refreshListenable: atualizar,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final local = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) return local == '/carregando' ? null : '/carregando';

      final logado = auth.valueOrNull != null;
      if (!logado) {
        if (_rotasPublicas.contains(local)) return null;
        return ref.read(preferenciasProvider).onboardingVisto ? '/login' : '/onboarding';
      }
      if (_rotasPublicas.contains(local) || local == '/carregando') return '/inicio';
      return null;
    },
    routes: [
      GoRoute(path: '/carregando', builder: (_, __) => const Scaffold(body: Carregando())),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/cadastro', builder: (_, __) => const CadastroPage()),
      GoRoute(
        path: '/agendar',
        builder: (_, state) => AgendarPage(reagendar: state.extra as Agendamento?),
        routes: [
          GoRoute(
            path: 'sucesso',
            builder: (_, state) {
              final (ag, reagendado) = state.extra! as (Agendamento, bool);
              return AgendamentoSucessoPage(agendamento: ag, reagendado: reagendado);
            },
          ),
        ],
      ),
      GoRoute(path: '/historico', builder: (_, __) => const HistoricoPage()),
      GoRoute(path: '/lembretes', builder: (_, __) => const LembretesPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => _ShellComMenu(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/inicio', builder: (_, __) => const HomePage())]),
          StatefulShellBranch(
              routes: [GoRoute(path: '/agendamentos', builder: (_, __) => const MeusAgendamentosPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/fila', builder: (_, __) => const FilaPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/perfil', builder: (_, __) => const PerfilPage())]),
        ],
      ),
    ],
  );
});

/// Menu inferior: Início, Agendamentos, Fila, Perfil.
class _ShellComMenu extends StatelessWidget {
  const _ShellComMenu({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Agendamentos'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: 'Fila'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
