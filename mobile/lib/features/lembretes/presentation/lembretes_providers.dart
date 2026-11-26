import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/notificacao_repository_impl.dart';
import '../domain/notificacao.dart';

final notificacaoRepositoryProvider =
    Provider<NotificacaoRepository>((ref) => NotificacaoRepositoryImpl(ref.watch(apiClientProvider)));

final notificacoesProvider =
    FutureProvider.autoDispose<List<Notificacao>>((ref) => ref.watch(notificacaoRepositoryProvider).listar());

final naoLidasProvider = Provider.autoDispose<int>(
    (ref) => ref.watch(notificacoesProvider).valueOrNull?.where((n) => !n.lida).length ?? 0);
