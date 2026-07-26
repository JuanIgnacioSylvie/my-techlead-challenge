-- =============================================================
-- 01_schema.sql — Definición DDL
-- Tablas: Usuarios, Clientes, Productos, Pedidos, DetallePedidos
-- Incluye: PKs, FKs con integridad referencial, CHECK/DEFAULT, índices
--
-- Idempotente: puede ejecutarse en cada arranque de db-init sin
-- destruir datos existentes (guardas IF OBJECT_ID ... IS NULL).
-- =============================================================

IF DB_ID(N'GestionPedidos') IS NULL
    CREATE DATABASE GestionPedidos;
GO

USE GestionPedidos;
GO

-- Requeridos por la columna calculada PERSISTED de DetallePedidos
-- (sqlcmd usa QUOTED_IDENTIFIER OFF por defecto)
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- -------------------------------------------------------------
-- Usuarios: operadores de campo que se autentican en la app.
-- No se confunden con Clientes (supuesto #4 del README).
-- -------------------------------------------------------------
IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuarios (
        UsuarioId       INT IDENTITY(1,1) NOT NULL,
        NombreUsuario   NVARCHAR(50)      NOT NULL,
        NombreCompleto  NVARCHAR(100)     NOT NULL,
        -- Hash bcrypt (60 chars); nunca se almacena la contraseña en claro
        PasswordHash    VARCHAR(72)       NOT NULL,
        Activo          BIT               NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
        FechaCreacion   DATETIME2(0)      NOT NULL CONSTRAINT DF_Usuarios_FechaCreacion DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_Usuarios PRIMARY KEY (UsuarioId),
        CONSTRAINT UQ_Usuarios_NombreUsuario UNIQUE (NombreUsuario)
    );
END
GO

-- -------------------------------------------------------------
-- Clientes: destinatarios de los pedidos.
-- -------------------------------------------------------------
IF OBJECT_ID(N'dbo.Clientes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Clientes (
        ClienteId      INT IDENTITY(1,1) NOT NULL,
        Nombre         NVARCHAR(100)     NOT NULL,
        Email          NVARCHAR(100)     NULL,
        Telefono       NVARCHAR(30)      NULL,
        Direccion      NVARCHAR(200)     NULL,
        Activo         BIT               NOT NULL CONSTRAINT DF_Clientes_Activo DEFAULT (1),
        FechaCreacion  DATETIME2(0)      NOT NULL CONSTRAINT DF_Clientes_FechaCreacion DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_Clientes PRIMARY KEY (ClienteId)
    );

    -- Búsqueda de clientes por nombre al registrar pedidos
    CREATE INDEX IX_Clientes_Nombre ON dbo.Clientes (Nombre);
END
GO

-- -------------------------------------------------------------
-- Productos: catálogo con stock controlado.
-- -------------------------------------------------------------
IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Productos (
        ProductoId     INT IDENTITY(1,1) NOT NULL,
        Sku            NVARCHAR(30)      NOT NULL,
        Nombre         NVARCHAR(100)     NOT NULL,
        Descripcion    NVARCHAR(300)     NULL,
        PrecioUnitario DECIMAL(12,2)     NOT NULL,
        Stock          INT               NOT NULL CONSTRAINT DF_Productos_Stock DEFAULT (0),
        Activo         BIT               NOT NULL CONSTRAINT DF_Productos_Activo DEFAULT (1),
        FechaCreacion  DATETIME2(0)      NOT NULL CONSTRAINT DF_Productos_FechaCreacion DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_Productos PRIMARY KEY (ProductoId),
        CONSTRAINT UQ_Productos_Sku UNIQUE (Sku),
        CONSTRAINT CK_Productos_Precio CHECK (PrecioUnitario >= 0),
        -- Red de seguridad última: aunque el SP valida stock, la
        -- restricción garantiza que nunca quede negativo.
        CONSTRAINT CK_Productos_Stock CHECK (Stock >= 0)
    );

    -- GET /productos filtra por nombre (búsqueda del catálogo en la app)
    CREATE INDEX IX_Productos_Nombre ON dbo.Productos (Nombre);
END
GO

-- -------------------------------------------------------------
-- Pedidos: cabecera. Estado con conjunto cerrado (supuesto #13).
-- -------------------------------------------------------------
IF OBJECT_ID(N'dbo.Pedidos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Pedidos (
        PedidoId            INT IDENTITY(1,1) NOT NULL,
        ClienteId           INT               NOT NULL,
        -- Operador que registró el pedido (trazabilidad)
        UsuarioId           INT               NOT NULL,
        Estado              NVARCHAR(20)      NOT NULL CONSTRAINT DF_Pedidos_Estado DEFAULT (N'Pendiente'),
        -- Desnormalizado a propósito: evita recalcular sumas en listados
        -- y en la vista de métricas. Lo fija sp_RegistrarPedido.
        Total               DECIMAL(14,2)     NOT NULL CONSTRAINT DF_Pedidos_Total DEFAULT (0),
        FechaCreacion       DATETIME2(0)      NOT NULL CONSTRAINT DF_Pedidos_FechaCreacion DEFAULT (SYSUTCDATETIME()),
        FechaActualizacion  DATETIME2(0)      NOT NULL CONSTRAINT DF_Pedidos_FechaActualizacion DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_Pedidos PRIMARY KEY (PedidoId),
        CONSTRAINT FK_Pedidos_Clientes FOREIGN KEY (ClienteId) REFERENCES dbo.Clientes (ClienteId),
        CONSTRAINT FK_Pedidos_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId),
        CONSTRAINT CK_Pedidos_Estado CHECK (Estado IN (N'Pendiente', N'EnPreparacion', N'Enviado', N'Entregado', N'Cancelado')),
        CONSTRAINT CK_Pedidos_Total CHECK (Total >= 0)
    );

    -- Consultas frecuentes: pedidos por estado (operación diaria) y
    -- por fecha (vista de métricas diarias); por cliente (historial).
    CREATE INDEX IX_Pedidos_Estado        ON dbo.Pedidos (Estado);
    CREATE INDEX IX_Pedidos_FechaCreacion ON dbo.Pedidos (FechaCreacion);
    CREATE INDEX IX_Pedidos_ClienteId     ON dbo.Pedidos (ClienteId);
END
GO

-- -------------------------------------------------------------
-- DetallePedidos: renglones del pedido.
-- -------------------------------------------------------------
IF OBJECT_ID(N'dbo.DetallePedidos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DetallePedidos (
        DetallePedidoId INT IDENTITY(1,1) NOT NULL,
        PedidoId        INT               NOT NULL,
        ProductoId      INT               NOT NULL,
        Cantidad        INT               NOT NULL,
        -- Snapshot del precio al momento del pedido: si el precio del
        -- producto cambia después, el pedido histórico no se altera.
        PrecioUnitario  DECIMAL(12,2)     NOT NULL,
        Subtotal        AS (CAST(Cantidad AS DECIMAL(14,2)) * PrecioUnitario) PERSISTED,

        CONSTRAINT PK_DetallePedidos PRIMARY KEY (DetallePedidoId),
        CONSTRAINT FK_DetallePedidos_Pedidos   FOREIGN KEY (PedidoId)   REFERENCES dbo.Pedidos (PedidoId) ON DELETE CASCADE,
        CONSTRAINT FK_DetallePedidos_Productos FOREIGN KEY (ProductoId) REFERENCES dbo.Productos (ProductoId),
        CONSTRAINT CK_DetallePedidos_Cantidad CHECK (Cantidad > 0),
        CONSTRAINT CK_DetallePedidos_Precio   CHECK (PrecioUnitario >= 0),
        -- Un producto aparece una sola vez por pedido (se suma cantidad)
        CONSTRAINT UQ_DetallePedidos_Pedido_Producto UNIQUE (PedidoId, ProductoId)
    );

    -- GET /pedidos/{id} arma el detalle; el índice único de arriba ya
    -- cubre PedidoId como prefijo, este apoya joins por producto.
    CREATE INDEX IX_DetallePedidos_ProductoId ON dbo.DetallePedidos (ProductoId);
END
GO
