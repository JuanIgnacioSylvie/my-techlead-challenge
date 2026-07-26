from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Configuración desde variables de entorno (ver docker-compose.yml)."""

    db_server: str = "localhost"
    db_port: int = 1433
    db_name: str = "GestionPedidos"
    db_user: str = "sa"
    db_password: str = "YourStrong!Passw0rd"

    jwt_secret: str = "cambiar-en-produccion"
    jwt_algorithm: str = "HS256"
    jwt_expires_minutes: int = 60


settings = Settings()
