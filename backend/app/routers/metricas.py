from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas import MetricaDiaria, MetricasResponse, ResumenEstado
from app.security import get_current_user

router = APIRouter(prefix="/metricas", tags=["metricas"])


@router.get("", response_model=MetricasResponse)
def obtener_metricas(
    fecha: date | None = Query(default=None, description="Filtrar por día (UTC); omitir para todo el histórico"),
    db: Session = Depends(get_db),
    _user: dict = Depends(get_current_user),
) -> MetricasResponse:
    """Consume dbo.vw_ResumenVentasDiarias (supuesto #2 del README)."""
    filtro = "WHERE Fecha = :fecha" if fecha else ""
    params = {"fecha": fecha} if fecha else {}

    resumen_rows = db.execute(
        text(
            f"""
            SELECT Estado,
                   SUM(CantidadPedidos) AS CantidadPedidos,
                   SUM(MontoTotal)      AS MontoTotal
            FROM dbo.vw_ResumenVentasDiarias
            {filtro}
            GROUP BY Estado
            ORDER BY Estado
            """
        ),
        params,
    ).mappings().all()

    detalle_rows = db.execute(
        text(
            f"""
            SELECT Fecha, Estado, ClienteId, ClienteNombre, CantidadPedidos, MontoTotal
            FROM dbo.vw_ResumenVentasDiarias
            {filtro}
            ORDER BY Fecha DESC, ClienteNombre, Estado
            """
        ),
        params,
    ).mappings().all()

    return MetricasResponse(
        resumen_por_estado=[
            ResumenEstado(
                estado=r["Estado"],
                cantidad_pedidos=r["CantidadPedidos"],
                monto_total=r["MontoTotal"],
            )
            for r in resumen_rows
        ],
        detalle=[
            MetricaDiaria(
                fecha=r["Fecha"],
                estado=r["Estado"],
                cliente_id=r["ClienteId"],
                cliente_nombre=r["ClienteNombre"],
                cantidad_pedidos=r["CantidadPedidos"],
                monto_total=r["MontoTotal"],
            )
            for r in detalle_rows
        ],
    )
