"""UBS Fácil — API REST.

Rode com:  uvicorn app.main:app --reload
Documentação interativa: http://localhost:8000/docs
"""
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import agendamentos, auth, fila, perfil, unidades
from app.core.clock import agora
from app.core.config import settings
from app.core.database import Base, SessionLocal, engine
from app.services.notificacoes import enviar_pendentes

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("ubs_facil")


async def _laco_lembretes() -> None:
    while True:
        try:
            with SessionLocal() as db:
                n = enviar_pendentes(db, agora())
                if n:
                    log.info("%d lembrete(s) enviado(s)", n)
        except Exception:
            log.exception("Falha ao enviar lembretes")
        await asyncio.sleep(settings.lembretes_intervalo_seg)


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(engine)  # em produção, preferir migrações (Alembic)
    tarefa = asyncio.create_task(_laco_lembretes()) if settings.lembretes_ativos else None
    yield
    if tarefa:
        tarefa.cancel()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="Agendamento, fila em tempo real e lembretes para Unidades Básicas de Saúde.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def cabecalhos_seguranca(request: Request, call_next):
    resp = await call_next(request)
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    resp.headers["Cache-Control"] = "no-store"  # dados de saúde não devem ficar em cache
    return resp


@app.exception_handler(RequestValidationError)
async def erro_validacao(_: Request, exc: RequestValidationError):
    """Mensagens de validação em linguagem simples para o app exibir direto ao paciente."""
    erros = [
        {"campo": ".".join(str(p) for p in e.get("loc", ())[1:]),
         "mensagem": str(e.get("msg", "Dado inválido")).removeprefix("Value error, ")}
        for e in exc.errors()
    ]
    return JSONResponse(status_code=422,
                        content={"detail": erros[0]["mensagem"] if erros else "Dados inválidos.", "erros": erros})


@app.get("/saude", tags=["Infra"])
def saude():
    return {"status": "ok"}


for r in (auth.router, unidades.router, agendamentos.router, fila.router, fila.recepcao, perfil.router):
    app.include_router(r)
