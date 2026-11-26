import os
import tempfile
from datetime import datetime

_db = os.path.join(tempfile.mkdtemp(), "teste.db")
os.environ["DATABASE_URL"] = f"sqlite:///{_db}"
os.environ["LEMBRETES_ATIVOS"] = "false"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.clock import get_now  # noqa: E402
from app.core.database import Base, SessionLocal, engine  # noqa: E402
from app.core.security import limitador_login  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Especialidade, Papel, TipoRegistro, Unidade, Usuario  # noqa: E402
from app.core.security import hash_senha  # noqa: E402
from app.seed import gerar_cns  # noqa: E402


class Relogio:
    """Relógio controlável: segunda-feira, 09/11/2026, 07:00."""

    def __init__(self) -> None:
        self.agora = datetime(2026, 11, 9, 7, 0)

    def __call__(self) -> datetime:
        return self.agora


CPF_MARIA = "52998224725"
CPF_JOAO = "39053344705"
CPF_RECEPCAO = "11144477735"
SENHA = "senhaSegura1"


@pytest.fixture()
def relogio():
    r = Relogio()
    app.dependency_overrides[get_now] = r
    yield r
    app.dependency_overrides.clear()


@pytest.fixture()
def client(relogio):
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    limitador_login._falhas.clear()
    with SessionLocal() as db:
        db.add_all([
            Unidade(nome="UBS Centro", endereco="Rua A, 1", cnes="2077485"),
            Unidade(nome="UBS Vila Nova", endereco="Rua B, 2"),
            Especialidade(nome="Clínica Geral", tempo_medio_min=15, prefixo_senha="C"),
            Especialidade(nome="Vacinação", tempo_medio_min=5, prefixo_senha="V", tipo_registro=TipoRegistro.VACINA),
            Usuario(nome="Recepção", cpf=CPF_RECEPCAO, cns=gerar_cns(99), senha_hash=hash_senha(SENHA),
                    papel=Papel.RECEPCAO, consentimento_em=relogio.agora),
        ])
        db.commit()
    with TestClient(app) as c:
        yield c


def cadastrar(client, cpf=CPF_MARIA, n=1, nome="Maria Silva"):
    r = client.post("/auth/cadastro", json={
        "nome": nome, "cpf": cpf, "cns": gerar_cns(n), "celular": "(11) 98765-4321",
        "senha": SENHA, "aceite_termos": True,
    })
    assert r.status_code == 201, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture()
def maria(client):
    return cadastrar(client)


@pytest.fixture()
def joao(client):
    return cadastrar(client, CPF_JOAO, 2, "João Souza")


@pytest.fixture()
def recepcao(client):
    r = client.post("/auth/login", json={"cpf": CPF_RECEPCAO, "senha": SENHA})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def agendar(client, headers, quando="2026-11-10T08:00:00", unidade=1, esp=1):
    return client.post("/agendamentos", headers=headers,
                       json={"unidade_id": unidade, "especialidade_id": esp, "data_hora": quando})
