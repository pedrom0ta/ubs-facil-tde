import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/fila_repository_impl.dart';
import '../domain/fila_status.dart';

final filaRepositoryProvider = Provider<FilaRepository>(
    (ref) => FilaRepositoryImpl(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)));

/// Situação na fila em tempo real. Fecha o WebSocket quando a tela sai de uso.
final filaProvider =
    StreamProvider.autoDispose<FilaStatus?>((ref) => ref.watch(filaRepositoryProvider).observar());
