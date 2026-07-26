from datetime import date, datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator


# ----- Auth -----

class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    password: str = Field(min_length=1, max_length=72)


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    usuario_id: int
    nombre_usuario: str
    nombre_completo: str


# ----- Productos -----

class ProductoOut(BaseModel):
    producto_id: int
    sku: str
    nombre: str
    descripcion: str | None
    precio_unitario: float
    stock: int


class ProductosPage(BaseModel):
    items: list[ProductoOut]
    total: int
    limit: int
    offset: int


# ----- Pedidos -----

class EstadoPedido(str, Enum):
    PENDIENTE = "Pendiente"
    EN_PREPARACION = "EnPreparacion"
    ENVIADO = "Enviado"
    ENTREGADO = "Entregado"
    CANCELADO = "Cancelado"


class DetalleIn(BaseModel):
    producto_id: int = Field(gt=0)
    cantidad: int = Field(gt=0, le=10_000)


class PedidoCreate(BaseModel):
    cliente_id: int = Field(gt=0)
    detalle: list[DetalleIn] = Field(min_length=1, max_length=100)

    @field_validator("detalle")
    @classmethod
    def productos_unicos(cls, v: list[DetalleIn]) -> list[DetalleIn]:
        ids = [d.producto_id for d in v]
        if len(ids) != len(set(ids)):
            raise ValueError("Cada producto puede aparecer una sola vez en el pedido.")
        return v


class DetalleOut(BaseModel):
    producto_id: int
    sku: str
    nombre: str
    cantidad: int
    precio_unitario: float
    subtotal: float


class PedidoOut(BaseModel):
    pedido_id: int
    cliente_id: int
    cliente_nombre: str
    usuario_id: int
    usuario_nombre: str
    estado: EstadoPedido
    total: float
    fecha_creacion: datetime
    fecha_actualizacion: datetime
    detalle: list[DetalleOut]


class PedidoCreado(BaseModel):
    pedido_id: int
    estado: EstadoPedido
    total: float


class EstadoUpdate(BaseModel):
    estado: EstadoPedido


# ----- Métricas -----

class MetricaDiaria(BaseModel):
    fecha: date
    estado: EstadoPedido
    cliente_id: int
    cliente_nombre: str
    cantidad_pedidos: int
    monto_total: float


class ResumenEstado(BaseModel):
    estado: EstadoPedido
    cantidad_pedidos: int
    monto_total: float


class MetricasResponse(BaseModel):
    resumen_por_estado: list[ResumenEstado]
    detalle: list[MetricaDiaria]
