from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.security import get_current_user

router = APIRouter(prefix="/clientes", tags=["clientes"])


class ClienteOut(BaseModel):
    cliente_id: int
    nombre: str
    direccion: str | None


@router.get("", response_model=list[ClienteOut])
def listar_clientes(
    db: Session = Depends(get_db),
    _user: dict = Depends(get_current_user),
) -> list[ClienteOut]:
    """Clientes activos para el formulario de pedido (no estaba en el
    enunciado, pero POST /pedidos exige cliente_id y la app necesita
    ofrecer opciones; ver supuestos del README)."""
    rows = db.execute(
        text(
            "SELECT ClienteId, Nombre, Direccion FROM dbo.Clientes "
            "WHERE Activo = 1 ORDER BY Nombre"
        )
    ).mappings().all()

    return [
        ClienteOut(cliente_id=r["ClienteId"], nombre=r["Nombre"], direccion=r["Direccion"])
        for r in rows
    ]
