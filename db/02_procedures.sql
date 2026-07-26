-- =============================================================
-- 02_procedures.sql — Stored Procedures y Vistas
--
-- - Tipo TVP DetallePedidoType: renglones del pedido desde el backend
-- - sp_RegistrarPedido: registro atómico + descuento de stock
-- - sp_ActualizarEstadoPedido: cambio de estado; repone stock al Cancelar
-- - vw_ResumenVentasDiarias: métricas por fecha / estado / cliente
--
-- Idempotente: CREATE OR ALTER / CREATE TYPE con guarda.
-- =============================================================

USE GestionPedidos;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- -------------------------------------------------------------
-- TVP: lista de (ProductoId, Cantidad) que envía el backend.
-- CREATE TYPE no admite IF NOT EXISTS nativo; se guarda con sys.types.
-- -------------------------------------------------------------
IF TYPE_ID(N'dbo.DetallePedidoType') IS NULL
BEGIN
    CREATE TYPE dbo.DetallePedidoType AS TABLE
    (
        ProductoId INT NOT NULL,
        Cantidad   INT NOT NULL,
        PRIMARY KEY (ProductoId)  -- un producto una sola vez por pedido
    );
END
GO

-- -------------------------------------------------------------
-- sp_RegistrarPedido
-- Transacción explícita. Bloquea filas de Productos con UPDLOCK+HOLDLOCK
-- para evitar overselling entre operadores concurrentes (supuesto #12).
-- Códigos de error de negocio (>= 50000) para que la API mapee a HTTP:
--   50001 stock insuficiente  -> 409 Conflict
--   50002 producto inválido   -> 400 / 404
--   50003 cliente inválido    -> 400 / 404
--   50004 usuario inválido    -> 400 / 401
--   50005 detalle vacío       -> 400
--   50006 cantidad inválida   -> 400
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarPedido
    @ClienteId INT,
    @UsuarioId INT,
    @Detalle   dbo.DetallePedidoType READONLY,
    @PedidoId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- cualquier error de runtime hace rollback automático

    SET @PedidoId = NULL;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Clientes WHERE ClienteId = @ClienteId AND Activo = 1
    )
        THROW 50003, N'Cliente inexistente o inactivo.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId AND Activo = 1
    )
        THROW 50004, N'Usuario inexistente o inactivo.', 1;

    IF NOT EXISTS (SELECT 1 FROM @Detalle)
        THROW 50005, N'El pedido debe incluir al menos un producto.', 1;

    IF EXISTS (SELECT 1 FROM @Detalle WHERE Cantidad <= 0)
        THROW 50006, N'La cantidad de cada renglón debe ser mayor a cero.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Bloqueo exclusivo de las filas de producto involucradas hasta el COMMIT.
        -- HOLDLOCK evita que otro operador lea stock "disponible" entre validar y descontar.
        SELECT
            d.ProductoId,
            d.Cantidad,
            p.Stock,
            p.PrecioUnitario,
            p.Activo,
            p.Nombre
        INTO #Lineas
        FROM @Detalle AS d
        INNER JOIN dbo.Productos AS p WITH (UPDLOCK, HOLDLOCK, ROWLOCK)
            ON p.ProductoId = d.ProductoId;

        IF (SELECT COUNT(*) FROM @Detalle) <> (SELECT COUNT(*) FROM #Lineas)
            THROW 50002, N'Uno o más productos del pedido no existen.', 1;

        IF EXISTS (SELECT 1 FROM #Lineas WHERE Activo = 0)
            THROW 50002, N'Uno o más productos del pedido están inactivos.', 1;

        IF EXISTS (SELECT 1 FROM #Lineas WHERE Stock < Cantidad)
        BEGIN
            DECLARE @MsgStock NVARCHAR(400);
            SELECT TOP (1) @MsgStock =
                N'Stock insuficiente para el producto ''' + Nombre
                + N''' (disponible: ' + CAST(Stock AS NVARCHAR(20))
                + N', solicitado: ' + CAST(Cantidad AS NVARCHAR(20)) + N').'
            FROM #Lineas
            WHERE Stock < Cantidad;

            THROW 50001, @MsgStock, 1;
        END

        INSERT INTO dbo.Pedidos (ClienteId, UsuarioId, Estado, Total)
        VALUES (@ClienteId, @UsuarioId, N'Pendiente', 0);

        SET @PedidoId = SCOPE_IDENTITY();

        -- Snapshot del precio: el historial del pedido no cambia si el catálogo se actualiza.
        INSERT INTO dbo.DetallePedidos (PedidoId, ProductoId, Cantidad, PrecioUnitario)
        SELECT @PedidoId, ProductoId, Cantidad, PrecioUnitario
        FROM #Lineas;

        UPDATE p
        SET p.Stock = p.Stock - l.Cantidad
        FROM dbo.Productos AS p
        INNER JOIN #Lineas AS l ON l.ProductoId = p.ProductoId;

        UPDATE dbo.Pedidos
        SET Total = (
                SELECT SUM(Subtotal)
                FROM dbo.DetallePedidos
                WHERE PedidoId = @PedidoId
            ),
            FechaActualizacion = SYSUTCDATETIME()
        WHERE PedidoId = @PedidoId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;  -- propaga número, severidad y mensaje al caller (pyodbc / API)
    END CATCH
END
GO

-- -------------------------------------------------------------
-- sp_ActualizarEstadoPedido
-- Cambia el estado del pedido. Si pasa a Cancelado (y no lo estaba),
-- repone el stock descontado al crear (supuesto #14).
-- Códigos:
--   50010 pedido inexistente
--   50011 estado inválido / sin cambio de negocio
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ActualizarEstadoPedido
    @PedidoId     INT,
    @NuevoEstado  NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @NuevoEstado NOT IN (N'Pendiente', N'EnPreparacion', N'Enviado', N'Entregado', N'Cancelado')
        THROW 50011, N'Estado de pedido no permitido.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EstadoActual NVARCHAR(20);

        SELECT @EstadoActual = Estado
        FROM dbo.Pedidos WITH (UPDLOCK, ROWLOCK)
        WHERE PedidoId = @PedidoId;

        IF @EstadoActual IS NULL
            THROW 50010, N'Pedido inexistente.', 1;

        IF @EstadoActual = @NuevoEstado
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        -- No se reabre un pedido cancelado en el PoC (evita re-reservar stock a medias).
        IF @EstadoActual = N'Cancelado'
            THROW 50011, N'No se puede cambiar el estado de un pedido cancelado.', 1;

        -- No se cancela un pedido ya entregado.
        IF @NuevoEstado = N'Cancelado' AND @EstadoActual = N'Entregado'
            THROW 50011, N'No se puede cancelar un pedido entregado.', 1;

        IF @NuevoEstado = N'Cancelado'
        BEGIN
            UPDATE p
            SET p.Stock = p.Stock + d.Cantidad
            FROM dbo.Productos AS p
            INNER JOIN dbo.DetallePedidos AS d ON d.ProductoId = p.ProductoId
            WHERE d.PedidoId = @PedidoId;
        END

        UPDATE dbo.Pedidos
        SET Estado = @NuevoEstado,
            FechaActualizacion = SYSUTCDATETIME()
        WHERE PedidoId = @PedidoId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO

-- -------------------------------------------------------------
-- vw_ResumenVentasDiarias
-- Consolida pedidos por día UTC, estado y cliente.
-- Pensada para GET /api/v1/metricas (supuesto #2).
-- -------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_ResumenVentasDiarias
AS
    SELECT
        CAST(p.FechaCreacion AS DATE) AS Fecha,
        p.Estado,
        c.ClienteId,
        c.Nombre                      AS ClienteNombre,
        COUNT_BIG(*)                  AS CantidadPedidos,
        SUM(p.Total)                  AS MontoTotal
    FROM dbo.Pedidos AS p
    INNER JOIN dbo.Clientes AS c ON c.ClienteId = p.ClienteId
    GROUP BY
        CAST(p.FechaCreacion AS DATE),
        p.Estado,
        c.ClienteId,
        c.Nombre;
GO
