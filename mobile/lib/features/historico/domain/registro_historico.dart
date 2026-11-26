enum TipoRegistro {
  consulta('CONSULTA', 'Consultas'),
  exame('EXAME', 'Exames'),
  vacina('VACINA', 'Vacinas');

  const TipoRegistro(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static TipoRegistro fromApi(String v) => values.firstWhere((t) => t.api == v, orElse: () => consulta);
}

class RegistroHistorico {
  const RegistroHistorico({
    required this.id,
    required this.tipo,
    required this.descricao,
    required this.dataHora,
    required this.unidade,
  });
  final int id;
  final TipoRegistro tipo;
  final String descricao;
  final DateTime dataHora;
  final String unidade;
}

abstract class HistoricoRepository {
  Future<List<RegistroHistorico>> listar({TipoRegistro? tipo});
}
