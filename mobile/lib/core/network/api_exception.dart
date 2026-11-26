import 'package:dio/dio.dart';

/// Erro já traduzido em linguagem simples, pronto para mostrar ao paciente.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return ApiException(data['detail'] as String, statusCode: e.response?.statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException('O servidor demorou para responder. Tente novamente.');
      case DioExceptionType.connectionError:
        return const ApiException('Sem conexão com o servidor. Verifique sua internet.');
      default:
        return ApiException(
          'Algo deu errado. Tente novamente em instantes.',
          statusCode: e.response?.statusCode,
        );
    }
  }

  @override
  String toString() => message;
}
