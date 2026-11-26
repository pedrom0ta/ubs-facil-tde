"""RF01, RF02, RF10 e requisitos de segurança/LGPD."""
from app.core.security import cns_valido, cpf_valido
from app.seed import gerar_cns
from tests.conftest import CPF_JOAO, CPF_MARIA, SENHA, agendar, cadastrar


def test_validacao_de_documentos():
    assert cpf_valido("529.982.247-25") and cpf_valido(CPF_JOAO)
    assert not cpf_valido("111.111.111-11") and not cpf_valido("529.982.247-26")
    assert cns_valido(gerar_cns(1)) and not cns_valido("123456789012345")


def test_cadastro_e_login(client):
    cadastrar(client)
    r = client.post("/auth/login", json={"cpf": "529.982.247-25", "senha": SENHA})
    assert r.status_code == 200
    assert r.json()["usuario"]["nome"] == "Maria Silva"
    assert r.json()["usuario"]["celular"] == "11987654321"


def test_cadastro_exige_consentimento_lgpd(client):
    r = client.post("/auth/cadastro", json={"nome": "Maria", "cpf": CPF_MARIA, "cns": gerar_cns(1),
                                            "senha": SENHA, "aceite_termos": False})
    assert r.status_code == 422
    assert "Termos" in r.json()["detail"]


def test_cadastro_rejeita_documentos_invalidos_e_duplicados(client):
    r = client.post("/auth/cadastro", json={"nome": "Maria", "cpf": "123.456.789-00", "cns": gerar_cns(1),
                                            "senha": SENHA, "aceite_termos": True})
    assert r.status_code == 422 and r.json()["detail"] == "CPF inválido"
    cadastrar(client)
    r = client.post("/auth/cadastro", json={"nome": "Outra", "cpf": CPF_MARIA, "cns": gerar_cns(5),
                                            "senha": SENHA, "aceite_termos": True})
    assert r.status_code == 409


def test_senha_guardada_com_hash(client):
    from app.core.database import SessionLocal
    from app.models import Usuario

    cadastrar(client)
    with SessionLocal() as db:
        u = db.query(Usuario).filter_by(cpf=CPF_MARIA).one()
        assert u.senha_hash.startswith("$2") and SENHA not in u.senha_hash


def test_bloqueio_apos_tentativas_erradas(client):
    cadastrar(client)
    for _ in range(5):
        assert client.post("/auth/login", json={"cpf": CPF_MARIA, "senha": "errada123"}).status_code == 401
    assert client.post("/auth/login", json={"cpf": CPF_MARIA, "senha": SENHA}).status_code == 429


def test_rotas_exigem_autenticacao(client):
    assert client.get("/agendamentos").status_code == 401
    assert client.get("/perfil", headers={"Authorization": "Bearer token-falso"}).status_code == 401


def test_paciente_nao_acessa_dados_de_outro(client, maria, joao):
    ag = agendar(client, maria).json()
    assert client.get(f"/agendamentos/{ag['id']}", headers=joao).status_code == 404
    assert client.post(f"/agendamentos/{ag['id']}/cancelar", headers=joao).status_code == 404


def test_paciente_nao_acessa_recepcao(client, maria):
    r = client.post("/recepcao/chamar-proximo", headers=maria,
                    json={"unidade_id": 1, "especialidade_id": 1, "consultorio": "Consultório 1"})
    assert r.status_code == 403


def test_perfil_atualizar_e_favoritas(client, maria):
    r = client.patch("/perfil", headers=maria, json={"nome": "Maria S. Oliveira", "notificacoes_ativas": False})
    assert r.json()["nome"] == "Maria S. Oliveira" and r.json()["notificacoes_ativas"] is False
    assert client.put("/perfil/favoritas/2", headers=maria).json()[0]["nome"] == "UBS Vila Nova"
    assert client.delete("/perfil/favoritas/2", headers=maria).json() == []
    assert client.put("/perfil/fcm-token", headers=maria, json={"token": "token-do-dispositivo-123"}).status_code == 204


def test_exportar_e_excluir_conta(client, maria):
    agendar(client, maria)
    dados = client.get("/perfil/exportar", headers=maria).json()
    assert dados["titular"]["resourceType"] == "Patient" and len(dados["agendamentos"]) == 1
    assert client.delete("/perfil", headers=maria).status_code == 204
    assert client.get("/perfil", headers=maria).status_code == 401


def test_cabecalhos_de_seguranca(client):
    r = client.get("/saude")
    assert r.headers["Cache-Control"] == "no-store" and r.headers["X-Frame-Options"] == "DENY"
