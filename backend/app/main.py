import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import DBAPIError, OperationalError

from app.errors import AppError
from app.routers import auth, clientes, metricas, pedidos, productos

logger = logging.getLogger("app")

app = FastAPI(
    title="Gestión de Pedidos e Inventario",
    description="API del desafío técnico Tech Lead (Xionico). Login: POST /api/v1/auth/login.",
    version="1.0.0",
)

API_PREFIX = "/api/v1"
app.include_router(auth.router, prefix=API_PREFIX)
app.include_router(clientes.router, prefix=API_PREFIX)
app.include_router(productos.router, prefix=API_PREFIX)
app.include_router(pedidos.router, prefix=API_PREFIX)
app.include_router(metricas.router, prefix=API_PREFIX)


# ----- Manejo centralizado de excepciones (enunciado 3.2) -----

@app.exception_handler(AppError)
async def app_error_handler(_: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.exception_handler(RequestValidationError)
async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    # El enunciado pide 400 para errores de validación (FastAPI usa 422 por defecto)
    errores = [
        {"campo": ".".join(str(p) for p in e["loc"] if p != "body"), "error": e["msg"]}
        for e in exc.errors()
    ]
    return JSONResponse(
        status_code=400,
        content={"detail": "Datos de entrada inválidos.", "errores": errores},
    )


@app.exception_handler(OperationalError)
async def db_unavailable_handler(_: Request, exc: OperationalError) -> JSONResponse:
    logger.error("Base de datos no disponible: %s", exc)
    return JSONResponse(
        status_code=503,
        content={"detail": "Base de datos no disponible. Reintente en unos segundos."},
    )


@app.exception_handler(DBAPIError)
async def db_error_handler(_: Request, exc: DBAPIError) -> JSONResponse:
    # Errores de BD no mapeados a negocio: no filtrar detalles internos
    logger.exception("Error de base de datos no controlado: %s", exc)
    return JSONResponse(status_code=500, content={"detail": "Error interno del servidor."})


@app.get("/health", tags=["health"])
def health() -> dict:
    return {"status": "ok"}
