"""Hash de senha (bcrypt), tokens JWT e validação de CPF / CNS."""
import re
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.core.config import settings


# ---------- Senhas ----------
def hash_senha(senha: str) -> str:
    return bcrypt.hashpw(senha.encode(), bcrypt.gensalt()).decode()


def verificar_senha(senha: str, senha_hash: str) -> bool:
    try:
        return bcrypt.checkpw(senha.encode(), senha_hash.encode())
    except ValueError:
        return False


# ---------- JWT ----------
def criar_token(usuario_id: int, papel: str) -> str:
    exp = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expira_min)
    payload = {"sub": str(usuario_id), "papel": papel, "exp": exp}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decodificar_token(token: str) -> dict:
    """Lança jwt.PyJWTError se o token for inválido ou expirado."""
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])


# ---------- Documentos ----------
def somente_digitos(valor: str) -> str:
    return re.sub(r"\D", "", valor or "")


def cpf_valido(cpf: str) -> bool:
    d = somente_digitos(cpf)
    if len(d) != 11 or d == d[0] * 11:
        return False
    for tam in (9, 10):
        soma = sum(int(d[i]) * (tam + 1 - i) for i in range(tam))
        dv = (soma * 10) % 11 % 10
        if dv != int(d[tam]):
            return False
    return True


def cns_valido(cns: str) -> bool:
    """Validação oficial do Cartão Nacional de Saúde (soma ponderada módulo 11)."""
    d = somente_digitos(cns)
    if len(d) != 15 or d[0] not in "123456789":
        return False
    soma = sum(int(d[i]) * (15 - i) for i in range(15))
    return soma % 11 == 0


# ---------- Limite de tentativas de login (anti força bruta) ----------
class LimitadorLogin:
    """Em memória. Em produção com várias instâncias, trocar por Redis."""

    def __init__(self) -> None:
        self._falhas: dict[str, list[float]] = defaultdict(list)

    def _recentes(self, chave: str) -> list[float]:
        limite = time.time() - settings.login_bloqueio_min * 60
        self._falhas[chave] = [t for t in self._falhas[chave] if t > limite]
        return self._falhas[chave]

    def bloqueado(self, chave: str) -> bool:
        return len(self._recentes(chave)) >= settings.login_max_tentativas

    def registrar_falha(self, chave: str) -> None:
        self._falhas[chave].append(time.time())

    def limpar(self, chave: str) -> None:
        self._falhas.pop(chave, None)


limitador_login = LimitadorLogin()
