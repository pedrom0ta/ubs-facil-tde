class Unidade {
  const Unidade({required this.id, required this.nome, required this.endereco});
  final int id;
  final String nome;
  final String endereco;

  @override
  bool operator ==(Object other) => other is Unidade && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Especialidade {
  const Especialidade({required this.id, required this.nome});
  final int id;
  final String nome;

  @override
  bool operator ==(Object other) => other is Especialidade && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class DiaDisponivel {
  const DiaDisponivel({required this.data, required this.vagas});
  final DateTime data;
  final int vagas;
}

class Horario {
  const Horario({required this.dataHora, required this.hora, required this.disponivel});
  final DateTime dataHora;
  final String hora;
  final bool disponivel;
}

enum StatusAgendamento {
  agendado,
  confirmado,
  checkin,
  emAtendimento,
  realizado,
  cancelado,
  faltou;

  static StatusAgendamento fromApi(String v) => switch (v) {
        'AGENDADO' => agendado,
        'CONFIRMADO' => confirmado,
        'CHECKIN' => checkin,
        'EM_ATENDIMENTO' => emAtendimento,
        'REALIZADO' => realizado,
        'CANCELADO' => cancelado,
        _ => faltou,
      };

  String get rotulo => switch (this) {
        agendado => 'Agendado',
        confirmado => 'Presença confirmada',
        checkin => 'Na fila',
        emAtendimento => 'Em atendimento',
        realizado => 'Realizado',
        cancelado => 'Cancelado',
        faltou => 'Não compareceu',
      };

  bool get podeAlterar => this == agendado || this == confirmado;
}

class Agendamento {
  const Agendamento({
    required this.id,
    required this.dataHora,
    required this.status,
    required this.unidade,
    required this.especialidade,
    this.senha,
    this.consultorio,
  });

  final int id;
  final DateTime dataHora;
  final StatusAgendamento status;
  final Unidade unidade;
  final Especialidade especialidade;
  final String? senha;
  final String? consultorio;
}
