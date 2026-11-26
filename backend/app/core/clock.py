"""Relógio da aplicação.

Todas as regras de horário usam `agora()` (horário local da UBS, sem fuso no objeto),
o que permite substituir o relógio nos testes via `app.dependency_overrides[get_now]`.
"""
from datetime import datetime
from zoneinfo import ZoneInfo

from app.core.config import settings

_TZ = ZoneInfo(settings.timezone)


def agora() -> datetime:
    return datetime.now(_TZ).replace(tzinfo=None, microsecond=0)


def get_now() -> datetime:
    """Dependência FastAPI."""
    return agora()
