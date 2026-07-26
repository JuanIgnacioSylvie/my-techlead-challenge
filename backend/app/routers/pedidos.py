from fastapi import APIRouter, Depends
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from app.database import get_db
from app.errors import AppError, map_db_error
from app.schemas import EstadoUpdate, PedidoCreado, PedidoCreate, PedidoOut, DetalleOut
from app.security import get_current_user

router = APIRouter(prefix="/pedidos", tags=["pedidos"])


def _obtener_pedido(pedido_id: int, db: Session) -> PedidoOut:
    conn = db.connection()

    header = conn.exec_driver_sql(
        """
        SELECT p.PedidoId, p.ClienteId, c.Nombre AS ClienteNombre,
               p.UsuarioId, u.NombreCompleto AS UsuarioNombre,
               p.Estado, p.Total, p.FechaCreacion, p.FechaActualizacion
        FROM dbo.Pedidos p
        INNER JOIN dbo.Clientes c ON c.ClienteId = p.ClienteId
        INNER JOIN dbo.Usuarios u ON u.UsuarioId = p.UsuarioId
        WHERE p.PedidoId = ?
        """,
        (pedido_id,),
    ).mappings().first()

    if header is None:
        raise AppError(404, f"Pedido {pedido_id} inexistente.")

    detalle_rows = conn.exec_driver_sql(
        """
        SELECT d.ProductoId, pr.Sku, pr.Nombre, d.Cantidad, d.PrecioUnitario, d.Subtotal
        FROM dbo.DetallePedidos d
        INNER JOIN dbo.Productos pr ON pr.ProductoId = d.ProductoId
        WHERE d.PedidoId = ?
        ORDER BY pr.Nombre
        """,
        (pedido_id,),
    ).mappings().all()

    return PedidoOut(
        pedido_id=header["PedidoId"],
        cliente_id=header["ClienteId"],
        cliente_nombre=header["ClienteNombre"],
        usuario_id=header["UsuarioId"],
        usuario_nombre=header["UsuarioNombre"],
        estado=header["Estado"],
        total=header["Total"],
        fecha_creacion=header["FechaCreacion"],
        fecha_actualizacion=header["FechaActualizacion"],
        detalle=[
            DetalleOut(
                producto_id=r["ProductoId"],
                sku=r["Sku"],
                nombre=r["Nombre"],
                cantidad=r["Cantidad"],
                precio_unitario=r["PrecioUnitario"],
                subtotal=r["Subtotal"],
            )
            for r in detalle_rows
        ],
    )


@router.post("", response_model=PedidoCreado, status_code=201)
def crear_pedido(
    payload: PedidoCreate,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> PedidoCreado:
    """Crea el pedido delegando la lógica transaccional en sp_RegistrarPedido.

    El detalle viaja como Table-Valued Parameter armado en un batch T-SQL
    parametrizado (placeholders qmark de pyodbc, sin concatenar valores).
    """
    values_sql = ", ".join(["(?, ?)"] * len(payload.detalle))
    params: list = []
    for item in payload.detalle:
        params.extend([item.producto_id, item.cantidad])
    params.extend([payload.cliente_id, user["UsuarioId"]])

    sql = f"""
        SET NOCOUNT ON;
        DECLARE @Detalle dbo.DetallePedidoType;
        INSERT INTO @Detalle (ProductoId, Cantidad) VALUES {values_sql};
        DECLARE @PedidoId INT;
        EXEC dbo.sp_RegistrarPedido
            @ClienteId = ?, @UsuarioId = ?, @Detalle = @Detalle,
            @PedidoId = @PedidoId OUTPUT;
        SELECT p.PedidoId, p.Estado, p.Total
        FROM dbo.Pedidos p WHERE p.PedidoId = @PedidoId;
    """

    try:
        row = db.connection().exec_driver_sql(sql, tuple(params)).mappings().first()
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        app_error = map_db_error(exc)
        if app_error is not None:
            raise app_error
        raise

    return PedidoCreado(
        pedido_id=row["PedidoId"], estado=row["Estado"], total=row["Total"]
    )


@router.get("/{pedido_id}", response_model=PedidoOut)
def detalle_pedido(
    pedido_id: int,
    db: Session = Depends(get_db),
    _user: dict = Depends(get_current_user),
) -> PedidoOut:
    return _obtener_pedido(pedido_id, db)


@router.patch("/{pedido_id}/estado", response_model=PedidoOut)
def actualizar_estado(
    pedido_id: int,
    payload: EstadoUpdate,
    db: Session = Depends(get_db),
    _user: dict = Depends(get_current_user),
) -> PedidoOut:
    try:
        db.connection().exec_driver_sql(
            "EXEC dbo.sp_ActualizarEstadoPedido @PedidoId = ?, @NuevoEstado = ?",
            (pedido_id, payload.estado.value),
        )
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        app_error = map_db_error(exc)
        if app_error is not None:
            raise app_error
        raise

    return _obtener_pedido(pedido_id, db)
