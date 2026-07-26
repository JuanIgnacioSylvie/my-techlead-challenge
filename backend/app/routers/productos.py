from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas import ProductoOut, ProductosPage
from app.security import get_current_user

router = APIRouter(prefix="/productos", tags=["productos"])


@router.get("", response_model=ProductosPage)
def listar_productos(
    nombre: str | None = Query(default=None, max_length=100, description="Filtro por nombre (contiene)"),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    _user: dict = Depends(get_current_user),
) -> ProductosPage:
    filtro = "AND Nombre LIKE :nombre" if nombre else ""
    params: dict = {"limit": limit, "offset": offset}
    if nombre:
        params["nombre"] = f"%{nombre}%"

    total = db.execute(
        text(f"SELECT COUNT(*) FROM dbo.Productos WHERE Activo = 1 {filtro}"),
        params,
    ).scalar_one()

    rows = db.execute(
        text(
            f"""
            SELECT ProductoId, Sku, Nombre, Descripcion, PrecioUnitario, Stock
            FROM dbo.Productos
            WHERE Activo = 1 {filtro}
            ORDER BY Nombre
            OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY
            """
        ),
        params,
    ).mappings().all()

    items = [
        ProductoOut(
            producto_id=r["ProductoId"],
            sku=r["Sku"],
            nombre=r["Nombre"],
            descripcion=r["Descripcion"],
            precio_unitario=r["PrecioUnitario"],
            stock=r["Stock"],
        )
        for r in rows
    ]

    return ProductosPage(items=items, total=total, limit=limit, offset=offset)
