"""Configurações da aplicação, lidas de variáveis de ambiente (ou arquivo .env)."""
import os
from dataclasses import dataclass, field
from pathlib import Path


def _load_dotenv() -> None:
    env = Path(__file__).resolve().parents[2] / ".env"
    if not env.exists():
        return
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip())


_load_dotenv()


def _bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).lower() in {"1", "true", "yes", "sim"}


@dataclass(frozen=True)
class Settings:
    app_name: str = "UBS Fácil API"
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./ubs_facil.db")
    jwt_secret: str = os.getenv("JWT_SECRET", "dev-apenas-troque-este-segredo-em-producao-2026")
    jwt_algorithm: str = "HS256"
    jwt_expira_min: int = int(os.getenv("JWT_EXPIRA_MIN", "720"))
    timezone: str = os.getenv("TZ_UBS", "America/Sao_Paulo")
    cors_origins: list[str] = field(
        default_factory=lambda: os.getenv("CORS_ORIGINS", "*").split(",")
    )
    # Janela permitida para o check-in digital, relativa ao horário da consulta
    checkin_antes_min: int = int(os.getenv("CHECKIN_ANTES_MIN", "120"))
    checkin_depois_min: int = int(os.getenv("CHECKIN_DEPOIS_MIN", "30"))
    # Agenda das unidades
    agenda_dias_a_frente: int = int(os.getenv("AGENDA_DIAS_A_FRENTE", "30"))
    # Notificações
    lembretes_ativos: bool = _bool("LEMBRETES_ATIVOS", True)
    lembretes_intervalo_seg: int = int(os.getenv("LEMBRETES_INTERVALO_SEG", "60"))
    firebase_credenciais: str | None = os.getenv("FIREBASE_CREDENCIAIS")  # caminho do JSON da conta de serviço
    # Proteção contra força bruta no login
    login_max_tentativas: int = int(os.getenv("LOGIN_MAX_TENTATIVAS", "5"))
    login_bloqueio_min: int = int(os.getenv("LOGIN_BLOQUEIO_MIN", "15"))


settings = Settings()
