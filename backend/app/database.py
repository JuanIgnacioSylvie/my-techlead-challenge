from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings

_odbc = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={settings.db_server},{settings.db_port};"
    f"DATABASE={settings.db_name};"
    f"UID={settings.db_user};"
    f"PWD={settings.db_password};"
    # El contenedor de SQL Server usa certificado autofirmado
    "TrustServerCertificate=yes;"
)

engine = create_engine(
    f"mssql+pyodbc:///?odbc_connect={quote_plus(_odbc)}",
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
