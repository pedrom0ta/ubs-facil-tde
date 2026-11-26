"""Catálogo de unidades e especialidades, e consulta de horários livres."""
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import usuario_atual
from app.core.clock import get_now
from app.core.database import get_db
from app.models import Especialidade, Unidade
from app.schemas import DiaDisponivelOut, EspecialidadeOut, HorarioOut, UnidadeOut
from app.services import agenda

router = APIRouter(tags=["Unidades e horários"], dependencies=[Depends(usuario_atual)])


@router.get("/unidades", response_model=list[UnidadeOut])
def listar_unidades(db: Session = Depends(get_db)):
    return db.scalars(select(Unidade).order_by(Unidade.nome)).all()


@router.get("/especialidades", response_model=list[EspecialidadeOut])
def listar_especialidades(db: Session = Depends(get_db)):
    return db.scalars(select(Especialidade).order_by(Especialidade.nome)).all()


def _validar(db: Session, unidade_id: int, especialidade_id: int) -> None:
    if not db.get(Unidade, unidade_id):
        raise HTTPException(404, "Unidade não encontrada.")
    if not db.get(Especialidade, especialidade_id):
        raise HTTPException(404, "Especialidade não encontrada.")


@router.get("/unidades/{unidade_id}/dias", response_model=list[DiaDisponivelOut])
def dias_disponiveis(unidade_id: int, especialidade_id: int = Query(...), db: Session = Depends(get_db),
                     agora: datetime = Depends(get_now)):
    _validar(db, unidade_id, especialidade_id)
    return agenda.proximos_dias(db, unidade_id, especialidade_id, agora)


@router.get("/unidades/{unidade_id}/horarios", response_model=list[HorarioOut])
def horarios(unidade_id: int, especialidade_id: int = Query(...), data: date = Query(...),
             db: Session = Depends(get_db), agora: datetime = Depends(get_now)):
    _validar(db, unidade_id, especialidade_id)
    return agenda.listar_horarios(db, unidade_id, especialidade_id, data, agora)
