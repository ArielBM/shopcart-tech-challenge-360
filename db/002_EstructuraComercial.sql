/* ShopCart | 002_EstructuraComercial.sql
   Crea: Direccion, Carrito, DetalleCarrito, Cupon, Checkout,
         Pedido, DetallePedido, CompromisoCupon, ReservaInventario,
         IntentoPago, UsoCupon, MovimientoInventario.
   Define: PK, DEFAULT, UNIQUE, CHECK, FK e indices de consulta.
*/
USE ShopCartDB;
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Direccion', N'U') IS NOT NULL
    THROW 51003, N'La migracion 003 ya parece aplicada: dbo.Direccion existe.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- 1. Direccion | Destinos guardados por cliente.
    CREATE TABLE dbo.Direccion (
        IDDireccion BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Direccion PRIMARY KEY,
        IDUsuario INT NOT NULL,
        NombreDestinatario NVARCHAR(150) NOT NULL,
        Telefono VARCHAR(30) NULL,
        Departamento NVARCHAR(100) NOT NULL,
        Municipio NVARCHAR(100) NOT NULL,
        DireccionTexto NVARCHAR(500) NOT NULL,
        Referencia NVARCHAR(300) NULL,
        Activa BIT NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL
    );
    -- Direcciones activas por defecto.
    ALTER TABLE dbo.Direccion ADD CONSTRAINT DF_Direccion_Activa DEFAULT (1) FOR Activa;
    ALTER TABLE dbo.Direccion ADD CONSTRAINT DF_Direccion_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    -- Permite verificar la propiedad de la direccion desde el pedido.
    ALTER TABLE dbo.Direccion ADD CONSTRAINT UQ_Direccion_ID_Usuario UNIQUE (IDDireccion, IDUsuario);
    ALTER TABLE dbo.Direccion ADD CONSTRAINT FK_Direccion_Usuario FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuario (IDUsuario);
    CREATE INDEX IX_Direccion_Usuario_Activa ON dbo.Direccion (IDUsuario, Activa);

    -- 2. Carrito | Seleccion editable, sin reserva de inventario.
    CREATE TABLE dbo.Carrito (
        IDCarrito BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Carrito PRIMARY KEY,
        IDUsuario INT NULL,
        TokenInvitadoHash VARBINARY(32) NULL,
        Estado VARCHAR(20) NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaUltimaActividad DATETIME2(3) NOT NULL
    );
    -- Un carrito pertenece a un cliente o a un invitado, nunca a ambos.
    ALTER TABLE dbo.Carrito ADD CONSTRAINT CK_Carrito_Propietario CHECK (
        (IDUsuario IS NOT NULL AND TokenInvitadoHash IS NULL)
        OR (IDUsuario IS NULL AND TokenInvitadoHash IS NOT NULL)
    );
    ALTER TABLE dbo.Carrito ADD CONSTRAINT CK_Carrito_Estado CHECK (Estado IN ('ACTIVO','CONVERTIDO'));
    ALTER TABLE dbo.Carrito ADD CONSTRAINT DF_Carrito_Estado DEFAULT ('ACTIVO') FOR Estado;
    ALTER TABLE dbo.Carrito ADD CONSTRAINT DF_Carrito_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.Carrito ADD CONSTRAINT DF_Carrito_UltimaActividad DEFAULT (SYSUTCDATETIME()) FOR FechaUltimaActividad;
    -- Evita reutilizar un token de invitado en varios carritos.
    CREATE UNIQUE INDEX UX_Carrito_TokenInvitado ON dbo.Carrito (TokenInvitadoHash) WHERE TokenInvitadoHash IS NOT NULL;
    ALTER TABLE dbo.Carrito ADD CONSTRAINT FK_Carrito_Usuario FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuario (IDUsuario);
    CREATE INDEX IX_Carrito_Usuario_Estado ON dbo.Carrito (IDUsuario, Estado) WHERE IDUsuario IS NOT NULL;

    -- 3. DetalleCarrito | Una linea por variante en cada carrito.
    CREATE TABLE dbo.DetalleCarrito (
        IDDetalleCarrito BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DetalleCarrito PRIMARY KEY,
        IDCarrito BIGINT NOT NULL,
        IDVariante INT NOT NULL,
        Cantidad INT NOT NULL,
        FechaActualizacion DATETIME2(3) NOT NULL
    );
    ALTER TABLE dbo.DetalleCarrito ADD CONSTRAINT UQ_DetalleCarrito_Carrito_Variante UNIQUE (IDCarrito, IDVariante);
    ALTER TABLE dbo.DetalleCarrito ADD CONSTRAINT CK_DetalleCarrito_Cantidad CHECK (Cantidad > 0);
    ALTER TABLE dbo.DetalleCarrito ADD CONSTRAINT DF_DetalleCarrito_FechaActualizacion DEFAULT (SYSUTCDATETIME()) FOR FechaActualizacion;
    ALTER TABLE dbo.DetalleCarrito ADD CONSTRAINT FK_DetalleCarrito_Carrito FOREIGN KEY (IDCarrito) REFERENCES dbo.Carrito (IDCarrito);
    ALTER TABLE dbo.DetalleCarrito ADD CONSTRAINT FK_DetalleCarrito_Variante FOREIGN KEY (IDVariante) REFERENCES dbo.Variante (IDVariante);

    -- 4. Cupon | Descuento con vigencia, alcance y limites de uso.
    CREATE TABLE dbo.Cupon (
        IDCupon INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cupon PRIMARY KEY,
        Codigo VARCHAR(50) NOT NULL,
        TipoDescuento VARCHAR(15) NOT NULL,
        Valor DECIMAL(18,2) NOT NULL,
        Alcance VARCHAR(15) NOT NULL,
        IDCategoria INT NULL,
        MontoMinimo DECIMAL(18,2) NOT NULL,
        LimiteGlobal INT NOT NULL,
        LimitePorCliente INT NOT NULL,
        FechaInicio DATETIME2(3) NOT NULL,
        FechaFin DATETIME2(3) NOT NULL,
        Activo BIT NOT NULL
    );
    ALTER TABLE dbo.Cupon ADD CONSTRAINT UQ_Cupon_Codigo UNIQUE (Codigo);
    ALTER TABLE dbo.Cupon ADD CONSTRAINT DF_Cupon_MontoMinimo DEFAULT (0) FOR MontoMinimo;
    ALTER TABLE dbo.Cupon ADD CONSTRAINT DF_Cupon_Activo DEFAULT (1) FOR Activo;
    -- Coherencia del valor, tipo y categoria aplicable.
    ALTER TABLE dbo.Cupon ADD CONSTRAINT CK_Cupon_Reglas CHECK (
        TipoDescuento IN ('PORCENTAJE','FIJO') AND Valor > 0
        AND (TipoDescuento = 'FIJO' OR Valor <= 100)
        AND Alcance IN ('CARRITO','CATEGORIA')
        AND ((Alcance = 'CARRITO' AND IDCategoria IS NULL)
            OR (Alcance = 'CATEGORIA' AND IDCategoria IS NOT NULL))
        AND MontoMinimo >= 0
        AND LimiteGlobal > 0 AND LimitePorCliente > 0
        AND FechaFin > FechaInicio
    );
    ALTER TABLE dbo.Cupon ADD CONSTRAINT FK_Cupon_Categoria FOREIGN KEY (IDCategoria) REFERENCES dbo.Categoria (IDCategoria);

    -- 5. Checkout | Vigencia e idempotencia al iniciar la compra.
    CREATE TABLE dbo.Checkout (
        IDCheckout BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Checkout PRIMARY KEY,
        IDCarrito BIGINT NOT NULL,
        IDUsuario INT NOT NULL,
        ClaveInicio UNIQUEIDENTIFIER NOT NULL,
        HuellaSolicitud VARBINARY(32) NOT NULL,
        Estado VARCHAR(20) NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaExpiracion DATETIME2(3) NOT NULL,
        FechaResolucion DATETIME2(3) NULL
    );
    -- Una clave de inicio produce un solo checkout.
    ALTER TABLE dbo.Checkout ADD CONSTRAINT UQ_Checkout_ClaveInicio UNIQUE (ClaveInicio);
    ALTER TABLE dbo.Checkout ADD CONSTRAINT UQ_Checkout_ID_Usuario UNIQUE (IDCheckout, IDUsuario);
    ALTER TABLE dbo.Checkout ADD CONSTRAINT CK_Checkout_Estado CHECK (Estado IN ('ACTIVO','CONFIRMADO','EXPIRADO','CANCELADO'));
    ALTER TABLE dbo.Checkout ADD CONSTRAINT CK_Checkout_Vigencia CHECK (FechaExpiracion > FechaCreacion);
    ALTER TABLE dbo.Checkout ADD CONSTRAINT DF_Checkout_Estado DEFAULT ('ACTIVO') FOR Estado;
    ALTER TABLE dbo.Checkout ADD CONSTRAINT DF_Checkout_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.Checkout ADD CONSTRAINT FK_Checkout_Carrito FOREIGN KEY (IDCarrito) REFERENCES dbo.Carrito (IDCarrito);
    ALTER TABLE dbo.Checkout ADD CONSTRAINT FK_Checkout_Usuario FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuario (IDUsuario);
    CREATE INDEX IX_Checkout_Estado_Expiracion ON dbo.Checkout (Estado, FechaExpiracion);

    -- 6. Pedido | Cotizacion congelada y estado comercial.
    CREATE TABLE dbo.Pedido (
        IDPedido BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Pedido PRIMARY KEY,
        IDCheckout BIGINT NOT NULL,
        IDUsuario INT NOT NULL,
        IDDireccionEntrega BIGINT NOT NULL,
        Estado VARCHAR(25) NOT NULL,
        Subtotal DECIMAL(18,2) NOT NULL,
        DescuentoTotal DECIMAL(18,2) NOT NULL,
        CostoEnvio DECIMAL(18,2) NOT NULL,
        Total DECIMAL(18,2) NOT NULL,
        -- Instantanea de direccion: los cambios al perfil no alteran el pedido.
        Destinatario NVARCHAR(150) NOT NULL,
        TelefonoEntrega VARCHAR(30) NULL,
        DepartamentoEntrega NVARCHAR(100) NOT NULL,
        MunicipioEntrega NVARCHAR(100) NOT NULL,
        DireccionEntregaTexto NVARCHAR(500) NOT NULL,
        ReferenciaEntrega NVARCHAR(300) NULL,
        MetodoEnvio NVARCHAR(80) NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaPago DATETIME2(3) NULL
    );
    -- Un checkout solo origina un pedido; el usuario debe ser el mismo.
    ALTER TABLE dbo.Pedido ADD CONSTRAINT UQ_Pedido_Checkout UNIQUE (IDCheckout);
    ALTER TABLE dbo.Pedido ADD CONSTRAINT UQ_Pedido_ID_Usuario UNIQUE (IDPedido, IDUsuario);
    ALTER TABLE dbo.Pedido ADD CONSTRAINT CK_Pedido_Estado CHECK (Estado IN (
        'PENDIENTE_PAGO','EXPIRADO','PAGADO','EN_PREPARACION','DESPACHADO','ENTREGADO','CANCELADO'
    ));
    -- Impide importes negativos y totales inconsistentes.
    ALTER TABLE dbo.Pedido ADD CONSTRAINT CK_Pedido_Importes CHECK (
        Subtotal >= 0 AND DescuentoTotal >= 0 AND CostoEnvio >= 0
        AND DescuentoTotal <= Subtotal
        AND Total = Subtotal - DescuentoTotal + CostoEnvio
    );
    ALTER TABLE dbo.Pedido ADD CONSTRAINT DF_Pedido_Estado DEFAULT ('PENDIENTE_PAGO') FOR Estado;
    ALTER TABLE dbo.Pedido ADD CONSTRAINT DF_Pedido_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.Pedido ADD CONSTRAINT FK_Pedido_Checkout_Usuario FOREIGN KEY (IDCheckout, IDUsuario)
        REFERENCES dbo.Checkout (IDCheckout, IDUsuario);
    -- Impide seleccionar direcciones ajenas al comprador.
    ALTER TABLE dbo.Pedido ADD CONSTRAINT FK_Pedido_Direccion_Usuario FOREIGN KEY (IDDireccionEntrega, IDUsuario)
        REFERENCES dbo.Direccion (IDDireccion, IDUsuario);
    CREATE INDEX IX_Pedido_Usuario_Fecha ON dbo.Pedido (IDUsuario, FechaCreacion DESC);
    CREATE INDEX IX_Pedido_Estado_Fecha ON dbo.Pedido (Estado, FechaCreacion DESC);

    -- 7. DetallePedido | Lineas e importes historicos, no precios vivos.
    CREATE TABLE dbo.DetallePedido (
        IDDetallePedido BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DetallePedido PRIMARY KEY,
        IDPedido BIGINT NOT NULL,
        IDVariante INT NOT NULL,
        SKUHistorico VARCHAR(64) NOT NULL,
        NombreHistorico NVARCHAR(250) NOT NULL,
        Cantidad INT NOT NULL,
        CantidadDevuelta INT NOT NULL,
        PrecioUnitario DECIMAL(18,2) NOT NULL,
        Subtotal DECIMAL(18,2) NOT NULL,
        Descuento DECIMAL(18,2) NOT NULL,
        Total DECIMAL(18,2) NOT NULL,
        MontoDevuelto DECIMAL(18,2) NOT NULL
    );
    -- Una variante no se repite dentro del mismo pedido.
    ALTER TABLE dbo.DetallePedido ADD CONSTRAINT UQ_DetallePedido_Pedido_Variante UNIQUE (IDPedido, IDVariante);
    ALTER TABLE dbo.DetallePedido ADD CONSTRAINT UQ_DetallePedido_ID_Pedido UNIQUE (IDDetallePedido, IDPedido);
    ALTER TABLE dbo.DetallePedido ADD CONSTRAINT DF_DetallePedido_CantidadDevuelta DEFAULT (0) FOR CantidadDevuelta;
    ALTER TABLE dbo.DetallePedido ADD CONSTRAINT DF_DetallePedido_MontoDevuelto DEFAULT (0) FOR MontoDevuelto;
    -- Cuadran precio, descuento, cantidad y devoluciones.
    ALTER TABLE dbo.DetallePedido ADD CONSTRAINT CK_DetallePedido_Importes CHECK (
        Cantidad > 0 AND PrecioUnitario >= 0
        AND Subtotal = Cantidad * PrecioUnitario
        AND Descuento >= 0 AND Descuento <= Subtotal
        AND Total = Subtotal - Descuento
        AND CantidadDevuelta BETWEEN 0 AND Cantidad
        AND MontoDevuelto BETWEEN 0 AND Total
    );
    ALTER TABLE dbo.DetallePedido ADD CONSTRAINT FK_DetallePedido_Pedido FOREIGN KEY (IDPedido) REFERENCES dbo.Pedido (IDPedido);
    ALTER TABLE dbo.DetallePedido ADD CONSTRAINT FK_DetallePedido_Variante FOREIGN KEY (IDVariante) REFERENCES dbo.Variante (IDVariante);

    -- 8. CompromisoCupon | Apartado temporal de un uso de cupon.
    CREATE TABLE dbo.CompromisoCupon (
        IDCompromisoCupon BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CompromisoCupon PRIMARY KEY,
        IDCupon INT NOT NULL,
        IDCheckout BIGINT NOT NULL,
        IDUsuario INT NOT NULL,
        Estado VARCHAR(20) NOT NULL,
        FechaExpiracion DATETIME2(3) NOT NULL
    );
    -- Un unico cupon por checkout; propietario consistente.
    ALTER TABLE dbo.CompromisoCupon ADD CONSTRAINT UQ_CompromisoCupon_Checkout UNIQUE (IDCheckout);
    ALTER TABLE dbo.CompromisoCupon ADD CONSTRAINT CK_CompromisoCupon_Estado CHECK (Estado IN ('ACTIVO','CONSUMIDO','EXPIRADO','LIBERADO'));
    ALTER TABLE dbo.CompromisoCupon ADD CONSTRAINT DF_CompromisoCupon_Estado DEFAULT ('ACTIVO') FOR Estado;
    ALTER TABLE dbo.CompromisoCupon ADD CONSTRAINT FK_CompromisoCupon_Cupon FOREIGN KEY (IDCupon) REFERENCES dbo.Cupon (IDCupon);
    ALTER TABLE dbo.CompromisoCupon ADD CONSTRAINT FK_CompromisoCupon_Checkout_Usuario FOREIGN KEY (IDCheckout, IDUsuario)
        REFERENCES dbo.Checkout (IDCheckout, IDUsuario);
    CREATE INDEX IX_CompromisoCupon_Cupon_Estado ON dbo.CompromisoCupon (IDCupon, Estado, FechaExpiracion);
    CREATE INDEX IX_CompromisoCupon_Cupon_Usuario ON dbo.CompromisoCupon (IDCupon, IDUsuario, Estado);

    -- 9. ReservaInventario | Compromete stock de una ubicacion por checkout.
    CREATE TABLE dbo.ReservaInventario (
        IDReservaInventario BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReservaInventario PRIMARY KEY,
        IDCheckout BIGINT NOT NULL,
        IDInventarioPorUbicacion INT NOT NULL,
        Cantidad INT NOT NULL,
        Estado VARCHAR(20) NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaExpiracion DATETIME2(3) NOT NULL,
        FechaResolucion DATETIME2(3) NULL
    );
    -- Un compromiso por saldo dentro del mismo checkout.
    ALTER TABLE dbo.ReservaInventario ADD CONSTRAINT UQ_ReservaInventario_Checkout_Inventario UNIQUE (IDCheckout, IDInventarioPorUbicacion);
    ALTER TABLE dbo.ReservaInventario ADD CONSTRAINT CK_ReservaInventario_Cantidad CHECK (Cantidad > 0);
    ALTER TABLE dbo.ReservaInventario ADD CONSTRAINT CK_ReservaInventario_Estado CHECK (Estado IN ('ACTIVA','CONSUMIDA','EXPIRADA','LIBERADA'));
    ALTER TABLE dbo.ReservaInventario ADD CONSTRAINT CK_ReservaInventario_Vigencia CHECK (FechaExpiracion > FechaCreacion);
    ALTER TABLE dbo.ReservaInventario ADD CONSTRAINT DF_ReservaInventario_Estado DEFAULT ('ACTIVA') FOR Estado;
    ALTER TABLE dbo.ReservaInventario ADD CONSTRAINT DF_ReservaInventario_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.ReservaInventario ADD CONSTRAINT FK_ReservaInventario_Checkout FOREIGN KEY (IDCheckout) REFERENCES dbo.Checkout (IDCheckout);
    ALTER TABLE dbo.ReservaInventario ADD CONSTRAINT FK_ReservaInventario_Inventario FOREIGN KEY (IDInventarioPorUbicacion)
        REFERENCES dbo.InventarioPorUbicacion (IDInventarioPorUbicacion);
    CREATE INDEX IX_ReservaInventario_Estado_Expiracion ON dbo.ReservaInventario (Estado, FechaExpiracion);
    CREATE INDEX IX_ReservaInventario_Inventario_Estado ON dbo.ReservaInventario (IDInventarioPorUbicacion, Estado);

    -- 10. IntentoPago | Identifica reintentos sin duplicar cobros.
    CREATE TABLE dbo.IntentoPago (
        IDIntentoPago BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_IntentoPago PRIMARY KEY,
        IDPedido BIGINT NOT NULL,
        ClaveIdempotencia UNIQUEIDENTIFIER NOT NULL,
        HuellaSolicitud VARBINARY(32) NOT NULL,
        Estado VARCHAR(20) NOT NULL,
        Monto DECIMAL(18,2) NOT NULL,
        ReferenciaProcesador VARCHAR(100) NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaResolucion DATETIME2(3) NULL
    );
    ALTER TABLE dbo.IntentoPago ADD CONSTRAINT UQ_IntentoPago_Clave UNIQUE (ClaveIdempotencia);
    ALTER TABLE dbo.IntentoPago ADD CONSTRAINT CK_IntentoPago_Estado CHECK (Estado IN ('PENDIENTE','PROCESANDO','EXITOSO','FALLIDO','INDETERMINADO'));
    ALTER TABLE dbo.IntentoPago ADD CONSTRAINT CK_IntentoPago_Monto CHECK (Monto >= 0);
    ALTER TABLE dbo.IntentoPago ADD CONSTRAINT DF_IntentoPago_Estado DEFAULT ('PENDIENTE') FOR Estado;
    ALTER TABLE dbo.IntentoPago ADD CONSTRAINT DF_IntentoPago_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.IntentoPago ADD CONSTRAINT FK_IntentoPago_Pedido FOREIGN KEY (IDPedido) REFERENCES dbo.Pedido (IDPedido);
    -- Solo un pago exitoso por pedido, aunque existan varios intentos.
    CREATE UNIQUE INDEX UX_IntentoPago_Pedido_Exitoso ON dbo.IntentoPago (IDPedido) WHERE Estado = 'EXITOSO';
    CREATE INDEX IX_IntentoPago_Pedido_Fecha ON dbo.IntentoPago (IDPedido, FechaCreacion DESC);

    -- 11. UsoCupon | Un consumo confirmado por pedido.
    CREATE TABLE dbo.UsoCupon (
        IDUsoCupon BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_UsoCupon PRIMARY KEY,
        IDCupon INT NOT NULL,
        IDPedido BIGINT NOT NULL,
        IDUsuario INT NOT NULL,
        DescuentoAplicado DECIMAL(18,2) NOT NULL,
        FechaUso DATETIME2(3) NOT NULL
    );
    ALTER TABLE dbo.UsoCupon ADD CONSTRAINT UQ_UsoCupon_Pedido UNIQUE (IDPedido);
    ALTER TABLE dbo.UsoCupon ADD CONSTRAINT CK_UsoCupon_Descuento CHECK (DescuentoAplicado >= 0);
    ALTER TABLE dbo.UsoCupon ADD CONSTRAINT DF_UsoCupon_FechaUso DEFAULT (SYSUTCDATETIME()) FOR FechaUso;
    ALTER TABLE dbo.UsoCupon ADD CONSTRAINT FK_UsoCupon_Cupon FOREIGN KEY (IDCupon) REFERENCES dbo.Cupon (IDCupon);
    -- El cliente asociado al uso debe ser dueno del pedido.
    ALTER TABLE dbo.UsoCupon ADD CONSTRAINT FK_UsoCupon_Pedido_Usuario FOREIGN KEY (IDPedido, IDUsuario)
        REFERENCES dbo.Pedido (IDPedido, IDUsuario);
    CREATE INDEX IX_UsoCupon_Cupon_Usuario ON dbo.UsoCupon (IDCupon, IDUsuario);

    -- 12. MovimientoInventario | Kardex fisico trazable a venta o ajuste.
    -- El origen DEVOLUCION se agregara junto con sus FK en la migracion 004.
    CREATE TABLE dbo.MovimientoInventario (
        IDMovimientoInventario BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_MovimientoInventario PRIMARY KEY,
        IDInventarioPorUbicacion INT NOT NULL,
        IDUsuario INT NOT NULL,
        IDDetallePedido BIGINT NULL,
        TipoMovimiento VARCHAR(25) NOT NULL,
        CantidadCambio INT NOT NULL,
        Motivo NVARCHAR(300) NOT NULL,
        FechaMovimiento DATETIME2(3) NOT NULL
    );
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT CK_MovimientoInventario_Cantidad CHECK (CantidadCambio <> 0);
    -- La direccion del cambio debe concordar con el tipo de movimiento.
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT CK_MovimientoInventario_Tipo CHECK (
        (TipoMovimiento IN ('ENTRADA_INICIAL','ENTRADA_MANUAL','CANCELACION') AND CantidadCambio > 0)
        OR (TipoMovimiento = 'SALIDA_VENTA' AND CantidadCambio < 0)
        OR (TipoMovimiento = 'AJUSTE' AND CantidadCambio <> 0)
    );
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT CK_MovimientoInventario_Origen CHECK (
        (TipoMovimiento IN ('SALIDA_VENTA','CANCELACION') AND IDDetallePedido IS NOT NULL)
        OR (TipoMovimiento IN ('ENTRADA_INICIAL','ENTRADA_MANUAL','AJUSTE') AND IDDetallePedido IS NULL)
    );
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT CK_MovimientoInventario_Motivo CHECK (LEN(LTRIM(RTRIM(Motivo))) > 0);
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT DF_MovimientoInventario_Fecha DEFAULT (SYSUTCDATETIME()) FOR FechaMovimiento;
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT FK_MovimientoInventario_Inventario FOREIGN KEY (IDInventarioPorUbicacion)
        REFERENCES dbo.InventarioPorUbicacion (IDInventarioPorUbicacion);
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT FK_MovimientoInventario_Usuario FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuario (IDUsuario);
    ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT FK_MovimientoInventario_DetallePedido FOREIGN KEY (IDDetallePedido)
        REFERENCES dbo.DetallePedido (IDDetallePedido);
    -- Una salida o cancelacion por linea y ubicacion.
    CREATE UNIQUE INDEX UX_MovimientoInventario_Venta_Cancelacion ON dbo.MovimientoInventario
        (IDDetallePedido, TipoMovimiento, IDInventarioPorUbicacion)
        WHERE IDDetallePedido IS NOT NULL;
    CREATE INDEX IX_MovimientoInventario_Inventario_Fecha ON dbo.MovimientoInventario
        (IDInventarioPorUbicacion, FechaMovimiento DESC);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
