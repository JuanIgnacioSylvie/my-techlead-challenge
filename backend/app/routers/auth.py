from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.errors import AppError
from app.schemas import LoginRequest, LoginResponse
from app.security import create_access_token, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> LoginResponse:
    row = db.execute(
        text(
            "SELECT UsuarioId, NombreUsuario, NombreCompleto, PasswordHash "
            "FROM dbo.Usuarios WHERE NombreUsuario = :username AND Activo = 1"
        ),
        {"username": payload.username},
    ).mappings().first()

    # Mismo mensaje para usuario inexistente y contraseña errónea:
    # no revelar cuál de los dos falló (enumeración de usuarios).
    if row is None or not verify_password(payload.password, row["PasswordHash"]):
        raise AppError(401, "Usuario o contraseña incorrectos.")

    token, expires_in = create_access_token(row["UsuarioId"], row["NombreUsuario"])

    return LoginResponse(
        access_token=token,
        expires_in=expires_in,
        usuario_id=row["UsuarioId"],
        nombre_usuario=row["NombreUsuario"],
        nombre_completo=row["NombreCompleto"],
    )
