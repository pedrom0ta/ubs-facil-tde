"""RF03 Agendar, RF04 Cancelar, RF05 Reagendar, RF06 Check-in e confirmação de presença."""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import usuario_atual
from app.core.clock import get_now
from app.core.config import settings
from app.core.database import get_db
from app.models import STATUS_ATIVOS, Agendamento, Especialidade, StatusAgendamento, Unidade, Usuario
from app.schemas import AgendamentoIn, AgendamentoOut, FilaOut, ReagendamentoIn
from app.services import agenda, fhir, fila
from app.services.notificacoes import agendar_lembretes, cancelar_lembretes

router = APIRouter(prefix="/agendamentos", tags=["Agendamentos"])

HORARIO_OCUPADO = "Este horário acabou de ser reservado por outra pessoa. Escolha outro, por favor."


def _meu(db: Session, agendamento_id: int, usuario: Usuario) -> Agendamento:
    ag = db.get(Agendamento, agendamento_id)
    # Controle de acesso: o paciente só enxerga os próprios agendamentos (404 para não revelar existência)
    if ag is None or ag.usuario_id != usuario.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Agendamento não encontrado.")
    return ag


def _checar_regras(db: Session, usuario: Usuario, unidade_id: int, especialidade_id: int,
                   data_hora: datetime, agora: datetime, ignorar_id: int | None = None) -> None:
    try:
        agenda.validar_horario(data_hora, agora)
    except agenda.RegraAgendaErro as e:
        raise HTTPException(422, str(e))
    if data_hora in agenda.horarios_ocupados(db, unidade_id, especialidade_id, data_hora.date(), ignorar_id):
        raise HTTPException(status.HTTP_409_CONFLICT, HORARIO_OCUPADO)
    conflito = db.scalar(select(Agendamento).where(
        Agendamento.usuario_id == usuario.id,
        Agendamento.data_hora == data_hora,
        Agendamento.status.in_(STATUS_ATIVOS),
        Agendamento.id != (ignorar_id or 0),
    ))
    if conflito:
        raise HTTPException(status.HTTP_409_CONFLICT, "Você já tem outra consulta neste mesmo horário.")
    mesma_esp = db.scalar(select(Agendamento).where(
        Agendamento.usuario_id == usuario.id,
        Agendamento.especialidade_id == especialidade_id,
        Agendamento.status.in_((StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO)),
        Agendamento.data_hora > agora,
        Agendamento.id != (ignorar_id or 0),
    ))
    if mesma_esp:
        raise HTTPException(status.HTTP_409_CONFLICT,
                            "Você já tem uma consulta futura nesta especialidade. Reagende-a em vez de marcar outra.")


@router.get("", response_model=list[AgendamentoOut])
def listar(ativos: bool = Query(True, description="true = próximas consultas; false = todas"),
           usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    q = select(Agendamento).where(Agendamento.usuario_id == usuario.id)
    if ativos:
        q = q.where(Agendamento.status.in_(STATUS_ATIVOS)).order_by(Agendamento.data_hora)
    else:
        q = q.order_by(Agendamento.data_hora.desc())
    return db.scalars(q).all()


@router.post("", response_model=AgendamentoOut, status_code=status.HTTP_201_CREATED)
def agendar(dados: AgendamentoIn, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db),
            agora: datetime = Depends(get_now)):
    if not db.get(Unidade, dados.unidade_id) or not db.get(Especialidade, dados.especialidade_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unidade ou especialidade não encontrada.")
    data_hora = dados.data_hora.replace(tzinfo=None, second=0, microsecond=0)
    _checar_regras(db, usuario, dados.unidade_id, dados.especialidade_id, data_hora, agora)
    ag = Agendamento(usuario_id=usuario.id, unidade_id=dados.unidade_id,
                     especialidade_id=dados.especialidade_id, data_hora=data_hora)
    db.add(ag)
    try:
        db.flush()
    except IntegrityError:  # duas pessoas no mesmo segundo: o índice único garante só uma
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, HORARIO_OCUPADO)
    db.refresh(ag)
    agendar_lembretes(db, ag, agora)
    db.commit()
    return ag


