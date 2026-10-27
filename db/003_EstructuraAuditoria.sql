/* ShopCart | 003_EstructuraAuditoria.sql
   Crea: RefreshToken, EstadoPedido, TransicionEstadoPedido,
         HistorialEstadoPedido, Devolucion, DetalleDevolucion, Bitacora.
   Modifica: MovimientoInventario (origen DEVOLUCION y trazabilidad).
   Define: PK, DEFAULT, UNIQUE, CHECK, FK e indices de consulta.
*/
USE ShopCartDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.RefreshToken', N'U') IS NOT NULL
    THROW 51004, N'La migracion 003 ya parece aplicada: dbo.RefreshToken existe.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- 1. RefreshToken | Sesiones renovables y rotacion rastreable.
    CREATE TABLE dbo.RefreshToken (
        IDRefreshToken BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RefreshToken PRIMARY KEY,
        IDUsuario INT NOT NULL,
        TokenHash VARBINARY(32) NOT NULL,
        IDFamilia UNIQUEIDENTIFIER NOT NULL,
        IDTokenAnterior BIGINT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaExpiracion DATETIME2(3) NOT NULL,
        FechaRevocacion DATETIME2(3) NULL
    );
    -- Un hash identifica un unico refresh token.
    ALTER TABLE dbo.RefreshToken ADD CONSTRAINT UQ_RefreshToken_Hash UNIQUE (TokenHash);
    ALTER TABLE dbo.RefreshToken ADD CONSTRAINT CK_RefreshToken_Fechas CHECK (
        FechaExpiracion > FechaCreacion AND
        (FechaRevocacion IS NULL OR FechaRevocacion >= FechaCreacion)
    );
    ALTER TABLE dbo.RefreshToken ADD CONSTRAINT DF_RefreshToken_FechaCreacion
        DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.RefreshToken ADD CONSTRAINT FK_RefreshToken_Usuario
        FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuario (IDUsuario);
    ALTER TABLE dbo.RefreshToken ADD CONSTRAINT FK_RefreshToken_Anterior
        FOREIGN KEY (IDTokenAnterior) REFERENCES dbo.RefreshToken (IDRefreshToken);
    -- Un token anterior solo puede originar un reemplazo.
    CREATE UNIQUE INDEX UX_RefreshToken_Anterior ON dbo.RefreshToken (IDTokenAnterior)
        WHERE IDTokenAnterior IS NOT NULL;
    CREATE INDEX IX_RefreshToken_Usuario_Familia ON dbo.RefreshToken (IDUsuario, IDFamilia, FechaCreacion DESC);

    -- 2. EstadoPedido | Catalogo de estados comerciales.
    CREATE TABLE dbo.EstadoPedido (
        IDEstadoPedido INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EstadoPedido PRIMARY KEY,
        Codigo VARCHAR(25) NOT NULL,
        Nombre NVARCHAR(80) NOT NULL
    );
    ALTER TABLE dbo.EstadoPedido ADD CONSTRAINT UQ_EstadoPedido_Codigo UNIQUE (Codigo);

    -- 3. TransicionEstadoPedido | Cambios logisticos permitidos.
    CREATE TABLE dbo.TransicionEstadoPedido (
        IDTransicionEstadoPedido INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TransicionEstadoPedido PRIMARY KEY,
        IDEstadoOrigen INT NOT NULL,
        IDEstadoDestino INT NOT NULL
    );
    ALTER TABLE dbo.TransicionEstadoPedido ADD CONSTRAINT UQ_TransicionEstadoPedido_Par
        UNIQUE (IDEstadoOrigen, IDEstadoDestino);
    ALTER TABLE dbo.TransicionEstadoPedido ADD CONSTRAINT CK_TransicionEstadoPedido_Distinta
        CHECK (IDEstadoOrigen <> IDEstadoDestino);
    ALTER TABLE dbo.TransicionEstadoPedido ADD CONSTRAINT FK_TransicionEstadoPedido_Origen
        FOREIGN KEY (IDEstadoOrigen) REFERENCES dbo.EstadoPedido (IDEstadoPedido);
    ALTER TABLE dbo.TransicionEstadoPedido ADD CONSTRAINT FK_TransicionEstadoPedido_Destino
        FOREIGN KEY (IDEstadoDestino) REFERENCES dbo.EstadoPedido (IDEstadoPedido);

    -- 4. HistorialEstadoPedido | Evidencia de cada transicion.
    CREATE TABLE dbo.HistorialEstadoPedido (
        IDHistorialEstadoPedido BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HistorialEstadoPedido PRIMARY KEY,
        IDPedido BIGINT NOT NULL,
        IDEstadoAnterior INT NULL,
        IDEstadoNuevo INT NOT NULL,
        IDUsuario INT NOT NULL,
        Motivo NVARCHAR(300) NULL,
        FechaCambio DATETIME2(3) NOT NULL
    );
    ALTER TABLE dbo.HistorialEstadoPedido ADD CONSTRAINT DF_HistorialEstadoPedido_Fecha
        DEFAULT (SYSUTCDATETIME()) FOR FechaCambio;
    -- Permite registrar la creacion inicial sin estado anterior.
    ALTER TABLE dbo.HistorialEstadoPedido ADD CONSTRAINT CK_HistorialEstadoPedido_Cambio CHECK (
        IDEstadoAnterior IS NULL OR IDEstadoAnterior <> IDEstadoNuevo
    );
    ALTER TABLE dbo.HistorialEstadoPedido ADD CONSTRAINT FK_HistorialEstadoPedido_Pedido
        FOREIGN KEY (IDPedido) REFERENCES dbo.Pedido (IDPedido);
    ALTER TABLE dbo.HistorialEstadoPedido ADD CONSTRAINT FK_HistorialEstadoPedido_Anterior
        FOREIGN KEY (IDEstadoAnterior) REFERENCES dbo.EstadoPedido (IDEstadoPedido);
    ALTER TABLE dbo.HistorialEstadoPedido ADD CONSTRAINT FK_HistorialEstadoPedido_Nuevo
        FOREIGN KEY (IDEstadoNuevo) REFERENCES dbo.EstadoPedido (IDEstadoPedido);
    ALTER TABLE dbo.HistorialEstadoPedido ADD CONSTRAINT FK_HistorialEstadoPedido_Usuario
        FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuario (IDUsuario);
    CREATE INDEX IX_HistorialEstadoPedido_Pedido_Fecha
        ON dbo.HistorialEstadoPedido (IDPedido, FechaCambio DESC);

    -- 5. Devolucion | Operacion de reintegro de un pedido.
    CREATE TABLE dbo.Devolucion (
        IDDevolucion BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Devolucion PRIMARY KEY,
        IDPedido BIGINT NOT NULL,
        IDUsuarioRegistro INT NOT NULL,
        Estado VARCHAR(20) NOT NULL,
        Motivo NVARCHAR(300) NOT NULL,
        MontoTotal DECIMAL(18,2) NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaConfirmacion DATETIME2(3) NULL
    );
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT UQ_Devolucion_ID_Pedido UNIQUE (IDDevolucion, IDPedido);
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT CK_Devolucion_Estado CHECK (Estado IN ('REGISTRADA','COMPLETADA','RECHAZADA'));
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT CK_Devolucion_Monto CHECK (MontoTotal >= 0);
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT CK_Devolucion_Motivo CHECK (LEN(LTRIM(RTRIM(Motivo))) > 0);
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT CK_Devolucion_Confirmacion CHECK (
        (Estado = 'COMPLETADA' AND FechaConfirmacion IS NOT NULL AND FechaConfirmacion >= FechaCreacion)
        OR (Estado <> 'COMPLETADA' AND FechaConfirmacion IS NULL)
    );
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT DF_Devolucion_Estado DEFAULT ('REGISTRADA') FOR Estado;
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT DF_Devolucion_Monto DEFAULT (0) FOR MontoTotal;
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT DF_Devolucion_Fecha DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT FK_Devolucion_Pedido FOREIGN KEY (IDPedido) REFERENCES dbo.Pedido (IDPedido);
    ALTER TABLE dbo.Devolucion ADD CONSTRAINT FK_Devolucion_Usuario FOREIGN KEY (IDUsuarioRegistro) REFERENCES dbo.Usuario (IDUsuario);
    CREATE INDEX IX_Devolucion_Pedido_Fecha ON dbo.Devolucion (IDPedido, FechaCreacion DESC);

    -- 6. DetalleDevolucion | Cantidad e importe por linea original.
    CREATE TABLE dbo.DetalleDevolucion (
        IDDetalleDevolucion BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DetalleDevolucion PRIMARY KEY,
        IDDevolucion BIGINT NOT NULL,
        IDPedido BIGINT NOT NULL,
        IDDetallePedido BIGINT NOT NULL,
        Cantidad INT NOT NULL,
        MontoReembolso DECIMAL(18,2) NOT NULL
    );
    -- Una linea no se repite dentro de la misma devolucion.
    ALTER TABLE dbo.DetalleDevolucion ADD CONSTRAINT UQ_DetalleDevolucion_Linea UNIQUE (IDDevolucion, IDDetallePedido);
    ALTER TABLE dbo.DetalleDevolucion ADD CONSTRAINT CK_DetalleDevolucion_Valores
        CHECK (Cantidad > 0 AND MontoReembolso >= 0);
    -- Ambas referencias deben corresponder al mismo pedido.
    ALTER TABLE dbo.DetalleDevolucion ADD CONSTRAINT FK_DetalleDevolucion_Devolucion_Pedido
        FOREIGN KEY (IDDevolucion, IDPedido) REFERENCES dbo.Devolucion (IDDevolucion, IDPedido);
    ALTER TABLE dbo.DetalleDevolucion ADD CONSTRAINT FK_DetalleDevolucion_DetallePedido_Pedido
        FOREIGN KEY (IDDetallePedido, IDPedido) REFERENCES dbo.DetallePedido (IDDetallePedido, IDPedido);
    CREATE INDEX IX_DetalleDevolucion_DetallePedido ON dbo.DetalleDevolucion (IDDetallePedido);

    -- 7. Bitacora | Cambios criticos de negocio, solo adicion.
    CREATE TABLE dbo.Bitacora (
        IDBitacora BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Bitacora PRIMARY KEY,
        IDUsuario INT NOT NULL,
        Modulo VARCHAR(30) NOT NULL,
        Entidad NVARCHAR(100) NOT NULL,
        IDEntidad BIGINT NOT NULL,
        Accion VARCHAR(30) NOT NULL,
        ValorAnterior NVARCHAR(MAX) NULL,
        ValorNuevo NVARCHAR(MAX) NULL,
        FechaAccion DATETIME2(3) NOT NULL
    );
    -- Los snapshots, cuando existan, deben contener JSON valido.
    ALTER TABLE dbo.Bitacora ADD CONSTRAINT CK_Bitacora_Json CHECK (
        (ValorAnterior IS NULL OR ISJSON(ValorAnterior) = 1)
        AND (ValorNuevo IS NULL OR ISJSON(ValorNuevo) = 1)
    );
    ALTER TABLE dbo.Bitacora ADD CONSTRAINT DF_Bitacora_Fecha DEFAULT (SYSUTCDATETIME()) FOR FechaAccion;
    ALTER TABLE dbo.Bitacora ADD CONSTRAINT FK_Bitacora_Usuario FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuario (IDUsuario);
    CREATE INDEX IX_Bitacora_Modulo_Fecha ON dbo.Bitacora (Modulo, FechaAccion DESC);

    -- Bloquear modificaciones y eliminaciones de la bitacora.
    EXEC(N'CREATE TRIGGER dbo.TR_Bitacora_SoloInsercion
        ON dbo.Bitacora AFTER UPDATE, DELETE AS
        BEGIN
            SET NOCOUNT ON;
            THROW 51040, N''La bitacora es inmutable.'', 1;
        END');

    -- 8. MovimientoInventario | Incorporar el origen de devolucion.
    ALTER TABLE dbo.MovimientoInventario ADD IDDetalleDevolucion BIGINT NULL;
    -- Reemplazar reglas previas para admitir devoluciones positivas.
    ALTER TABLE dbo.MovimientoInventario DROP CONSTRAINT CK_MovimientoInventario_Tipo;
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT CK_MovimientoInventario_Tipo CHECK (
        (TipoMovimiento IN ('ENTRADA_INICIAL','ENTRADA_MANUAL','CANCELACION','DEVOLUCION') AND CantidadCambio > 0)
        OR (TipoMovimiento = 'SALIDA_VENTA' AND CantidadCambio < 0)
        OR (TipoMovimiento = 'AJUSTE' AND CantidadCambio <> 0)
    );
    ALTER TABLE dbo.MovimientoInventario DROP CONSTRAINT CK_MovimientoInventario_Origen;
    -- Compilar la restriccion tras agregar la nueva columna.
    EXEC sys.sp_executesql N'ALTER TABLE dbo.MovimientoInventario
        ADD CONSTRAINT CK_MovimientoInventario_Origen CHECK (
            (TipoMovimiento IN (''SALIDA_VENTA'',''CANCELACION'') AND IDDetallePedido IS NOT NULL AND IDDetalleDevolucion IS NULL)
            OR (TipoMovimiento = ''DEVOLUCION'' AND IDDetallePedido IS NULL AND IDDetalleDevolucion IS NOT NULL)
            OR (TipoMovimiento IN (''ENTRADA_INICIAL'',''ENTRADA_MANUAL'',''AJUSTE'') AND IDDetallePedido IS NULL AND IDDetalleDevolucion IS NULL)
        )';
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT FK_MovimientoInventario_DetalleDevolucion
        FOREIGN KEY (IDDetalleDevolucion) REFERENCES dbo.DetalleDevolucion (IDDetalleDevolucion);
    -- Evitar reintegrar dos veces la misma linea de devolucion.
    -- Compilar el indice tras agregar la nueva columna.
    EXEC sys.sp_executesql N'CREATE UNIQUE INDEX UX_MovimientoInventario_Devolucion
        ON dbo.MovimientoInventario (IDDetalleDevolucion)
        WHERE IDDetalleDevolucion IS NOT NULL';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
