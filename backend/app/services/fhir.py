"""Adaptador HL7 FHIR R4 (preparação para a integração com o e-SUS / RNDS — Fase 07).

Converte as entidades internas em recursos FHIR. O envio efetivo à RNDS exige
credenciamento do município e certificado digital; por isso este módulo expõe
somente a conversão, que pode ser consumida por um serviço de integração.
"""
from datetime import timedelta

from app.models import Agendamento, StatusAgendamento, Usuario

_STATUS_FHIR = {
    StatusAgendamento.AGENDADO: "booked",
    StatusAgendamento.CONFIRMADO: "booked",
    StatusAgendamento.CHECKIN: "checked-in",
    StatusAgendamento.EM_ATENDIMENTO: "arrived",
    StatusAgendamento.REALIZADO: "fulfilled",
    StatusAgendamento.CANCELADO: "cancelled",
    StatusAgendamento.FALTOU: "noshow",
}

# Sistemas de identificadores usados pela RNDS
SISTEMA_CPF = "https://saude.gov.br/fhir/sid/cpf"
SISTEMA_CNS = "https://saude.gov.br/fhir/sid/cns"
SISTEMA_CNES = "https://saude.gov.br/fhir/sid/cnes"


def paciente(u: Usuario) -> dict:
    return {
        "resourceType": "Patient",
        "id": str(u.id),
        "identifier": [
            {"system": SISTEMA_CPF, "value": u.cpf},
            {"system": SISTEMA_CNS, "value": u.cns},
        ],
        "name": [{"text": u.nome}],
        "telecom": [{"system": "phone", "value": u.celular}] if u.celular else [],
    }


def consulta(a: Agendamento) -> dict:
    fim = a.data_hora + timedelta(minutes=a.especialidade.tempo_medio_min)
    local = {"display": a.unidade.nome}
    if a.unidade.cnes:
        local["identifier"] = {"system": SISTEMA_CNES, "value": a.unidade.cnes}
    return {
        "resourceType": "Appointment",
        "id": str(a.id),
        "status": _STATUS_FHIR[a.status],
        "serviceType": [{"text": a.especialidade.nome}],
        "start": a.data_hora.isoformat(),
        "end": fim.isoformat(),
        "created": a.criado_em.isoformat() if a.criado_em else None,
        "participant": [
            {"actor": {"reference": f"Patient/{a.usuario_id}", "display": a.usuario.nome}, "status": "accepted"},
            {"actor": local, "status": "accepted"},
        ],
    }
