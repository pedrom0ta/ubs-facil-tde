"""RF09 Histórico, RF10 Perfil, notificações e direitos do titular (LGPD)."""
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import usuario_atual
from app.core.database import get_db
from app.core.security import somente_digitos
from app.models import Notificacao, RegistroHistorico, TipoRegistro, Unidade, Usuario
from app.schemas import (
    AgendamentoOut,
    FcmTokenIn,
    NotificacaoOut,
    PerfilUpdateIn,
    RegistroOut,
    UnidadeOut,
    UsuarioOut,
)
from app.services import fhir

router = APIRouter(tags=["Perfil, histórico e notificações"])


# ---------- Histórico ----------
@router.get("/historico", response_model=list[RegistroOut])
def historico(tipo: TipoRegistro | None = Query(None), usuario: Usuario = Depends(usuario_atual),
              db: Session = Depends(get_db)):
    q = select(RegistroHistorico).where(RegistroHistorico.usuario_id == usuario.id)
    if tipo:
        q = q.where(RegistroHistorico.tipo == tipo)
    return db.scalars(q.order_by(RegistroHistorico.data_hora.desc())).all()


# ---------- Perfil ----------
@router.get("/perfil", response_model=UsuarioOut)
def ver_perfil(usuario: Usuario = Depends(usuario_atual)):
    return usuario


@router.patch("/perfil", response_model=UsuarioOut)
def atualizar_perfil(dados: PerfilUpdateIn, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    if dados.nome is not None:
        usuario.nome = dados.nome.strip()
    if dados.celular is not None:
        d = somente_digitos(dados.celular)
        if d and len(d) not in (10, 11):
            raise HTTPException(422, "Celular inválido.")
        usuario.celular = d or None
    if dados.notificacoes_ativas is not None:
        usuario.notificacoes_ativas = dados.notificacoes_ativas
    db.commit()
    return usuario


@router.put("/perfil/fcm-token", status_code=status.HTTP_204_NO_CONTENT)
def registrar_dispositivo(dados: FcmTokenIn, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    """O app envia o token do Firebase Cloud Messaging após o login."""
    usuario.fcm_token = dados.token
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/perfil/favoritas", response_model=list[UnidadeOut])
def favoritas(usuario: Usuario = Depends(usuario_atual)):
    return usuario.unidades_favoritas


@router.put("/perfil/favoritas/{unidade_id}", response_model=list[UnidadeOut])
def favoritar(unidade_id: int, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    unidade = db.get(Unidade, unidade_id)
    if unidade is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unidade não encontrada.")
    if unidade not in usuario.unidades_favoritas:
        usuario.unidades_favoritas.append(unidade)
        db.commit()
    return usuario.unidades_favoritas


@router.delete("/perfil/favoritas/{unidade_id}", response_model=list[UnidadeOut])
def desfavoritar(unidade_id: int, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    usuario.unidades_favoritas = [u for u in usuario.unidades_favoritas if u.id != unidade_id]
    db.commit()
    return usuario.unidades_favoritas


# ---------- LGPD ----------
@router.get("/perfil/exportar", tags=["LGPD"])
def exportar_dados(usuario: Usuario = Depends(usuario_atual)):
    """Portabilidade (art. 18, V): todos os dados do titular em formato estruturado."""
    return {
        "titular": fhir.paciente(usuario),
        "consentimento_em": usuario.consentimento_em.isoformat(),
        "agendamentos": [AgendamentoOut.model_validate(a).model_dump(mode="json") for a in usuario.agendamentos],
        "historico": [RegistroOut.model_validate(r).model_dump(mode="json") for r in usuario.registros],
    }


@router.delete("/perfil", status_code=status.HTTP_204_NO_CONTENT, tags=["LGPD"])
def excluir_conta(usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    """Eliminação dos dados (art. 18, VI). Prontuários oficiais permanecem no e-SUS, conforme a lei."""
    db.delete(usuario)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------- Notificações ----------
@router.get("/notificacoes", response_model=list[NotificacaoOut])
def notificacoes(usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    return db.scalars(
        select(Notificacao)
        .where(Notificacao.usuario_id == usuario.id, Notificacao.enviada_em.is_not(None))
        .order_by(Notificacao.enviada_em.desc())
        .limit(50)
    ).all()


@router.post("/notificacoes/{notificacao_id}/lida", status_code=status.HTTP_204_NO_CONTENT)
def marcar_lida(notificacao_id: int, usuario: Usuario = Depends(usuario_atual), db: Session = Depends(get_db)):
    n = db.get(Notificacao, notificacao_id)
    if n is None or n.usuario_id != usuario.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Notificação não encontrada.")
    n.lida = True
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
