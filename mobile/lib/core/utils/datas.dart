import 'package:intl/intl.dart';

/// Formatação de datas em português do Brasil.
class Datas {
  const Datas._();

  static final _diaSemana = DateFormat('EEE', 'pt_BR');
  static final _diaMes = DateFormat("d 'de' MMM", 'pt_BR');
  static final _completa = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
  static final _hora = DateFormat('HH:mm', 'pt_BR');
  static final _api = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  static final _apiData = DateFormat('yyyy-MM-dd');

  /// "Ter" (sem ponto final)
  static String diaSemanaCurto(DateTime d) => _capitalizar(_diaSemana.format(d).replaceAll('.', ''));

  /// "ter, 10 de nov. · 08:00"
  static String consulta(DateTime d) =>
      '${diaSemanaCurto(d)}, ${_diaMes.format(d)} · ${_hora.format(d)}';

  /// "Terça-feira, 10 de novembro"
  static String completa(DateTime d) => _capitalizar(_completa.format(d));

  static String hora(DateTime d) => _hora.format(d);

  static String mesCurto(DateTime d) => DateFormat('MMM', 'pt_BR').format(d).replaceAll('.', '');

  /// Formato aceito pela API (horário local da UBS, sem fuso).
  static String paraApi(DateTime d) => _api.format(d);

  static String dataApi(DateTime d) => _apiData.format(d);

  static bool mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
