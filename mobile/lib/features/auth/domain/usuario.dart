/// Entidade de domínio: paciente (ou atendente da recepção) autenticado.
class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.cns,
    required this.celular,
    required this.notificacoesAtivas,
  });

  final int id;
  final String nome;
  final String cpf;
  final String cns;
  final String? celular;
  final bool notificacoesAtivas;

  String get primeiroNome => nome.trim().split(RegExp(r'\s+')).first;

  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+'));
    final ini = partes.first[0] + (partes.length > 1 ? partes.last[0] : '');
    return ini.toUpperCase();
  }
}

/// Contrato do repositório (camada de domínio não conhece HTTP).
abstract class AuthRepository {
  Future<Usuario?> usuarioLogado();
  Future<Usuario> entrar({required String cpf, required String senha});
  Future<Usuario> cadastrar({
    required String nome,
    required String cpf,
    required String cns,
    String? celular,
    required String senha,
    required bool aceiteTermos,
  });
  Future<void> sair();
}
