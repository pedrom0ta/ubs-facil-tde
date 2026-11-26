"""RF01 Cadastro e RF02 Login."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.clock import get_now
from app.core.database import get_db
from app.core.security import criar_token, hash_senha, limitador_login, somente_digitos, verificar_senha
from app.models import Usuario
from app.schemas import CadastroIn, LoginIn, TokenOut, UsuarioOut

router = APIRouter(prefix="/auth", tags=["Autenticação"])


def _token(u: Usuario) -> TokenOut:
    return TokenOut(access_token=criar_token(u.id, u.papel.value), usuario=UsuarioOut.model_validate(u))


@router.post("/cadastro", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def cadastrar(dados: CadastroIn, db: Session = Depends(get_db), agora: datetime = Depends(get_now)):
    existe = db.scalar(select(Usuario).where(or_(Usuario.cpf == dados.cpf, Usuario.cns == dados.cns)))
    if existe:
        raise HTTPException(status.HTTP_409_CONFLICT, "Já existe uma conta com este CPF ou Cartão Nacional de Saúde.")
    u = Usuario(
        nome=dados.nome.strip(), cpf=dados.cpf, cns=dados.cns, celular=dados.celular,
        senha_hash=hash_senha(dados.senha), consentimento_em=agora,
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return _token(u)


@router.post("/login", response_model=TokenOut)
def login(dados: LoginIn, db: Session = Depends(get_db)):
    cpf = somente_digitos(dados.cpf)
    if limitador_login.bloqueado(cpf):
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS,
                            "Muitas tentativas. Aguarde alguns minutos e tente novamente.")
    u = db.scalar(select(Usuario).where(Usuario.cpf == cpf))
    if u is None or not verificar_senha(dados.senha, u.senha_hash):
        limitador_login.registrar_falha(cpf)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "CPF ou senha incorretos.")
    limitador_login.limpar(cpf)
    return _token(u)
