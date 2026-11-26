import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/historico_repository_impl.dart';
import '../domain/registro_historico.dart';

final historicoRepositoryProvider =
    Provider<HistoricoRepository>(
        (ref) => HistoricoRepositoryImpl(ref.watch(apiClientProvider)));

final historicoProvider = FutureProvider.autoDispose.family<List<RegistroHistorico>, TipoRegistro?>(
    (ref, tipo) => ref.watch(historicoRepositoryProvider).listar(tipo: tipo));
