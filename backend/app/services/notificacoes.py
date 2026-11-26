"""Lembretes automáticos e envio de push (Firebase Cloud Messaging).

- Ao agendar, são criados dois lembretes: 24h e 2h antes da consulta.
- Um laço em segundo plano (ver main.py) envia os lembretes vencidos a cada minuto.
- Sem credenciais do Firebase configuradas, o envio é apenas registrado no log
  (modo desenvolvimento) e a notificação continua disponível em GET /notificacoes.
"""
import logging
from datetime import datetime, timedelta

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import Agendamento, Notificacao, TipoNotificacao, Usuario

log = logging.getLogger("ubs_facil.notificacoes")


# ---------- Envio push ----------
class EnviadorPush:
    def __init__(self) -> None:
        self._app = None
        if settings.firebase_credenciais:
            try:
                import firebase_admin
                from firebase_admin import credentials

                self._app = firebase_admin.initialize_app(credentials.Certificate(settings.firebase_credenciais))
                log.info("Firebase Cloud Messaging ativo")
            except Exception as exc:  # pragma: no cover - depende de credenciais reais
                log.warning("Não foi possível iniciar o Firebase: %s", exc)

    def enviar(self, token: str | None, titulo: str, mensagem: str, dados: dict | None = None) -> bool:
        if not token:
            return False
        if self._app is None:
            log.info("[push simulado] %s — %s", titulo, mensagem)
            return True
        from firebase_admin import messaging  # pragma: no cover

        msg = messaging.Message(  # pragma: no cover
            token=token,
            notification=messaging.Notification(title=titulo, body=mensagem),
            data={k: str(v) for k, v in (dados or {}).items()},
        )
        messaging.send(msg)  # pragma: no cover
        return True  # pragma: no cover


enviador = EnviadorPush()


def _fmt(dh: datetime) -> str:
    return dh.strftime("%d/%m às %H:%M")


# ---------- Lembretes de consulta ----------
def agendar_lembretes(db: Session, ag: Agendamento, agora: datetime) -> None:
    cancelar_lembretes(db, ag.id)
    nome_unidade = ag.unidade.nome
    lembretes = [
        (TipoNotificacao.LEMBRETE_24H, ag.data_hora - timedelta(hours=24),
         f"Sua consulta de {ag.especialidade.nome} na {nome_unidade} é amanhã, {_fmt(ag.data_hora)}. Deseja confirmar sua presença?"),
        (TipoNotificacao.LEMBRETE_2H, ag.data_hora - timedelta(hours=2),
         f"Sua consulta de {ag.especialidade.nome} na {nome_unidade} é daqui a 2 horas. Ao chegar, faça o check-in pelo app."),
    ]
    for tipo, quando, texto in lembretes:
        if quando > agora:
            db.add(Notificacao(
                usuario_id=ag.usuario_id, agendamento_id=ag.id, tipo=tipo,
                titulo="Lembrete de consulta", mensagem=texto, enviar_em=quando,
            ))


def cancelar_lembretes(db: Session, agendamento_id: int) -> None:
    db.execute(
        update(Notificacao)
        .where(Notificacao.agendamento_id == agendamento_id, Notificacao.enviada_em.is_(None))
        .values(cancelada=True)
    )


def notificar_agora(db: Session, usuario: Usuario, tipo: TipoNotificacao, titulo: str, mensagem: str,
                    agora: datetime, agendamento_id: int | None = None) -> None:
    n = Notificacao(usuario_id=usuario.id, agendamento_id=agendamento_id, tipo=tipo,
                    titulo=titulo, mensagem=mensagem, enviar_em=agora, enviada_em=agora)
    db.add(n)
    if usuario.notificacoes_ativas:
        enviador.enviar(usuario.fcm_token, titulo, mensagem, {"tipo": tipo.value, "agendamento_id": agendamento_id or ""})


def enviar_pendentes(db: Session, agora: datetime) -> int:
    """Envia todos os lembretes vencidos. Retorna quantos foram processados."""
    pendentes = db.scalars(
        select(Notificacao).where(
            Notificacao.enviada_em.is_(None),
            Notificacao.cancelada.is_(False),
            Notificacao.enviar_em <= agora,
        )
    ).all()
    for n in pendentes:
        if n.usuario.notificacoes_ativas:
            enviador.enviar(n.usuario.fcm_token, n.titulo, n.mensagem,
                            {"tipo": n.tipo.value, "agendamento_id": n.agendamento_id or ""})
        n.enviada_em = agora
    db.commit()
    return len(pendentes)
