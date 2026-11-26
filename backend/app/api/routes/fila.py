"""RF07 Fila em tempo real (polling e WebSocket) e módulo da recepção."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import somente_recepcao, usuario_atual, usuario_do_token
from app.core.clock import agora as relogio, get_now
from app.core.database import SessionLocal, get_db
from app.models import (
    Agendamento,
    RegistroHistorico,
    StatusAgendamento,
    TipoNotificacao,
    Usuario,
)
from app.schemas import AgendamentoOut, ChamarProximoIn, FilaOut, FinalizarIn
from app.services import fila
from app.services.notificacoes import notificar_agora

router = APIRouter(prefix="/fila", tags=["Fila em tempo real"])
recepcao = APIRouter(prefix="/recepcao", tags=["Recepção"], dependencies=[Depends(somente_recepcao)])


def _minha_vez(db: Session, usuario_id: int) -> Agendamento | None:
    return db.scalar(
        select(Agendamento)
        .where(Agendamento.usuario_id == usuario_id,
               Agendamento.status.in_((StatusAgendamento.CHECKIN, StatusAgendamento.EM_ATENDIMENTO)))
        .order_by(Agendamento.checkin_em.desc())
    )


@router.get("/minha", response_model=FilaOut, responses={204: {"description": "Sem check-in ativo"}})
def minha_posicao(usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db),
                  agora: datetime = Depends(get_now)):
    """Alternativa por polling ao WebSocket (recomenda-se consultar a cada 15 s)."""
    ag = _minha_vez(db, usuario.id)
    if ag is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Você não está em nenhuma fila no momento.")
    return fila.situacao(db, ag, agora)


@router.websocket("/ws")
async def fila_ws(ws: WebSocket, token: str = Query(...)):
    """Conecte com `ws://<host>/fila/ws?token=<JWT>`. Recebe a situação a cada mudança na fila."""
    db = SessionLocal()
    try:
        usuario = usuario_do_token(token, db)
        if usuario is None:
            await ws.close(code=4401)
            return
        await fila.gerenciador.conectar(usuario.id, ws)
        ag = _minha_vez(db, usuario.id)
        if ag:
            info = fila.situacao(db, ag, relogio())
            await ws.send_json({**info, "status": info["status"].value, "atualizado_em": info["atualizado_em"].isoformat()})
        try:
            while True:
                await ws.receive_text()  # mantém a conexão; o cliente pode enviar "ping"
        except WebSocketDisconnect:
            fila.gerenciador.desconectar(usuario.id, ws)
    finally:
        db.close()


# ---------- Recepção (painel da unidade) ----------
@recepcao.get("/fila", response_model=list[FilaOut])
def ver_fila(unidade_id: int, especialidade_id: int, db: Session = Depends(get_db),
             agora: datetime = Depends(get_now)):
    return [fila.situacao(db, a, agora) for a in fila.fila_do_dia(db, unidade_id, especialidade_id, agora.date())]


@recepcao.post("/chamar-proximo", response_model=AgendamentoOut)
async def chamar_proximo(dados: ChamarProximoIn, db: Session = Depends(get_db), agora: datetime = Depends(get_now)):
    atual = fila.fila_do_dia(db, dados.unidade_id, dados.especialidade_id, agora.date())
    if not atual:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Não há pacientes aguardando nesta fila.")
    ag = atual[0]
    ag.status = StatusAgendamento.EM_ATENDIMENTO
    ag.chamado_em = agora
    ag.consultorio = dados.consultorio
    notificar_agora(db, ag.usuario, TipoNotificacao.FILA_CHAMADO, "Sua senha foi chamada!",
                    f"Senha {ag.senha}: dirija-se ao {dados.consultorio}.", agora, ag.id)
    db.commit()
    await fila.difundir_fila(db, dados.unidade_id, dados.especialidade_id, agora.date(), agora, extras=[ag])
    return ag


@recepcao.post("/agendamentos/{agendamento_id}/finalizar", response_model=AgendamentoOut)
def finalizar(agendamento_id: int, dados: FinalizarIn, db: Session = Depends(get_db),
              agora: datetime = Depends(get_now)):
    ag = db.get(Agendamento, agendamento_id)
    if ag is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Agendamento não encontrado.")
    if not dados.compareceu:
        if ag.status in (StatusAgendamento.REALIZADO, StatusAgendamento.CANCELADO):
            raise HTTPException(status.HTTP_409_CONFLICT, "Atendimento já encerrado.")
        ag.status = StatusAgendamento.FALTOU
        db.commit()
        return ag
    if ag.status != StatusAgendamento.EM_ATENDIMENTO:
        raise HTTPException(status.HTTP_409_CONFLICT, "Só é possível finalizar um atendimento em andamento.")
    ag.status = StatusAgendamento.REALIZADO
    ag.finalizado_em = agora
    tipo = ag.especialidade.tipo_registro
    nome = ag.especialidade.nome
    descricao = f"Consulta · {nome}" if tipo.value == "CONSULTA" else nome
    db.add(RegistroHistorico(
        usuario_id=ag.usuario_id, tipo=tipo, descricao=descricao,
        unidade_id=ag.unidade_id, data_hora=ag.data_hora, agendamento_id=ag.id, observacoes=dados.observacoes,
    ))
    db.commit()
    return ag
