-- =============================================================
-- 03_seed_data.sql — Datos de prueba iniciales (DML)
--
-- Idempotente: inserta solo si aún no existen (por claves naturales).
-- Los pedidos de ejemplo se crean UNA sola vez (si Pedidos está vacía)
-- invocando sp_RegistrarPedido, para respetar el descuento de stock.
--
-- Credenciales (documentadas también en README.md):
--   operador / Operador123!
--   admin    / Admin123!
--   demo     / Demo123!
--
-- Hashes bcrypt generados con: bcrypt.hashpw(..., gensalt(rounds=12))
-- =============================================================

USE GestionPedidos;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

-- -------------------------------------------------------------
-- Usuarios (operadores)
-- -------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = N'operador')
    INSERT INTO dbo.Usuarios (NombreUsuario, NombreCompleto, PasswordHash)
    VALUES (
        N'operador',
        N'Lucía Fernández',
        '$2b$12$mBvQGtrNfiPbjy38d02OheXvNd/JDmuYrYQ0zpunc6n7gdwyMbLWu'  -- Operador123!
    );

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = N'admin')
    INSERT INTO dbo.Usuarios (NombreUsuario, NombreCompleto, PasswordHash)
    VALUES (
        N'admin',
        N'Carlos Méndez',
        '$2b$12$ZlRygqxJx.GOBpUZ2cFKHeQQWT6Vx4zu9f2X0CsDpU3gTfSJhS7uS'  -- Admin123!
    );

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE NombreUsuario = N'demo')
    INSERT INTO dbo.Usuarios (NombreUsuario, NombreCompleto, PasswordHash)
    VALUES (
        N'demo',
        N'Usuario Demo',
        '$2b$12$FYEz9KSUl7a8fJEcJtLA..BBOS7VOqLY1wBcSSpEchrGD43czEyUq'  -- Demo123!
    );
GO

-- -------------------------------------------------------------
-- Clientes
-- -------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WHERE Nombre = N'Distribuidora Norte SA')
    INSERT INTO dbo.Clientes (Nombre, Email, Telefono, Direccion)
    VALUES (N'Distribuidora Norte SA', N'compras@dnorte.example', N'+54 11 4555-1001', N'Av. del Libertador 4500, CABA');

IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WHERE Nombre = N'Supermercado El Sol')
    INSERT INTO dbo.Clientes (Nombre, Email, Telefono, Direccion)
    VALUES (N'Supermercado El Sol', N'pedidos@elsol.example', N'+54 11 4555-2002', N'Calle Mitre 820, Quilmes');

IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WHERE Nombre = N'Farmacia Central')
    INSERT INTO dbo.Clientes (Nombre, Email, Telefono, Direccion)
    VALUES (N'Farmacia Central', N'deposito@farmaciacentral.example', N'+54 11 4555-3003', N'Av. Rivadavia 11200, CABA');

IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WHERE Nombre = N'Almacén del Sur')
    INSERT INTO dbo.Clientes (Nombre, Email, Telefono, Direccion)
    VALUES (N'Almacén del Sur', N'ops@almacendelsur.example', N'+54 11 4555-4004', N'Ruta 2 Km 42, La Plata');

IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WHERE Nombre = N'Café Andino')
    INSERT INTO dbo.Clientes (Nombre, Email, Telefono, Direccion)
    VALUES (N'Café Andino', N'compras@cafeandino.example', N'+54 11 4555-5005', N'Honduras 5800, Palermo');
GO

-- -------------------------------------------------------------
-- Productos (stock inicial antes de los pedidos de ejemplo)
-- -------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Sku = N'CAJ-001')
    INSERT INTO dbo.Productos (Sku, Nombre, Descripcion, PrecioUnitario, Stock)
    VALUES (N'CAJ-001', N'Caja cartón mediana', N'Caja 40x30x30 cm, pack x10', 1250.00, 120);

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Sku = N'CAJ-002')
    INSERT INTO dbo.Productos (Sku, Nombre, Descripcion, PrecioUnitario, Stock)
    VALUES (N'CAJ-002', N'Caja cartón grande', N'Caja 60x40x40 cm, pack x5', 2100.00, 80);

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Sku = N'PLT-100')
    INSERT INTO dbo.Productos (Sku, Nombre, Descripcion, PrecioUnitario, Stock)
    VALUES (N'PLT-100', N'Pallet estándar', N'Pallet europool 120x80 cm', 8500.00, 40);

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Sku = N'FLM-050')
    INSERT INTO dbo.Productos (Sku, Nombre, Descripcion, PrecioUnitario, Stock)
    VALUES (N'FLM-050', N'Film stretch 50cm', N'Rollo industrial 2.5 kg', 3200.00, 200);

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Sku = N'ETQ-A4')
    INSERT INTO dbo.Productos (Sku, Nombre, Descripcion, PrecioUnitario, Stock)
    VALUES (N'ETQ-A4', N'Etiquetas adhesivas A4', N'Resma 100 hojas', 980.00, 150);

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Sku = N'CIN-200')
    INSERT INTO dbo.Productos (Sku, Nombre, Descripcion, PrecioUnitario, Stock)
    VALUES (N'CIN-200', N'Cinta de embalaje', N'Pack x12 rollos transparentes', 1450.00, 90);

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Sku = N'GUA-M')
    INSERT INTO dbo.Productos (Sku, Nombre, Descripcion, PrecioUnitario, Stock)
    VALUES (N'GUA-M', N'Guantes de trabajo M', N'Par nitrilo, talle M', 650.00, 300);

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Sku = N'BOT-5L')
    INSERT INTO dbo.Productos (Sku, Nombre, Descripcion, PrecioUnitario, Stock)
    VALUES (N'BOT-5L', N'Bidón agua 5L', N'Bidón sellado para ruta', 1100.00, 60);
