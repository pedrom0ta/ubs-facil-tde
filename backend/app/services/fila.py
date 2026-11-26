"""Fila em tempo real: posição, tempo estimado e difusão por WebSocket.

A fila é por unidade + especialidade + dia. Entra nela quem fez o check-in digital.
A ordem respeita o horário agendado (quem marcou mais cedo é chamado antes) e,
em empate, a ordem de chegada.
"""
import logging
from collections import defaultdict
from datetime import date, datetime, time, timedelta

from fastapi import WebSocket
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Agendamento, Especialidade, Notificacao, StatusAgendamento, TipoNotificacao
from app.services.notificacoes import notificar_agora

log = logging.getLogger("ubs_facil.fila")


def _intervalo(dia: date) -> tuple[datetime, datetime]:
    inicio = datetime.combine(dia, time.min)
    return inicio, inicio + timedelta(days=1)


def fila_do_dia(db: Session, unidade_id: int, especialidade_id: int, dia: date) -> list[Agendamento]:
    ini, fim = _intervalo(dia)
    return list(db.scalars(
        select(Agendamento)
        .where(
            Agendamento.unidade_id == unidade_id,
            Agendamento.especialidade_id == especialidade_id,
            Agendamento.data_hora >= ini,
            Agendamento.data_hora < fim,
            Agendamento.status == StatusAgendamento.CHECKIN,
        )
        .order_by(Agendamento.data_hora, Agendamento.checkin_em)
    ))


def tempo_medio_min(db: Session, unidade_id: int, especialidade: Especialidade, dia: date) -> float:
    """Média real dos atendimentos de hoje; se ainda não houver, usa a média cadastrada da especialidade."""
    ini, fim = _intervalo(dia)
    feitos = db.execute(
        select(Agendamento.chamado_em, Agendamento.finalizado_em).where(
            Agendamento.unidade_id == unidade_id,
            Agendamento.especialidade_id == especialidade.id,
            Agendamento.data_hora >= ini,
            Agendamento.data_hora < fim,
            Agendamento.status == StatusAgendamento.REALIZADO,
            Agendamento.chamado_em.is_not(None),
            Agendamento.finalizado_em.is_not(None),
        )
    ).all()
    duracoes = [(f - c).total_seconds() / 60 for c, f in feitos if f > c]
    if len(duracoes) >= 3:
        return sum(duracoes) / len(duracoes)
    return float(especialidade.tempo_medio_min)


def gerar_senha(db: Session, ag: Agendamento) -> str:
    ini, fim = _intervalo(ag.data_hora.date())
    n = db.scalar(
        select(func.count()).select_from(Agendamento).where(
            Agendamento.unidade_id == ag.unidade_id,
            Agendamento.especialidade_id == ag.especialidade_id,
            Agendamento.data_hora >= ini,
            Agendamento.data_hora < fim,
            Agendamento.senha.is_not(None),
        )
    ) or 0
    return f"{ag.especialidade.prefixo_senha}-{n + 1:03d}"


def situacao(db: Session, ag: Agendamento, agora: datetime) -> dict:
    base = {
        "agendamento_id": ag.id,
        "unidade": ag.unidade.nome,
        "especialidade": ag.especialidade.nome,
        "status": ag.status,
        "senha": ag.senha,
        "consultorio": ag.consultorio,
        "posicao": None,
        "pessoas_a_frente": None,
        "tempo_estimado_min": None,
        "atualizado_em": agora,
    }
    if ag.status != StatusAgendamento.CHECKIN:
        return base
    fila = fila_do_dia(db, ag.unidade_id, ag.especialidade_id, ag.data_hora.date())
    pos = next((i for i, a in enumerate(fila, start=1) if a.id == ag.id), None)
    if pos is None:
        return base
    media = tempo_medio_min(db, ag.unidade_id, ag.especialidade, ag.data_hora.date())
    ini, fim = _intervalo(ag.data_hora.date())
    em_atendimento = db.scalar(
        select(func.count()).select_from(Agendamento).where(
            Agendamento.unidade_id == ag.unidade_id,
            Agendamento.especialidade_id == ag.especialidade_id,
            Agendamento.data_hora >= ini,
            Agendamento.data_hora < fim,
            Agendamento.status == StatusAgendamento.EM_ATENDIMENTO,
        )
    ) or 0
    estimado = (pos - 1) * media + (media / 2 if em_atendimento else 0)
    base.update(posicao=pos, pessoas_a_frente=pos - 1, tempo_estimado_min=round(estimado))
    return base


# ---------- WebSocket ----------
class GerenciadorConexoes:
    """Conexões abertas por usuário. Para várias instâncias da API, usar Redis Pub/Sub."""

    def __init__(self) -> None:
        self._conexoes: dict[int, set[WebSocket]] = defaultdict(set)

    async def conectar(self, usuario_id: int, ws: WebSocket) -> None:
        await ws.accept()
        self._conexoes[usuario_id].add(ws)

    def desconectar(self, usuario_id: int, ws: WebSocket) -> None:
        self._conexoes[usuario_id].discard(ws)

    async def enviar(self, usuario_id: int, dados: dict) -> None:
        for ws in list(self._conexoes.get(usuario_id, ())):
            try:
                await ws.send_json(dados)
            except Exception:  # conexão caiu
                self.desconectar(usuario_id, ws)


gerenciador = GerenciadorConexoes()


def _serializar(d: dict) -> dict:
    out = dict(d)
    out["status"] = d["status"].value
    out["atualizado_em"] = d["atualizado_em"].isoformat()
    return out


async def difundir_fila(db: Session, unidade_id: int, especialidade_id: int, dia: date, agora: datetime,
                        extras: list[Agendamento] | None = None) -> None:
    """Recalcula a fila e envia a situação atualizada para cada paciente conectado.

    Também dispara o push "você é o próximo" quando alguém chega à 1ª posição.
    `extras` são agendamentos que acabaram de sair da fila (ex.: chamado) e também precisam ser avisados.
    """
    fila = fila_do_dia(db, unidade_id, especialidade_id, dia)
    for ag in fila:
        info = situacao(db, ag, agora)
        if info["posicao"] == 1:
            ja_avisado = db.scalar(select(func.count()).select_from(Notificacao).where(
                Notificacao.agendamento_id == ag.id, Notificacao.tipo == TipoNotificacao.FILA_PROXIMO))
            if not ja_avisado:
                notificar_agora(db, ag.usuario, TipoNotificacao.FILA_PROXIMO, "Você é o próximo!",
                                f"Fique perto do consultório. Sua senha é {ag.senha}.", agora, ag.id)
        await gerenciador.enviar(ag.usuario_id, _serializar(info))
    for ag in extras or []:
        await gerenciador.enviar(ag.usuario_id, _serializar(situacao(db, ag, agora)))
    db.commit()

