import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../../agendamento/domain/entidades.dart';
import '../domain/fila_status.dart';

FilaStatus filaStatusFromJson(Map<String, dynamic> j) => FilaStatus(
      agendamentoId: j['agendamento_id'] as int,
      unidade: j['unidade'] as String,
      especialidade: j['especialidade'] as String,
      status: StatusAgendamento.fromApi(j['status'] as String),
      senha: j['senha'] as String?,
      posicao: j['posicao'] as int?,
      pessoasAFrente: j['pessoas_a_frente'] as int?,
      tempoEstimadoMin: j['tempo_estimado_min'] as int?,
      consultorio: j['consultorio'] as String?,
    );

class FilaRepositoryImpl implements FilaRepository {
  FilaRepositoryImpl(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  static const _intervaloReserva = Duration(seconds: 15);

  @override
  Future<FilaStatus?> minha() async {
    try {
      final j = await _api.get('/fila/minha');
      return filaStatusFromJson(j as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 1. Busca a situação atual (HTTP).
  /// 2. Abre o WebSocket e repassa cada atualização enviada pelo servidor.
  /// 3. Se a conexão cair, consulta por HTTP a cada 15 s e tenta reconectar.
  @override
  Stream<FilaStatus?> observar() async* {
    yield await minha();
    final token = await _tokens.read();
    if (token == null) return;

    while (true) {
      WebSocketChannel? canal;
      try {
        canal = WebSocketChannel.connect(Uri.parse('${Env.wsUrl}/fila/ws?token=$token'));
        await canal.ready;
        await for (final msg in canal.stream) {
          yield filaStatusFromJson(jsonDecode(msg as String) as Map<String, dynamic>);
        }
      } catch (_) {
        // sem WebSocket: segue com polling abaixo
      } finally {
        await canal?.sink.close();
      }
      await Future<void>.delayed(_intervaloReserva);
      try {
        yield await minha();
      } on ApiException {
        // mantém o último estado exibido e tenta de novo
      }
    }
  }
}
