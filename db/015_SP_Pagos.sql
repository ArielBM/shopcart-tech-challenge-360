/* ShopCart | 015_SP_Pagos.sql
   Crea:
   - SP_Pagos_IniciarIntento
   - SP_Pagos_RegistrarFallo
*/
USE ShopCartDB;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Pagos_IniciarIntento
    @IDCheckout BIGINT,
    @IDUsuario INT,
    @IDDireccion BIGINT,
    @ClaveIdempotencia UNIQUEIDENTIFIER,
    @HuellaSolicitud VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @IDCheckout IS NULL
       OR @IDCheckout <= 0
       OR @IDUsuario IS NULL
       OR @IDUsuario <= 0
       OR @IDDireccion IS NULL
       OR @IDDireccion <= 0
       OR @ClaveIdempotencia IS NULL
       OR @HuellaSolicitud IS NULL
       OR DATALENGTH(@HuellaSolicitud) <> 32
        THROW 51900, N'Parametros de pago invalidos.', 1;
    
    DECLARE @IDCarrito AS BIGINT;
    
    DECLARE @IDIntentoPago AS BIGINT;
    
    DECLARE @EstadoCheckout AS VARCHAR(20);
    
    DECLARE @EstadoIntento AS VARCHAR(20);
    
    DECLARE @FechaExpiracion AS DATETIME2(3);
    
    DECLARE @HuellaExistente AS VARBINARY(32);
    
    DECLARE @IDCheckoutExistente AS BIGINT;
    
    DECLARE @MontoExistente AS DECIMAL(18,2);
    
    DECLARE @MontoAmplio AS DECIMAL(38,2);
    
    DECLARE @Monto AS DECIMAL(18,2);
    
    DECLARE @ResultadoBloqueo AS INT;
    
    DECLARE @Recurso AS NVARCHAR(255);
    
    DECLARE @Ahora AS DATETIME2(3);
    
    BEGIN TRY
        -- Lectura preliminar. Se revalida en la transaccion.
        SELECT @IDCarrito = IDCarrito
        FROM dbo.Checkout
        WHERE IDCheckout = @IDCheckout
              AND IDUsuario = @IDUsuario;
        
        IF @IDCarrito IS NULL
            THROW 51901, N'Checkout no encontrado.', 1;
        
        BEGIN TRANSACTION;
        
        -- Mismo orden de bloqueo que checkout y carrito.
        SET @Recurso = CONCAT(N'Carrito:Usuario:', @IDUsuario);
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51902, N'No se pudo bloquear el carrito.', 1;
        
        -- Serializar el uso global de la clave.
        SET @Recurso = CONCAT(N'Pago:Clave:', CONVERT (VARCHAR(36), @ClaveIdempotencia));
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51903, N'No se pudo bloquear el intento.', 1;
        
        -- Comprobar primero un intento existente:
        -- un reintento debe recuperar su resultado.
        SELECT @IDIntentoPago = IDIntentoPago,
               @IDCheckoutExistente = IDCheckout,
               @HuellaExistente = HuellaSolicitud,
               @EstadoIntento = Estado,
               @MontoExistente = Monto
        FROM dbo.IntentoPago WITH (UPDLOCK, HOLDLOCK)
        WHERE ClaveIdempotencia = @ClaveIdempotencia;
        
        IF @IDIntentoPago IS NOT NULL
            BEGIN
                IF @IDCheckoutExistente <> @IDCheckout
                   OR @HuellaExistente <> @HuellaSolicitud
                    THROW 51904, N'Clave de idempotencia reutilizada.', 1;
                
                -- Revalidar propiedad incluso en reintentos.
                IF NOT EXISTS (SELECT 1
                               FROM dbo.Checkout
                               WHERE IDCheckout = @IDCheckout
                                     AND IDUsuario = @IDUsuario)
                    THROW 51901, N'Checkout no encontrado.', 1;
                
                COMMIT TRANSACTION;
                
                SELECT @IDIntentoPago AS IDIntentoPago,
                       @IDCheckout AS IDCheckout,
                       @EstadoIntento AS Estado,
                       @MontoExistente AS Monto,
                       CAST (1 AS BIT) AS Reutilizado;
                
                RETURN;
            END
        
        -- Validar checkout y plazo de reserva.
        SELECT @EstadoCheckout = Estado,
               @FechaExpiracion = FechaExpiracion
        FROM dbo.Checkout WITH (UPDLOCK, HOLDLOCK)
        WHERE IDCheckout = @IDCheckout
              AND IDUsuario = @IDUsuario
              AND IDCarrito = @IDCarrito;
        
        SET @Ahora = SYSUTCDATETIME();
        
        IF @EstadoCheckout IS NULL
           OR @EstadoCheckout <> 'ACTIVO'
           OR @FechaExpiracion <= @Ahora
            THROW 51905, N'Checkout no activo o vencido.', 1;
        
        -- La direccion debe ser propia y estar activa.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Direccion
                       WHERE IDDireccion = @IDDireccion
                             AND IDUsuario = @IDUsuario
                             AND Activa = 1)
            THROW 51906, N'Direccion de entrega no disponible.', 1;
        
        -- No admitir otro intento sin resolver.
        IF EXISTS (SELECT 1
                   FROM dbo.IntentoPago WITH (UPDLOCK, HOLDLOCK)
                   WHERE IDCheckout = @IDCheckout
                         AND Estado IN ('PENDIENTE', 'PROCESANDO', 'INDETERMINADO'))
            THROW 51907, N'Existe un intento de pago pendiente.', 1;
        
        -- Un checkout no puede tener dos pagos exitosos.
        IF EXISTS (SELECT 1
                   FROM dbo.IntentoPago
                   WHERE IDCheckout = @IDCheckout
                         AND Estado = 'EXITOSO')
            THROW 51908, N'El checkout ya tiene un pago exitoso.', 1;
        
        -- Calcular el monto congelado, no el precio actual.
        SELECT @MontoAmplio = SUM(CONVERT (DECIMAL(38,2), Total))
        FROM dbo.DetalleCheckout
        WHERE IDCheckout = @IDCheckout;
        
        IF @MontoAmplio IS NULL
           OR @MontoAmplio > 9999999999999999.99
           OR @MontoAmplio < 0
           OR EXISTS (SELECT 1
                      FROM dbo.DetalleCheckout
                      WHERE IDCheckout = @IDCheckout
                            AND Descuento <> 0)
            THROW 51909, N'La cotizacion no es valida.', 1;
        
        -- Corroborar correspondencia entre cotizacion
        -- y reservas de inventario.
        IF EXISTS (SELECT 1
                   FROM dbo.DetalleCheckout AS d
                   WHERE d.IDCheckout = @IDCheckout
                         AND NOT EXISTS (SELECT 1
                                         FROM dbo.ReservaInventario AS r
                                              INNER JOIN
                                              dbo.InventarioPorUbicacion AS i
                                              ON i.IDInventarioPorUbicacion = r.IDInventarioPorUbicacion
                                         WHERE r.IDCheckout = d.IDCheckout
                                               AND i.IDVariante = d.IDVariante
                                               AND r.Cantidad = d.Cantidad
                                               AND r.Estado = 'ACTIVA'
                                               AND r.FechaExpiracion > @Ahora))
           OR (SELECT COUNT_BIG(*)
               FROM dbo.DetalleCheckout
               WHERE IDCheckout = @IDCheckout) <> (SELECT COUNT_BIG(*)
                                                   FROM dbo.ReservaInventario
                                                   WHERE IDCheckout = @IDCheckout
                                                         AND Estado = 'ACTIVA')
            THROW 51910, N'Las reservas no coinciden con la cotizacion.', 1;
        
        SET @Monto = CONVERT (DECIMAL(18,2), @MontoAmplio);
        
        INSERT INTO dbo.IntentoPago (
            IDCheckout,
            IDPedido,
            ClaveIdempotencia,
            HuellaSolicitud,
            Estado,
            Monto,
            ReferenciaProcesador,
            FechaCreacion,
            FechaResolucion
        )
        VALUES                      (@IDCheckout, NULL, @ClaveIdempotencia, @HuellaSolicitud, 'PENDIENTE', @Monto, NULL, @Ahora, NULL);
        
        SET @IDIntentoPago = CONVERT (BIGINT, SCOPE_IDENTITY());
        
        COMMIT TRANSACTION;
        
        SELECT @IDIntentoPago AS IDIntentoPago,
               @IDCheckout AS IDCheckout,
               CAST ('PENDIENTE' AS VARCHAR(20)) AS Estado,
               @Monto AS Monto,
               CAST (0 AS BIT) AS Reutilizado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Pagos_RegistrarFallo
    @IDCheckout BIGINT,
    @IDUsuario INT,
    @ClaveIdempotencia UNIQUEIDENTIFIER,
    @HuellaSolicitud VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @IDCheckout IS NULL
       OR @IDCheckout <= 0
       OR @IDUsuario IS NULL
       OR @IDUsuario <= 0
       OR @ClaveIdempotencia IS NULL
       OR @HuellaSolicitud IS NULL
       OR DATALENGTH(@HuellaSolicitud) <> 32
        THROW 51911, N'Parametros de pago invalidos.', 1;
    
    DECLARE @IDCarrito AS BIGINT;
    
    DECLARE @IDIntentoPago AS BIGINT;
    
    DECLARE @Estado AS VARCHAR(20);
    
    DECLARE @HuellaExistente AS VARBINARY(32);
    
    DECLARE @ResultadoBloqueo AS INT;
    
    DECLARE @Recurso AS NVARCHAR(255);
    
    DECLARE @Ahora AS DATETIME2(3);
    
    DECLARE @Reutilizado AS BIT = 0;
    
    BEGIN TRY
        -- Lectura preliminar; la propiedad se valida
        -- nuevamente dentro de la transaccion.
        SELECT @IDCarrito = IDCarrito
        FROM dbo.Checkout
        WHERE IDCheckout = @IDCheckout
              AND IDUsuario = @IDUsuario;
        
        IF @IDCarrito IS NULL
            THROW 51912, N'Checkout no encontrado.', 1;
        
        BEGIN TRANSACTION;
        
        -- Bloquear operaciones concurrentes del carrito.
        SET @Recurso = CONCAT(N'Carrito:Usuario:', @IDUsuario);
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51913, N'No se pudo bloquear el carrito.', 1;
        
        -- Serializar operaciones con la misma clave.
        SET @Recurso = CONCAT(N'Pago:Clave:', CONVERT (VARCHAR(36), @ClaveIdempotencia));
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51914, N'No se pudo bloquear el intento.', 1;
        
        -- Recuperar el intento registrado.
        SELECT @IDIntentoPago = p.IDIntentoPago,
               @Estado = p.Estado,
               @HuellaExistente = p.HuellaSolicitud
        FROM dbo.IntentoPago AS p WITH (UPDLOCK, HOLDLOCK)
             INNER JOIN
             dbo.Checkout AS c
             ON c.IDCheckout = p.IDCheckout
        WHERE p.ClaveIdempotencia = @ClaveIdempotencia
              AND p.IDCheckout = @IDCheckout
              AND c.IDUsuario = @IDUsuario;
        
        IF @IDIntentoPago IS NULL
            THROW 51915, N'Intento de pago no encontrado.', 1;
        
        IF @HuellaExistente <> @HuellaSolicitud
            THROW 51916, N'La solicitud no coincide.', 1;
        
        -- Solo se permiten intentos pendientes o
        -- intentos fallidos que se estén reconsultando.
        IF @Estado NOT IN ('PENDIENTE', 'FALLIDO')
            THROW 51918, N'El intento no admite registrar un fallo.', 1;
        
        -- Reintento idempotente: no modificar nuevamente.
        IF @Estado = 'FALLIDO'
            BEGIN
                SET @Reutilizado = 1;
            END
        
        -- Resolver un intento pendiente como fallido.
        IF @Estado = 'PENDIENTE'
            BEGIN
                SET @Ahora = SYSUTCDATETIME();
                
                UPDATE dbo.IntentoPago
                SET Estado          = 'FALLIDO',
                    FechaResolucion = @Ahora
                WHERE IDIntentoPago = @IDIntentoPago
                      AND Estado = 'PENDIENTE';
                
                IF @@ROWCOUNT <> 1
                    THROW 51917, N'El intento cambio de estado.', 1;
            END
        
        COMMIT TRANSACTION;
        
        SELECT @IDIntentoPago AS IDIntentoPago,
               @IDCheckout AS IDCheckout,
               CAST ('FALLIDO' AS VARCHAR(20)) AS Estado,
               @Reutilizado AS Reutilizado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        THROW;
    END CATCH
END