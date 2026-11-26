"""Regras da agenda: quais horários existem e quais estão livres."""
from datetime import date, datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import STATUS_ATIVOS, Agendamento

# Grade padrão de atendimento das UBS (de 30 em 30 minutos)
GRADE = [time(h, m) for h in range(7, 11) for m in (0, 30) if (h, m) >= (7, 30)] + [time(11, 0)] + [
    time(h, m) for h in range(13, 17) for m in (0, 30)
]


class RegraAgendaErro(ValueError):
    pass


def dia_util(d: date) -> bool:
    return d.weekday() < 5


def validar_horario(data_hora: datetime, agora: datetime) -> None:
    """Prevenção de erros: bloqueia passado, fim de semana, horário fora da grade e datas muito distantes."""
    if data_hora <= agora:
        raise RegraAgendaErro("Não é possível agendar em um horário que já passou.")
    if not dia_util(data_hora.date()):
        raise RegraAgendaErro("As UBS atendem de segunda a sexta-feira.")
    if data_hora.time().replace(second=0, microsecond=0) not in GRADE or data_hora.second:
        raise RegraAgendaErro("Horário fora da grade de atendimento da unidade.")
    if data_hora.date() > agora.date() + timedelta(days=settings.agenda_dias_a_frente):
        raise RegraAgendaErro(f"A agenda está aberta apenas para os próximos {settings.agenda_dias_a_frente} dias.")


def horarios_ocupados(db: Session, unidade_id: int, especialidade_id: int, dia: date, ignorar_id: int | None = None) -> set[datetime]:
    inicio = datetime.combine(dia, time.min)
    fim = inicio + timedelta(days=1)
    q = select(Agendamento.data_hora).where(
        Agendamento.unidade_id == unidade_id,
        Agendamento.especialidade_id == especialidade_id,
        Agendamento.data_hora >= inicio,
        Agendamento.data_hora < fim,
        Agendamento.status.in_(STATUS_ATIVOS),
    )
    if ignorar_id:
        q = q.where(Agendamento.id != ignorar_id)
    return set(db.scalars(q))


def listar_horarios(db: Session, unidade_id: int, especialidade_id: int, dia: date, agora: datetime) -> list[dict]:
    if not dia_util(dia):
        return []
    ocupados = horarios_ocupados(db, unidade_id, especialidade_id, dia)
    resultado = []
    for t in GRADE:
        dh = datetime.combine(dia, t)
        resultado.append({
            "data_hora": dh,
            "hora": t.strftime("%H:%M"),
            "disponivel": dh > agora and dh not in ocupados,
        })
    return resultado


def proximos_dias(db: Session, unidade_id: int, especialidade_id: int, agora: datetime, quantidade: int = 10) -> list[dict]:
    dias, d = [], agora.date()
    limite = agora.date() + timedelta(days=settings.agenda_dias_a_frente)
    while len(dias) < quantidade and d <= limite:
        if dia_util(d):
            vagas = sum(1 for h in listar_horarios(db, unidade_id, especialidade_id, d, agora) if h["disponivel"])
            if vagas:
                dias.append({"data": d, "vagas": vagas})
        d += timedelta(days=1)
    return dias
