FROM python:3.12-slim

# Driver ODBC de Microsoft para SQL Server (msodbcsql18).
# El prod.list oficial ya referencia /usr/share/keyrings/microsoft-prod.gpg,
# por eso el key dearmorado se guarda exactamente en esa ruta.
RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg2 \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list -o /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
