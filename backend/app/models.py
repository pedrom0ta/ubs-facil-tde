"""Modelo de dados (SQLAlchemy 2.0). Funciona com SQLite (dev) e PostgreSQL (produção)."""
import enum
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Table,
    Text,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.clock import agora
from app.core.database import Base


class Papel(str, enum.Enum):
    PACIENTE = "PACIENTE"
    RECEPCAO = "RECEPCAO"


class StatusAgendamento(str, enum.Enum):
    AGENDADO = "AGENDADO"
    CONFIRMADO = "CONFIRMADO"          # presença confirmada pelo lembrete
    CHECKIN = "CHECKIN"                # paciente chegou e está na fila
    EM_ATENDIMENTO = "EM_ATENDIMENTO"  # senha chamada
    REALIZADO = "REALIZADO"
    CANCELADO = "CANCELADO"
    FALTOU = "FALTOU"


STATUS_ATIVOS = (
    StatusAgendamento.AGENDADO,
    StatusAgendamento.CONFIRMADO,
    StatusAgendamento.CHECKIN,
    StatusAgendamento.EM_ATENDIMENTO,
)


class TipoRegistro(str, enum.Enum):
    CONSULTA = "CONSULTA"
    EXAME = "EXAME"
    VACINA = "VACINA"


class TipoNotificacao(str, enum.Enum):
    LEMBRETE_24H = "LEMBRETE_24H"
    LEMBRETE_2H = "LEMBRETE_2H"
    FILA_PROXIMO = "FILA_PROXIMO"
    FILA_CHAMADO = "FILA_CHAMADO"


favoritas = Table(
    "unidades_favoritas",
    Base.metadata,
    Column("usuario_id", ForeignKey("usuarios.id", ondelete="CASCADE"), primary_key=True),
    Column("unidade_id", ForeignKey("unidades.id", ondelete="CASCADE"), primary_key=True),
)


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(120))
    cpf: Mapped[str] = mapped_column(String(11), unique=True, index=True)
    cns: Mapped[str] = mapped_column(String(15), unique=True, index=True)
    celular: Mapped[str | None] = mapped_column(String(15))
    senha_hash: Mapped[str] = mapped_column(String(100))
    papel: Mapped[Papel] = mapped_column(Enum(Papel), default=Papel.PACIENTE)
    consentimento_em: Mapped[datetime] = mapped_column(DateTime)  # aceite dos termos (LGPD)
    notificacoes_ativas: Mapped[bool] = mapped_column(Boolean, default=True)
    fcm_token: Mapped[str | None] = mapped_column(String(255))
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=agora)

    agendamentos: Mapped[list["Agendamento"]] = relationship(back_populates="usuario", cascade="all, delete-orphan")
    registros: Mapped[list["RegistroHistorico"]] = relationship(back_populates="usuario", cascade="all, delete-orphan")
    notificacoes: Mapped[list["Notificacao"]] = relationship(back_populates="usuario", cascade="all, delete-orphan")
    unidades_favoritas: Mapped[list["Unidade"]] = relationship(secondary=favoritas)


class Unidade(Base):
    __tablename__ = "unidades"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(120))
    endereco: Mapped[str] = mapped_column(String(200))
    cnes: Mapped[str | None] = mapped_column(String(7))  # código no Cadastro Nacional de Estabelecimentos de Saúde


class Especialidade(Base):
    __tablename__ = "especialidades"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(80))
    tempo_medio_min: Mapped[int] = mapped_column(Integer, default=15)  # usado na estimativa da fila
    prefixo_senha: Mapped[str] = mapped_column(String(2), default="C")
    tipo_registro: Mapped[TipoRegistro] = mapped_column(Enum(TipoRegistro), default=TipoRegistro.CONSULTA)


class Agendamento(Base):
    __tablename__ = "agendamentos"
    __table_args__ = (
        # Um horário só pode ter um agendamento ativo por unidade + especialidade
        Index(
            "uq_horario_ativo",
            "unidade_id",
            "especialidade_id",
            "data_hora",
            unique=True,
            sqlite_where=text("status NOT IN ('CANCELADO','FALTOU')"),
            postgresql_where=text("status NOT IN ('CANCELADO','FALTOU')"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id", ondelete="CASCADE"), index=True)
    unidade_id: Mapped[int] = mapped_column(ForeignKey("unidades.id"))
    especialidade_id: Mapped[int] = mapped_column(ForeignKey("especialidades.id"))
    data_hora: Mapped[datetime] = mapped_column(DateTime, index=True)
    status: Mapped[StatusAgendamento] = mapped_column(Enum(StatusAgendamento), default=StatusAgendamento.AGENDADO)
    senha: Mapped[str | None] = mapped_column(String(8))
    consultorio: Mapped[str | None] = mapped_column(String(30))
    criado_em: Mapped[datetime] = mapped_column(DateTime, default=agora)
    confirmado_em: Mapped[datetime | None] = mapped_column(DateTime)
    checkin_em: Mapped[datetime | None] = mapped_column(DateTime)
    chamado_em: Mapped[datetime | None] = mapped_column(DateTime)
    finalizado_em: Mapped[datetime | None] = mapped_column(DateTime)
    cancelado_em: Mapped[datetime | None] = mapped_column(DateTime)

    usuario: Mapped[Usuario] = relationship(back_populates="agendamentos")
    unidade: Mapped[Unidade] = relationship()
    especialidade: Mapped[Especialidade] = relationship()


class RegistroHistorico(Base):
    __tablename__ = "registros_historico"

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id", ondelete="CASCADE"), index=True)
    tipo: Mapped[TipoRegistro] = mapped_column(Enum(TipoRegistro))
    descricao: Mapped[str] = mapped_column(String(160))
    unidade_id: Mapped[int] = mapped_column(ForeignKey("unidades.id"))
    data_hora: Mapped[datetime] = mapped_column(DateTime)
    agendamento_id: Mapped[int | None] = mapped_column(ForeignKey("agendamentos.id", ondelete="SET NULL"))
    observacoes: Mapped[str | None] = mapped_column(Text)

    usuario: Mapped[Usuario] = relationship(back_populates="registros")
    unidade: Mapped[Unidade] = relationship()


class Notificacao(Base):
    __tablename__ = "notificacoes"

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id", ondelete="CASCADE"), index=True)
    agendamento_id: Mapped[int | None] = mapped_column(ForeignKey("agendamentos.id", ondelete="CASCADE"))
    tipo: Mapped[TipoNotificacao] = mapped_column(Enum(TipoNotificacao))
    titulo: Mapped[str] = mapped_column(String(80))
    mensagem: Mapped[str] = mapped_column(String(255))
    enviar_em: Mapped[datetime] = mapped_column(DateTime, index=True)
    enviada_em: Mapped[datetime | None] = mapped_column(DateTime)
    cancelada: Mapped[bool] = mapped_column(Boolean, default=False)
    lida: Mapped[bool] = mapped_column(Boolean, default=False)

    usuario: Mapped[Usuario] = relationship(back_populates="notificacoes")
