from datetime import datetime, timedelta, timezone

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.errors import AppError

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# auto_error=False para responder 401 propio (en vez del 403 default)
_bearer = HTTPBearer(auto_error=False)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(usuario_id: int, nombre_usuario: str) -> tuple[str, int]:
    expires_in = settings.jwt_expires_minutes * 60
    payload = {
        "sub": str(usuario_id),
        "username": nombre_usuario,
        "exp": datetime.now(timezone.utc) + timedelta(seconds=expires_in),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expires_in


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> dict:
    """Dependencia de FastAPI: valida el JWT y devuelve el usuario activo."""
    if credentials is None:
        raise AppError(401, "Token de autenticación requerido.")

    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
        usuario_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise AppError(401, "Token inválido o expirado.")

    row = db.execute(
        text(
            "SELECT UsuarioId, NombreUsuario, NombreCompleto "
            "FROM dbo.Usuarios WHERE UsuarioId = :id AND Activo = 1"
        ),
        {"id": usuario_id},
    ).mappings().first()

    if row is None:
        raise AppError(401, "Usuario inexistente o inactivo.")

    return dict(row)