@router.get("/{agendamento_id}", response_model=AgendamentoOut)
def detalhar(agendamento_id: int, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    return _meu(db, agendamento_id, usuario)


@router.patch("/{agendamento_id}", response_model=AgendamentoOut)
def reagendar(agendamento_id: int, dados: ReagendamentoIn, usuario: Usuario = Depends(usuario_atual),
              db: Session = Depends(get_db), agora: datetime = Depends(get_now)):
    ag = _meu(db, agendamento_id, usuario)
    if ag.status not in (StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO):
        raise HTTPException(status.HTTP_409_CONFLICT, "Esta consulta não pode mais ser reagendada.")
    nova = dados.data_hora.replace(tzinfo=None, second=0, microsecond=0)
    _checar_regras(db, usuario, ag.unidade_id, ag.especialidade_id, nova, agora, ignorar_id=ag.id)
    ag.data_hora = nova
    ag.status = StatusAgendamento.AGENDADO
    ag.confirmado_em = None
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, HORARIO_OCUPADO)
    agendar_lembretes(db, ag, agora)
    db.commit()
    return ag


@router.post("/{agendamento_id}/cancelar", response_model=AgendamentoOut)
async def cancelar(agendamento_id: int, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db),
                   agora: datetime = Depends(get_now)):
    ag = _meu(db, agendamento_id, usuario)
    if ag.status not in (StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO, StatusAgendamento.CHECKIN):
        raise HTTPException(status.HTTP_409_CONFLICT, "Esta consulta não pode mais ser cancelada.")
    estava_na_fila = ag.status == StatusAgendamento.CHECKIN
    ag.status = StatusAgendamento.CANCELADO
    ag.cancelado_em = agora
    cancelar_lembretes(db, ag.id)
    db.commit()
    if estava_na_fila:  # quem estava atrás sobe uma posição
        await fila.difundir_fila(db, ag.unidade_id, ag.especialidade_id, ag.data_hora.date(), agora)
    return ag


@router.post("/{agendamento_id}/confirmar", response_model=AgendamentoOut)
def confirmar_presenca(agendamento_id: int, usuario: Usuario = Depends(usuario_atual),
                       db: Session = Depends(get_db), agora: datetime = Depends(get_now)):
    ag = _meu(db, agendamento_id, usuario)
    if ag.status not in (StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO) or ag.data_hora <= agora:
        raise HTTPException(status.HTTP_409_CONFLICT, "Não é possível confirmar esta consulta.")
    ag.status = StatusAgendamento.CONFIRMADO
    ag.confirmado_em = agora
    db.commit()
    return ag


@router.post("/{agendamento_id}/checkin", response_model=FilaOut)
async def checkin(agendamento_id: int, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db),
                  agora: datetime = Depends(get_now)):
    ag = _meu(db, agendamento_id, usuario)
    if ag.status == StatusAgendamento.CHECKIN:
        return fila.situacao(db, ag, agora)
    if ag.status not in (StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO):
        raise HTTPException(status.HTTP_409_CONFLICT, "Não é possível fazer check-in nesta consulta.")
    abre = ag.data_hora - timedelta(minutes=settings.checkin_antes_min)
    fecha = ag.data_hora + timedelta(minutes=settings.checkin_depois_min)
    if agora < abre:
        raise HTTPException(status.HTTP_409_CONFLICT,
                            f"O check-in abre {settings.checkin_antes_min // 60}h antes da consulta ({abre:%d/%m às %H:%M}).")
    if agora > fecha:
        raise HTTPException(status.HTTP_409_CONFLICT,
                            "O prazo para check-in desta consulta terminou. Procure a recepção da unidade.")
    ag.status = StatusAgendamento.CHECKIN
    ag.checkin_em = agora
    ag.senha = fila.gerar_senha(db, ag)
    cancelar_lembretes(db, ag.id)
    db.commit()
    await fila.difundir_fila(db, ag.unidade_id, ag.especialidade_id, ag.data_hora.date(), agora)
    return fila.situacao(db, ag, agora)


@router.get("/{agendamento_id}/fhir", tags=["Integração HL7 FHIR"])
def como_fhir(agendamento_id: int, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    """Recurso FHIR R4 `Appointment` correspondente ao agendamento."""
    return fhir.consulta(_meu(db, agendamento_id, usuario))
