import 'package:flutter/services.dart';

String somenteDigitos(String v) => v.replaceAll(RegExp(r'\D'), '');

/// Validação de CPF com dígitos verificadores (mesma regra do backend).
bool cpfValido(String cpf) {
  final d = somenteDigitos(cpf);
  if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
  for (final tam in [9, 10]) {
    var soma = 0;
    for (var i = 0; i < tam; i++) {
      soma += int.parse(d[i]) * (tam + 1 - i);
    }
    final dv = (soma * 10) % 11 % 10;
    if (dv != int.parse(d[tam])) return false;
  }
  return true;
}

/// Validação do Cartão Nacional de Saúde (soma ponderada módulo 11).
bool cnsValido(String cns) {
  final d = somenteDigitos(cns);
  if (d.length != 15 || d[0] == '0') return false;
  var soma = 0;
  for (var i = 0; i < 15; i++) {
    soma += int.parse(d[i]) * (15 - i);
  }
  return soma % 11 == 0;
}

String formatarCpf(String v) => _aplicarMascara(somenteDigitos(v), '###.###.###-##');
String formatarCns(String v) => _aplicarMascara(somenteDigitos(v), '### #### #### ####');
String formatarCelular(String v) {
  final d = somenteDigitos(v);
  return _aplicarMascara(d, d.length <= 10 ? '(##) ####-####' : '(##) #####-####');
}

/// CPF com os dígitos do meio ocultos, para exibir em tela (privacidade).
String cpfOculto(String cpf) {
  final d = somenteDigitos(cpf);
  if (d.length != 11) return cpf;
  return '${d.substring(0, 3)}.***.***-${d.substring(9)}';
}

String _aplicarMascara(String digitos, String mascara) {
  final buf = StringBuffer();
  var i = 0;
  for (final c in mascara.split('')) {
    if (i >= digitos.length) break;
    if (c == '#') {
      buf.write(digitos[i++]);
    } else {
      buf.write(c);
    }
  }
  return buf.toString();
}

/// Máscara aplicada enquanto o usuário digita.
class MascaraInputFormatter extends TextInputFormatter {
  MascaraInputFormatter(this.formatar, this.maxDigitos);

  factory MascaraInputFormatter.cpf() => MascaraInputFormatter(formatarCpf, 11);
  factory MascaraInputFormatter.cns() => MascaraInputFormatter(formatarCns, 15);
  factory MascaraInputFormatter.celular() => MascaraInputFormatter(formatarCelular, 11);

  final String Function(String) formatar;
  final int maxDigitos;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = somenteDigitos(newValue.text);
    if (d.length > maxDigitos) d = d.substring(0, maxDigitos);
    final texto = formatar(d);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
