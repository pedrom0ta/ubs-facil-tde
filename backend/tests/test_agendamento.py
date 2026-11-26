"""RF03 Agendar, RF04 Cancelar, RF05 Reagendar, RF08 Lembretes."""
from datetime import datetime

from app.core.database import SessionLocal
from app.models import Notificacao
from app.services.notificacoes import enviar_pendentes
from tests.conftest import agendar


def test_lista_horarios_bloqueia_ocupados_e_passados(client, maria, joao, relogio):
    agendar(client, maria, "2026-11-09T08:00:00")
    relogio.agora = datetime(2026, 11, 9, 7, 45)
    hs = {h["hora"]: h["disponivel"] for h in client.get(
        "/unidades/1/horarios", params={"especialidade_id": 1, "data": "2026-11-09"}, headers=joao).json()}
    assert hs["07:30"] is False  # já passou
    assert hs["08:00"] is False  # ocupado pela Maria
    assert hs["08:30"] is True
    sabado = client.get("/unidades/1/horarios", params={"especialidade_id": 1, "data": "2026-11-14"}, headers=joao)
    assert sabado.json() == []


def test_agendar_com_sucesso(client, maria):
    r = agendar(client, maria)
    assert r.status_code == 201
    corpo = r.json()
    assert corpo["status"] == "AGENDADO" and corpo["unidade"]["nome"] == "UBS Centro"
    assert client.get("/agendamentos", headers=maria).json()[0]["id"] == corpo["id"]


def test_prevencao_de_erros_no_agendamento(client, maria):
    assert agendar(client, maria, "2026-11-08T08:00:00").status_code == 422  # passado
    assert agendar(client, maria, "2026-11-14T08:00:00").status_code == 422  # sábado
    assert agendar(client, maria, "2026-11-10T08:15:00").status_code == 422  # fora da grade
    assert agendar(client, maria, "2027-03-01T08:00:00").status_code == 422  # longe demais
    assert agendar(client, maria, "2026-11-10T08:00:00", unidade=99).status_code == 404


def test_horario_nao_pode_ser_reservado_duas_vezes(client, maria, joao):
    assert agendar(client, maria).status_code == 201
    r = agendar(client, joao)
    assert r.status_code == 409 and "reservado" in r.json()["detail"]
    # outra especialidade no mesmo horário é permitida
    assert agendar(client, joao, esp=2).status_code == 201


def test_paciente_nao_marca_duas_consultas_futuras_na_mesma_especialidade(client, maria):
    agendar(client, maria)
    r = agendar(client, maria, "2026-11-11T09:00:00")
    assert r.status_code == 409 and "Reagende" in r.json()["detail"]


def test_cancelar_libera_a_vaga(client, maria, joao):
    ag = agendar(client, maria).json()
    r = client.post(f"/agendamentos/{ag['id']}/cancelar", headers=maria)
    assert r.json()["status"] == "CANCELADO"
    assert agendar(client, joao).status_code == 201  # vaga devolvida
    assert client.get("/agendamentos", headers=maria).json() == []
    assert client.post(f"/agendamentos/{ag['id']}/cancelar", headers=maria).status_code == 409


def test_reagendar(client, maria, joao):
    ag = agendar(client, maria).json()
    agendar(client, joao, "2026-11-10T09:00:00")
    r = client.patch(f"/agendamentos/{ag['id']}", headers=maria, json={"data_hora": "2026-11-10T09:00:00"})
    assert r.status_code == 409
    r = client.patch(f"/agendamentos/{ag['id']}", headers=maria, json={"data_hora": "2026-11-12T10:30:00"})
    assert r.status_code == 200 and r.json()["data_hora"] == "2026-11-12T10:30:00"
    assert agendar(client, joao, "2026-11-10T08:00:00", esp=2).status_code == 201


def test_lembretes_24h_e_2h(client, maria, relogio):
    ag = agendar(client, maria, "2026-11-11T08:00:00").json()
    with SessionLocal() as db:
        tipos = sorted((n.tipo.value, n.enviar_em) for n in db.query(Notificacao).filter_by(agendamento_id=ag["id"]))
    assert tipos == [("LEMBRETE_24H", datetime(2026, 11, 10, 8, 0)), ("LEMBRETE_2H", datetime(2026, 11, 11, 6, 0))]

    with SessionLocal() as db:
        assert enviar_pendentes(db, datetime(2026, 11, 10, 8, 1)) == 1
    notifs = client.get("/notificacoes", headers=maria).json()
    assert len(notifs) == 1 and "amanhã" in notifs[0]["mensagem"]
    assert client.post(f"/notificacoes/{notifs[0]['id']}/lida", headers=maria).status_code == 204

    relogio.agora = datetime(2026, 11, 10, 8, 2)
    assert client.post(f"/agendamentos/{ag['id']}/confirmar", headers=maria).json()["status"] == "CONFIRMADO"


def test_cancelamento_cancela_lembretes(client, maria):
    ag = agendar(client, maria, "2026-11-11T08:00:00").json()
    client.post(f"/agendamentos/{ag['id']}/cancelar", headers=maria)
    with SessionLocal() as db:
        assert enviar_pendentes(db, datetime(2026, 11, 12, 0, 0)) == 0


def test_reagendar_recria_lembretes(client, maria):
    ag = agendar(client, maria, "2026-11-11T08:00:00").json()
    client.patch(f"/agendamentos/{ag['id']}", headers=maria, json={"data_hora": "2026-11-13T14:00:00"})
    with SessionLocal() as db:
        ativas = db.query(Notificacao).filter_by(agendamento_id=ag["id"], cancelada=False).all()
    assert sorted(n.enviar_em for n in ativas) == [datetime(2026, 11, 12, 14, 0), datetime(2026, 11, 13, 12, 0)]


def test_recurso_fhir(client, maria):
    ag = agendar(client, maria).json()
    r = client.get(f"/agendamentos/{ag['id']}/fhir", headers=maria).json()
    assert r["resourceType"] == "Appointment" and r["status"] == "booked"
    assert r["end"] == "2026-11-10T08:15:00"
