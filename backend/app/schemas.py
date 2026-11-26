"""Contratos de entrada e saída da API (Pydantic v2)."""
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.security import cns_valido, cpf_valido, somente_digitos
from app.models import StatusAgendamento, TipoNotificacao, TipoRegistro


class _Base(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------- Auth ----------
class CadastroIn(BaseModel):
    nome: str = Field(min_length=3, max_length=120)
    cpf: str
    cns: str
    celular: str | None = None
    senha: str = Field(min_length=8, max_length=72)
    aceite_termos: bool

    @field_validator("cpf")
    @classmethod
    def _cpf(cls, v: str) -> str:
        if not cpf_valido(v):
            raise ValueError("CPF inválido")
        return somente_digitos(v)

    @field_validator("cns")
    @classmethod
    def _cns(cls, v: str) -> str:
        if not cns_valido(v):
            raise ValueError("Cartão Nacional de Saúde inválido")
        return somente_digitos(v)

    @field_validator("celular")
    @classmethod
    def _celular(cls, v: str | None) -> str | None:
        if v is None or v == "":
            return None
        d = somente_digitos(v)
        if len(d) not in (10, 11):
            raise ValueError("Celular inválido")
        return d

    @field_validator("aceite_termos")
    @classmethod
    def _aceite(cls, v: bool) -> bool:
        if not v:
            raise ValueError("É necessário aceitar os Termos de Uso e a Política de Privacidade")
        return v


class LoginIn(BaseModel):
    cpf: str
    senha: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: "UsuarioOut"


# ---------- Perfil ----------
class UsuarioOut(_Base):
    id: int
    nome: str
    cpf: str
    cns: str
    celular: str | None
    papel: str
    notificacoes_ativas: bool


class PerfilUpdateIn(BaseModel):
    nome: str | None = Field(default=None, min_length=3, max_length=120)
    celular: str | None = None
    notificacoes_ativas: bool | None = None


class FcmTokenIn(BaseModel):
    token: str = Field(min_length=10, max_length=255)


# ---------- Catálogo ----------
class UnidadeOut(_Base):
    id: int
    nome: str
    endereco: str


class EspecialidadeOut(_Base):
    id: int
    nome: str


class HorarioOut(BaseModel):
    data_hora: datetime
    hora: str
    disponivel: bool


class DiaDisponivelOut(BaseModel):
    data: date
    vagas: int


# ---------- Agendamentos ----------
class AgendamentoIn(BaseModel):
    unidade_id: int
    especialidade_id: int
    data_hora: datetime


class ReagendamentoIn(BaseModel):
    data_hora: datetime


class AgendamentoOut(_Base):
    id: int
    data_hora: datetime
    status: StatusAgendamento
    senha: str | None
    consultorio: str | None
    unidade: UnidadeOut
    especialidade: EspecialidadeOut


# ---------- Fila ----------
class FilaOut(BaseModel):
    agendamento_id: int
    unidade: str
    especialidade: str
    status: StatusAgendamento
    senha: str | None
    posicao: int | None = Field(description="1 = próximo a ser chamado; None quando já foi chamado")
    pessoas_a_frente: int | None
    tempo_estimado_min: int | None
    consultorio: str | None
    atualizado_em: datetime


class ChamarProximoIn(BaseModel):
    unidade_id: int
    especialidade_id: int
    consultorio: str = Field(min_length=1, max_length=30)


class FinalizarIn(BaseModel):
    observacoes: str | None = None
    compareceu: bool = True


# ---------- Histórico ----------
class RegistroOut(_Base):
    id: int
    tipo: TipoRegistro
    descricao: str
    data_hora: datetime
    unidade: UnidadeOut


# ---------- Notificações ----------
class NotificacaoOut(_Base):
    id: int
    tipo: TipoNotificacao
    titulo: str
    mensagem: str
    agendamento_id: int | None
    enviada_em: datetime | None
    lida: bool


TokenOut.model_rebuild()
