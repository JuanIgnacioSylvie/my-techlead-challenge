import re

from sqlalchemy.exc import DBAPIError


class AppError(Exception):
    """Error de negocio con código HTTP asociado."""

    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail


# Códigos de negocio lanzados con THROW en los stored procedures
# (ver db/02_procedures.sql) mapeados a códigos HTTP.
_SQL_BUSINESS_ERRORS: dict[int, int] = {
    50001: 409,  # stock insuficiente
    50002: 404,  # producto inexistente/inactivo
    50003: 404,  # cliente inexistente/inactivo
    50004: 400,  # usuario inexistente/inactivo
    50005: 400,  # detalle vacío
    50006: 400,  # cantidad inválida
    50010: 404,  # pedido inexistente
    50011: 400,  # transición de estado inválida
}

_MSG_RE = re.compile(r"\[SQL Server\](.+?)(?:\s*\(\d+\)\s*\(SQL|$)")


def map_db_error(exc: DBAPIError) -> AppError | None:
    """Traduce un THROW de negocio de SQL Server a AppError; None si no lo es."""
    text = str(exc.orig) if exc.orig is not None else str(exc)

    for code, status in _SQL_BUSINESS_ERRORS.items():
        if f"({code})" in text or f"{code}," in text:
            match = _MSG_RE.search(text)
            detail = match.group(1).strip() if match else "Error de negocio en base de datos."
            return AppError(status, detail)
    return None
