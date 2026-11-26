"""Dados iniciais para desenvolvimento e demonstração.

Uso:  python -m app.seed          (cria as tabelas e popula se o banco estiver vazio)
      python -m app.seed --reset  (apaga tudo e recria)
"""
import sys
from datetime import datetime, time, timedelta

from sqlalchemy import select

from app.core.clock import agora
from app.core.database import Base, SessionLocal, engine
from app.core.security import hash_senha
from app.models import (
    Agendamento,
    Especialidade,
    Papel,
    RegistroHistorico,
    StatusAgendamento,
    TipoRegistro,
    Unidade,
    Usuario,
)


def gerar_cns(n: int) -> str:
    """CNS fictício válido (prefixo 7) derivado de um número; usado só em dados de demonstração."""
    k = n * 100
    while True:
        b = f"7{k:013d}"
        soma = sum(int(b[i]) * (15 - i) for i in range(14))
        dv = (11 - soma % 11) % 11
        if dv < 10:
            return b + str(dv)
        k += 1


DEMO_CPF = "52998224725"         # CPF fictício válido
RECEPCAO_CPF = "11144477735"     # CPF fictício válido
DEMO_SENHA = "ubsfacil123"


def popular(db) -> None:
    if db.scalar(select(Usuario).limit(1)):
        print("Banco já possui dados; nada a fazer (use --reset para recriar).")
        return
    now = agora()

    unidades = [
        Unidade(nome="UBS Centro", endereco="Rua XV de Novembro, 120 · Centro", cnes="2077485"),
        Unidade(nome="UBS Jardim América", endereco="Av. das Américas, 1450 · Jardim América", cnes="2077493"),
        Unidade(nome="UBS Vila Nova", endereco="Rua das Palmeiras, 77 · Vila Nova", cnes="2077507"),
    ]
    esp = {
        "Clínica Geral": Especialidade(nome="Clínica Geral", tempo_medio_min=15, prefixo_senha="C"),
        "Pediatria": Especialidade(nome="Pediatria", tempo_medio_min=20, prefixo_senha="P"),
        "Ginecologia": Especialidade(nome="Ginecologia", tempo_medio_min=20, prefixo_senha="G"),
        "Odontologia": Especialidade(nome="Odontologia", tempo_medio_min=30, prefixo_senha="O"),
        "Vacinação": Especialidade(nome="Vacinação", tempo_medio_min=5, prefixo_senha="V", tipo_registro=TipoRegistro.VACINA),
        "Coleta de exames": Especialidade(nome="Coleta de exames", tempo_medio_min=10, prefixo_senha="E", tipo_registro=TipoRegistro.EXAME),
    }
    db.add_all(unidades + list(esp.values()))

    maria = Usuario(nome="Maria Silva", cpf=DEMO_CPF, cns=gerar_cns(1), celular="11987654321",
                    senha_hash=hash_senha(DEMO_SENHA), consentimento_em=now)
    recepcao = Usuario(nome="Recepção UBS Centro", cpf=RECEPCAO_CPF, cns=gerar_cns(2),
                       senha_hash=hash_senha(DEMO_SENHA), papel=Papel.RECEPCAO, consentimento_em=now)
    db.add_all([maria, recepcao])
    db.flush()

    centro = unidades[0]
    historico = [
        (TipoRegistro.CONSULTA, "Consulta · Clínica Geral", now - timedelta(days=55)),
        (TipoRegistro.EXAME, "Coleta de exames · Hemograma completo", now - timedelta(days=70)),
        (TipoRegistro.CONSULTA, "Consulta · Ginecologia", now - timedelta(days=83)),
        (TipoRegistro.VACINA, "Vacinação · Influenza (gripe)", now - timedelta(days=118)),
        (TipoRegistro.CONSULTA, "Consulta · Pediatria", now - timedelta(days=156)),
    ]
    for tipo, desc, quando in historico:
        db.add(RegistroHistorico(usuario_id=maria.id, tipo=tipo, descricao=desc, unidade_id=centro.id,
                                 data_hora=quando.replace(hour=9, minute=0, second=0)))

    # Fila de demonstração de hoje (dias úteis): 3 pacientes fictícios já fizeram check-in na UBS Centro
    if now.weekday() < 5:
        for i, h in enumerate((time(7, 30), time(8, 0), time(8, 30)), start=1):
            p = Usuario(nome=f"Paciente Demonstração {i}", cpf=f"0000000000{i}", cns=gerar_cns(10 + i),
                        senha_hash=hash_senha(DEMO_SENHA + str(i)), consentimento_em=now)
            db.add(p)
            db.flush()
            db.add(Agendamento(usuario_id=p.id, unidade_id=centro.id, especialidade_id=esp["Clínica Geral"].id,
                               data_hora=datetime.combine(now.date(), h), status=StatusAgendamento.CHECKIN,
                               checkin_em=now - timedelta(minutes=30 - i), senha=f"C-{i:03d}"))
    db.commit()
    print("Dados de demonstração criados.")
    print(f"  Paciente:  CPF {DEMO_CPF}  senha {DEMO_SENHA}")
    print(f"  Recepção:  CPF {RECEPCAO_CPF}  senha {DEMO_SENHA}")


def main() -> None:
    if "--reset" in sys.argv:
        Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        popular(db)


if __name__ == "__main__":
    main()
