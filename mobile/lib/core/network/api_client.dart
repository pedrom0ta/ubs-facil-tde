import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Cliente HTTP único do app: injeta o token, aplica timeouts e traduz erros.
class ApiClient {
  ApiClient(this._tokens, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Env.apiUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401 && onSessaoExpirada != null) {
          onSessaoExpirada!();
        }
        handler.next(error);
      },
    ));
  }

  final Dio _dio;
  final TokenStorage _tokens;

  /// Chamado quando a API responde 401 (token expirado): o app volta ao login.
  void Function()? onSessaoExpirada;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _call(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) => _call(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, {Object? body}) => _call(() => _dio.put(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) => _call(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path) => _call(() => _dio.delete(path));

  Future<dynamic> _call(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
