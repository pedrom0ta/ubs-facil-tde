from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWTError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decodificar_token
from app.models import Papel, Usuario

_bearer = HTTPBearer(auto_error=False)


def usuario_do_token(token: str, db: Session) -> Usuario | None:
    try:
        payload = decodificar_token(token)
        return db.get(Usuario, int(payload["sub"]))
    except (PyJWTError, KeyError, ValueError):
        return None


def usuario_atual(
    cred: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> Usuario:
    if cred is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Faça login para continuar.")
    usuario = usuario_do_token(cred.credentials, db)
    if usuario is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sessão expirada. Entre novamente.")
    return usuario


def somente_recepcao(usuario: Usuario = Depends(usuario_atual)) -> Usuario:
    if usuario.papel != Papel.RECEPCAO:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Acesso restrito à recepção da unidade.")
    return usuario