GO

-- -------------------------------------------------------------
-- Pedidos de ejemplo (solo si la tabla está vacía)
-- Usa sp_RegistrarPedido + sp_ActualizarEstadoPedido para dejar
-- stock y estados coherentes con las reglas de negocio.
-- -------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.Pedidos)
BEGIN
    DECLARE @UsuarioOp   INT = (SELECT UsuarioId FROM dbo.Usuarios WHERE NombreUsuario = N'operador');
    DECLARE @UsuarioAdm  INT = (SELECT UsuarioId FROM dbo.Usuarios WHERE NombreUsuario = N'admin');

    DECLARE @CliNorte    INT = (SELECT ClienteId FROM dbo.Clientes WHERE Nombre = N'Distribuidora Norte SA');
    DECLARE @CliSol      INT = (SELECT ClienteId FROM dbo.Clientes WHERE Nombre = N'Supermercado El Sol');
    DECLARE @CliFarma    INT = (SELECT ClienteId FROM dbo.Clientes WHERE Nombre = N'Farmacia Central');
    DECLARE @CliSur      INT = (SELECT ClienteId FROM dbo.Clientes WHERE Nombre = N'Almacén del Sur');

    DECLARE @Caj001 INT = (SELECT ProductoId FROM dbo.Productos WHERE Sku = N'CAJ-001');
    DECLARE @Caj002 INT = (SELECT ProductoId FROM dbo.Productos WHERE Sku = N'CAJ-002');
    DECLARE @Plt100 INT = (SELECT ProductoId FROM dbo.Productos WHERE Sku = N'PLT-100');
    DECLARE @Flm050 INT = (SELECT ProductoId FROM dbo.Productos WHERE Sku = N'FLM-050');
    DECLARE @EtqA4  INT = (SELECT ProductoId FROM dbo.Productos WHERE Sku = N'ETQ-A4');
    DECLARE @Cin200 INT = (SELECT ProductoId FROM dbo.Productos WHERE Sku = N'CIN-200');
    DECLARE @GuaM   INT = (SELECT ProductoId FROM dbo.Productos WHERE Sku = N'GUA-M');

    DECLARE @Pedido1 INT, @Pedido2 INT, @Pedido3 INT, @Pedido4 INT, @Pedido5 INT;
    DECLARE @Detalle dbo.DetallePedidoType;

    -- Pedido 1: Pendiente (queda en ese estado)
    DELETE FROM @Detalle;
    INSERT INTO @Detalle (ProductoId, Cantidad) VALUES (@Caj001, 10), (@Flm050, 5);
    EXEC dbo.sp_RegistrarPedido @CliNorte, @UsuarioOp, @Detalle, @Pedido1 OUTPUT;

    -- Pedido 2: EnPreparacion
    DELETE FROM @Detalle;
    INSERT INTO @Detalle (ProductoId, Cantidad) VALUES (@Caj002, 4), (@Cin200, 6), (@EtqA4, 20);
    EXEC dbo.sp_RegistrarPedido @CliSol, @UsuarioOp, @Detalle, @Pedido2 OUTPUT;
    EXEC dbo.sp_ActualizarEstadoPedido @Pedido2, N'EnPreparacion';

    -- Pedido 3: Enviado
    DELETE FROM @Detalle;
    INSERT INTO @Detalle (ProductoId, Cantidad) VALUES (@Plt100, 2), (@GuaM, 50);
    EXEC dbo.sp_RegistrarPedido @CliFarma, @UsuarioAdm, @Detalle, @Pedido3 OUTPUT;
    EXEC dbo.sp_ActualizarEstadoPedido @Pedido3, N'EnPreparacion';
    EXEC dbo.sp_ActualizarEstadoPedido @Pedido3, N'Enviado';

    -- Pedido 4: Entregado
    DELETE FROM @Detalle;
    INSERT INTO @Detalle (ProductoId, Cantidad) VALUES (@Caj001, 5), (@EtqA4, 10), (@Flm050, 2);
    EXEC dbo.sp_RegistrarPedido @CliSur, @UsuarioOp, @Detalle, @Pedido4 OUTPUT;
    EXEC dbo.sp_ActualizarEstadoPedido @Pedido4, N'EnPreparacion';
    EXEC dbo.sp_ActualizarEstadoPedido @Pedido4, N'Enviado';
    EXEC dbo.sp_ActualizarEstadoPedido @Pedido4, N'Entregado';

    -- Pedido 5: Cancelado (repondrá stock vía SP)
    DELETE FROM @Detalle;
    INSERT INTO @Detalle (ProductoId, Cantidad) VALUES (@Plt100, 1), (@Cin200, 3);
    EXEC dbo.sp_RegistrarPedido @CliNorte, @UsuarioAdm, @Detalle, @Pedido5 OUTPUT;
    EXEC dbo.sp_ActualizarEstadoPedido @Pedido5, N'Cancelado';

    PRINT N'Seed de pedidos OK: '
        + N'P1=' + CAST(@Pedido1 AS NVARCHAR(10))
        + N' P2=' + CAST(@Pedido2 AS NVARCHAR(10))
        + N' P3=' + CAST(@Pedido3 AS NVARCHAR(10))
        + N' P4=' + CAST(@Pedido4 AS NVARCHAR(10))
        + N' P5=' + CAST(@Pedido5 AS NVARCHAR(10));
END
ELSE
    PRINT N'Seed de pedidos omitido: ya existen pedidos.';
GO
