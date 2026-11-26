import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ubs_facil/core/utils/datas.dart';
import 'package:ubs_facil/core/utils/documentos.dart';
import 'package:ubs_facil/features/agendamento/domain/entidades.dart';

void main() {
  group('CPF', () {
    test('aceita CPF válido com ou sem máscara', () {
      expect(cpfValido('529.982.247-25'), isTrue);
      expect(cpfValido('52998224725'), isTrue);
    });
    test('rejeita dígito errado, repetidos e tamanho errado', () {
      expect(cpfValido('529.982.247-26'), isFalse);
      expect(cpfValido('111.111.111-11'), isFalse);
      expect(cpfValido('1234'), isFalse);
    });
    test('oculta os dígitos do meio', () {
      expect(cpfOculto('52998224725'), '529.***.***-25');
    });
  });

  group('CNS', () {
    test('valida pela soma ponderada', () {
      expect(cnsValido('70000000000010${_dv('70000000000010')}'), isTrue);
      expect(cnsValido('123456789012345'), isFalse);
      expect(cnsValido('000000000000000'), isFalse);
    });
  });

  group('Máscaras', () {
    test('formata enquanto digita', () {
      final f = MascaraInputFormatter.cpf();
      final r = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '529982247251234'));
      expect(r.text, '529.982.247-25');
      expect(formatarCns('898001234567890'), '898 0012 3456 7890');
      expect(formatarCelular('11987654321'), '(11) 98765-4321');
    });
  });

  group('Datas e status', () {
    setUpAll(() => initializeDateFormatting('pt_BR'));

    test('formato enviado à API', () {
      expect(Datas.paraApi(DateTime(2026, 11, 10, 8)), '2026-11-10T08:00:00');
    });
    test('converte status da API', () {
      expect(StatusAgendamento.fromApi('EM_ATENDIMENTO'), StatusAgendamento.emAtendimento);
      expect(StatusAgendamento.fromApi('CONFIRMADO').podeAlterar, isTrue);
      expect(StatusAgendamento.fromApi('REALIZADO').podeAlterar, isFalse);
    });
  });
}

/// Calcula o 15º dígito para montar um CNS de teste válido.
String _dv(String base14) {
  var soma = 0;
  for (var i = 0; i < 14; i++) {
    soma += int.parse(base14[i]) * (15 - i);
  }
  final dv = (11 - soma % 11) % 11;
  return dv < 10 ? '$dv' : 'x';
}
