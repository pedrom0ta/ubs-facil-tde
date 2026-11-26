"""RF06 Check-in, RF07 Fila em tempo real, RF09 Histórico."""
from datetime import datetime

from tests.conftest import agendar


def _checkin(client, h, ag_id):
    return client.post(f"/agendamentos/{ag_id}/checkin", headers=h)


def test_checkin_respeita_janela(client, maria, relogio):
    ag = agendar(client, maria, "2026-11-10T10:00:00").json()
    relogio.agora = datetime(2026, 11, 10, 7, 30)
    r = _checkin(client, maria, ag["id"])
    assert r.status_code == 409 and "abre" in r.json()["detail"]
    relogio.agora = datetime(2026, 11, 10, 10, 31)
    assert _checkin(client, maria, ag["id"]).status_code == 409
    relogio.agora = datetime(2026, 11, 10, 9, 0)
    r = _checkin(client, maria, ag["id"])
    assert r.status_code == 200 and r.json()["senha"] == "C-001" and r.json()["posicao"] == 1


def test_fila_ordem_posicao_e_tempo(client, maria, joao, relogio):
    a_m = agendar(client, maria, "2026-11-10T08:30:00").json()
    a_j = agendar(client, joao, "2026-11-10T08:00:00").json()
    relogio.agora = datetime(2026, 11, 10, 7, 40)
    _checkin(client, maria, a_m["id"])    # Maria chegou primeiro...
    _checkin(client, joao, a_j["id"])     # ...mas João tem horário mais cedo
    m = client.get("/fila/minha", headers=maria).json()
    j = client.get("/fila/minha", headers=joao).json()
    assert j["posicao"] == 1 and m["posicao"] == 2
    assert m["pessoas_a_frente"] == 1 and m["tempo_estimado_min"] == 15
    assert m["senha"] == "C-001" and j["senha"] == "C-002"


def test_recepcao_chama_e_fila_anda(client, maria, joao, recepcao, relogio):
    a_j = agendar(client, joao, "2026-11-10T08:00:00").json()
    a_m = agendar(client, maria, "2026-11-10T08:30:00").json()
    relogio.agora = datetime(2026, 11, 10, 7, 50)
    _checkin(client, joao, a_j["id"])
    _checkin(client, maria, a_m["id"])

    r = client.post("/recepcao/chamar-proximo", headers=recepcao,
                    json={"unidade_id": 1, "especialidade_id": 1, "consultorio": "Consultório 2"})
    assert r.json()["id"] == a_j["id"] and r.json()["status"] == "EM_ATENDIMENTO"

    m = client.get("/fila/minha", headers=maria).json()
    assert m["posicao"] == 1 and m["tempo_estimado_min"] == 8  # metade do atendimento em curso
    j = client.get("/fila/minha", headers=joao).json()
    assert j["status"] == "EM_ATENDIMENTO" and j["consultorio"] == "Consultório 2"

    tipos = {n["tipo"] for n in client.get("/notificacoes", headers=maria).json()}
    assert "FILA_PROXIMO" in tipos
    assert "FILA_CHAMADO" in {n["tipo"] for n in client.get("/notificacoes", headers=joao).json()}


def test_finalizar_vai_para_historico(client, joao, recepcao, relogio):
    a = agendar(client, joao, "2026-11-10T08:00:00", esp=2).json()
    relogio.agora = datetime(2026, 11, 10, 7, 55)
    _checkin(client, joao, a["id"])
    client.post("/recepcao/chamar-proximo", headers=recepcao,
                json={"unidade_id": 1, "especialidade_id": 2, "consultorio": "Sala de vacina"})
    relogio.agora = datetime(2026, 11, 10, 8, 3)
    r = client.post(f"/recepcao/agendamentos/{a['id']}/finalizar", headers=recepcao, json={})
    assert r.json()["status"] == "REALIZADO"

    hist = client.get("/historico", headers=joao).json()
    assert len(hist) == 1 and hist[0]["tipo"] == "VACINA" and hist[0]["descricao"] == "Vacinação"
    assert client.get("/historico", params={"tipo": "CONSULTA"}, headers=joao).json() == []
    assert client.get("/fila/minha", headers=joao).status_code == 404


def test_cancelar_na_fila_faz_os_outros_subirem(client, maria, joao, relogio):
    a_j = agendar(client, joao, "2026-11-10T08:00:00").json()
    a_m = agendar(client, maria, "2026-11-10T08:30:00").json()
    relogio.agora = datetime(2026, 11, 10, 7, 50)
    _checkin(client, joao, a_j["id"])
    _checkin(client, maria, a_m["id"])
    client.post(f"/agendamentos/{a_j['id']}/cancelar", headers=joao)
    assert client.get("/fila/minha", headers=maria).json()["posicao"] == 1


def test_websocket_recebe_atualizacoes(client, maria, joao, recepcao, relogio):
    a_j = agendar(client, joao, "2026-11-10T08:00:00").json()
    a_m = agendar(client, maria, "2026-11-10T08:30:00").json()
    relogio.agora = datetime(2026, 11, 10, 7, 50)
    _checkin(client, joao, a_j["id"])
    _checkin(client, maria, a_m["id"])
    token = maria["Authorization"].split()[1]
    with client.websocket_connect(f"/fila/ws?token={token}") as ws:
        primeira = ws.receive_json()
        assert primeira["posicao"] == 2
        client.post("/recepcao/chamar-proximo", headers=recepcao,
                    json={"unidade_id": 1, "especialidade_id": 1, "consultorio": "Consultório 1"})
        atualizacao = ws.receive_json()
        assert atualizacao["posicao"] == 1


def test_websocket_recusa_token_invalido(client):
    import pytest
    from starlette.websockets import WebSocketDisconnect

    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/fila/ws?token=invalido") as ws:
            ws.receive_json()
