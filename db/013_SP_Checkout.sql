/* ShopCart | 013_SP_Checkout.sql
   Crea: 
   - SP_Checkout_Iniciar´
   - SP_Checkout_ExpirarReservas
   - SP_Checkout_Cancelar
   - SP_Checkout_ConfirmarPago
*/
USE ShopCartDB;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Checkout_Iniciar
    @IDUsuario INT,
    @ClaveInicio UNIQUEIDENTIFIER,
    @HuellaSolicitud VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @IDUsuario IS NULL
       OR @IDUsuario <= 0
        THROW 51700, N'El cliente no es valido.', 1;
    
    IF @ClaveInicio IS NULL
       OR @HuellaSolicitud IS NULL
        THROW 51701, N'La clave y la huella son obligatorias.', 1;
    
    DECLARE @IDCheckout AS BIGINT;
    
    DECLARE @IDCarrito AS BIGINT;
    
    DECLARE @IDUbicacion AS INT;
    
    DECLARE @Estado AS VARCHAR(20);
    
    DECLARE @FechaExpiracion AS DATETIME2(3);
    
    DECLARE @HuellaExistente AS VARBINARY(32);
    
    DECLARE @PropietarioExistente AS INT;
    
    DECLARE @ResultadoBloqueo AS INT;
    
    DECLARE @Recurso AS NVARCHAR(255);
    
    DECLARE @Ahora AS DATETIME2(3);
    
    DECLARE @IDVariante AS INT;
    
    DECLARE @Cantidad AS INT;
    
    DECLARE @IDInventario AS INT;
    
    DECLARE @Disponible AS BIGINT;
    
    -- Datos comerciales congelados.
    DECLARE @Precio AS DECIMAL(18,2);
    
    DECLARE @SKU AS VARCHAR(64);
    
    DECLARE @Nombre AS NVARCHAR(250);
    
    DECLARE @SubtotalLineaAmplio AS DECIMAL(38,2);
    
    DECLARE @SubtotalLinea AS DECIMAL(18,2);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Una clave se procesa por una sola transacción,
        -- incluso cuando pertenece a clientes diferentes.
        SET @Recurso = CONCAT(N'Checkout:Clave:', CONVERT (VARCHAR(36), @ClaveInicio));
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51702, N'No se pudo bloquear el inicio de checkout.', 1;
        
        -- Idempotencia: devolver el checkout existente.
        SELECT @IDCheckout = IDCheckout,
               @PropietarioExistente = IDUsuario,
               @HuellaExistente = HuellaSolicitud,
               @Estado = Estado,
               @FechaExpiracion = FechaExpiracion
        FROM dbo.Checkout WITH (UPDLOCK, HOLDLOCK)
        WHERE ClaveInicio = @ClaveInicio;
        
        IF @IDCheckout IS NOT NULL
            BEGIN
                IF @PropietarioExistente <> @IDUsuario
                   OR @HuellaExistente <> @HuellaSolicitud
                    THROW 51703, N'La clave de idempotencia ya se utilizo para otra solicitud.', 1;
                
                COMMIT TRANSACTION;
                
                SELECT @IDCheckout AS IDCheckout,
                       @Estado AS Estado,
                       @FechaExpiracion AS FechaExpiracion,
                       CAST (1 AS BIT) AS Reutilizado;
                
                RETURN;
            END
        
        -- Mismo recurso utilizado por las operaciones
        -- del carrito del módulo RF-04.
        SET @Recurso = CONCAT(N'Carrito:Usuario:', @IDUsuario);
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51704, N'No se pudo bloquear el carrito.', 1;
        
        SELECT TOP (1) @IDCarrito = IDCarrito
        FROM dbo.Carrito WITH (UPDLOCK, HOLDLOCK)
        WHERE IDUsuario = @IDUsuario
              AND Estado = 'ACTIVO'
        ORDER BY IDCarrito DESC;
        
        IF @IDCarrito IS NULL
            THROW 51705, N'El cliente no tiene un carrito activo.', 1;
        
        IF NOT EXISTS (SELECT 1
                       FROM dbo.DetalleCarrito
                       WHERE IDCarrito = @IDCarrito)
            THROW 51706, N'El carrito esta vacio.', 1;
        
        -- Capturar un único instante para verificar
        -- la vigencia de checkouts anteriores.
        SET @Ahora = SYSUTCDATETIME();
        
        -- No permitir otro checkout si existe uno vigente.
        IF EXISTS (SELECT 1
                   FROM dbo.Checkout WITH (UPDLOCK, HOLDLOCK)
                   WHERE IDCarrito = @IDCarrito
                         AND Estado = 'ACTIVO'
                         AND FechaExpiracion > @Ahora)
            THROW 51707, N'El carrito ya tiene un checkout activo.', 1;
        
        -- Una reserva vencida debe liberarse antes
        -- de iniciar otra sobre el mismo carrito.
        IF EXISTS (SELECT 1
                   FROM dbo.Checkout WITH (UPDLOCK, HOLDLOCK)
                   WHERE IDCarrito = @IDCarrito
                         AND Estado = 'ACTIVO'
                         AND FechaExpiracion <= @Ahora)
            THROW 51712, N'La reserva anterior vencio y esta pendiente de liberacion. Intenta nuevamente.', 1;
        
        -- Localizar la bodega central.
        SELECT @IDUbicacion = IDUbicacion
        FROM dbo.Ubicacion
        WHERE Codigo = 'BOD-CENTRAL'
              AND Activa = 1;
        
        IF @IDUbicacion IS NULL
            THROW 51708, N'La bodega central no esta disponible.', 1;
        
        -- Recorrer variantes en orden fijo para
        -- reducir el riesgo de deadlocks.
        DECLARE Lineas CURSOR LOCAL FAST_FORWARD
            FOR SELECT IDVariante,
                       Cantidad
                FROM dbo.DetalleCarrito
                WHERE IDCarrito = @IDCarrito
                ORDER BY IDVariante;
        
        -- Capturar el instante real de creación.
        -- La reserva tiene una vigencia de 15 minutos.
        SET @Ahora = SYSUTCDATETIME();
        
        SET @FechaExpiracion = DATEADD(MINUTE, 15, @Ahora);
        
        INSERT INTO dbo.Checkout (
            IDCarrito,
            IDUsuario,
            ClaveInicio,
            HuellaSolicitud,
            Estado,
            FechaCreacion,
            FechaExpiracion
        )
        VALUES                   (@IDCarrito, @IDUsuario, @ClaveInicio, @HuellaSolicitud, 'ACTIVO', @Ahora, @FechaExpiracion);
        
        SET @IDCheckout = CONVERT (BIGINT, SCOPE_IDENTITY());
        
        OPEN Lineas;
        
        FETCH NEXT FROM Lineas INTO @IDVariante, @Cantidad;
        
        WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Comprobar disponibilidad comercial y
                -- obtener los datos que deben congelarse.
                SET @Precio = NULL;
                
                SET @SKU = NULL;
                
                SET @Nombre = NULL;
                
                SELECT @Precio = v.PrecioActual,
                       @SKU = v.SKU,
                       @Nombre = p.Nombre
                FROM dbo.Variante AS v WITH (UPDLOCK, HOLDLOCK)
                     INNER JOIN
                     dbo.Producto AS p
                     ON p.IDProducto = v.IDProducto
                     INNER JOIN
                     dbo.Categoria AS c
                     ON c.IDCategoria = p.IDCategoria
                WHERE v.IDVariante = @IDVariante
                      AND v.Activa = 1
                      AND p.Activo = 1
                      AND c.Activa = 1;
                
                IF @Precio IS NULL
                   OR @SKU IS NULL
                   OR @Nombre IS NULL
                    THROW 51709, N'Una variante del carrito ya no esta disponible.', 1;
                
                -- Bloqueo exclusivo del inventario.
                SET @Recurso = CONCAT(N'Inventario:', @IDVariante, N':', @IDUbicacion);
                
                EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
                
                IF @ResultadoBloqueo < 0
                    THROW 51710, N'No se pudo bloquear el inventario.', 1;
                
                SET @IDInventario = NULL;
                
                SET @Disponible = 0;
                
                SELECT @IDInventario = IDInventarioPorUbicacion,
                       @Disponible = CONVERT (BIGINT, ExistenciaFisica) - CantidadReservada
                FROM dbo.InventarioPorUbicacion WITH (UPDLOCK, HOLDLOCK)
                WHERE IDVariante = @IDVariante
                      AND IDUbicacion = @IDUbicacion;
                
                -- Evitar sobreventa.
                IF @IDInventario IS NULL
                   OR @Disponible < @Cantidad
                    THROW 51711, N'Existencia insuficiente para una variante del carrito.', 1;
                
                -- Calcular el importe con precisión decimal.
                SET @SubtotalLineaAmplio = CONVERT (DECIMAL(38,2), CONVERT (DECIMAL(18,2), @Cantidad) * @Precio);
                
                IF @SubtotalLineaAmplio > 9999999999999999.99
                    THROW 51713, N'El importe de la linea excede el limite permitido.', 1;
                
                SET @SubtotalLinea = CONVERT (DECIMAL(18,2), @SubtotalLineaAmplio);
                
                -- Incrementar inventario reservado.
                UPDATE dbo.InventarioPorUbicacion
                SET CantidadReservada  = CantidadReservada + @Cantidad,
                    FechaActualizacion = @Ahora
                WHERE IDInventarioPorUbicacion = @IDInventario
                      AND ExistenciaFisica - CantidadReservada >= @Cantidad;
                
                IF @@ROWCOUNT <> 1
                    THROW 51711, N'Existencia insuficiente para una variante del carrito.', 1;
                
                -- Registrar la reserva individual.
                INSERT INTO dbo.ReservaInventario (
                    IDCheckout,
                    IDInventarioPorUbicacion,
                    Cantidad,
                    Estado,
                    FechaCreacion,
                    FechaExpiracion
                )
                VALUES                            (@IDCheckout, @IDInventario, @Cantidad, 'ACTIVA', @Ahora, @FechaExpiracion);
                
                -- Congelar las condiciones comerciales.
                -- Descuento = 0 hasta integrar RF-05.
                INSERT INTO dbo.DetalleCheckout (
                    IDCheckout,
                    IDVariante,
                    SKUHistorico,
                    NombreHistorico,
                    Cantidad,
                    PrecioUnitario,
                    Subtotal,
                    Descuento,
                    Total
                )
                VALUES                          (@IDCheckout, @IDVariante, @SKU, @Nombre, @Cantidad, @Precio, @SubtotalLinea, 0, @SubtotalLinea);
                
                FETCH NEXT FROM Lineas INTO @IDVariante, @Cantidad;
            END
        
        CLOSE Lineas;
        
        DEALLOCATE Lineas;
        
        COMMIT TRANSACTION;
        
        SELECT @IDCheckout AS IDCheckout,
               CAST ('ACTIVO' AS VARCHAR(20)) AS Estado,
               @FechaExpiracion AS FechaExpiracion,
               CAST (0 AS BIT) AS Reutilizado;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'Lineas') >= 0
            CLOSE Lineas;
        
        IF CURSOR_STATUS('local', 'Lineas') >= -1
            DEALLOCATE Lineas;
        
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Checkout_ExpirarReservas
    @Limite INT=50
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @Limite IS NULL
       OR @Limite NOT BETWEEN 1 AND 500
        THROW 51720, N'El limite debe estar entre 1 y 500.', 1;
    
    DECLARE @Procesados AS INT = 0;
    
    DECLARE @IDCheckout AS BIGINT;
    
    DECLARE @IDCarrito AS BIGINT;
    
    DECLARE @IDUsuario AS INT;
    
    DECLARE @Estado AS VARCHAR(20);
    
    DECLARE @Vence AS DATETIME2(3);
    
    DECLARE @Ahora AS DATETIME2(3);
    
    DECLARE @Resultado AS INT;
    
    DECLARE @Recurso AS NVARCHAR(255);
    
    DECLARE @IDReserva AS BIGINT;
    
    DECLARE @IDInventario AS INT;
    
    DECLARE @IDVariante AS INT;
    
    DECLARE @IDUbicacion AS INT;
    
    DECLARE @Cantidad AS INT;
    
    -- Evita que dos instancias del trabajador seleccionen el mismo lote.
    EXECUTE @Resultado = sys.sp_getapplock @Resource = N'Checkout:Expiracion', @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0;
    
    IF @Resultado < 0
        BEGIN
            SELECT CAST (0 AS INT) AS CheckoutsExpirados;
            
            RETURN;
        END
    
    BEGIN TRY
        WHILE @Procesados < @Limite
            BEGIN
                SET @IDCheckout = NULL;
                
                SET @Ahora = SYSUTCDATETIME();
                
                SELECT TOP (1) @IDCheckout = IDCheckout,
                               @IDCarrito = IDCarrito,
                               @IDUsuario = IDUsuario
                FROM dbo.Checkout
                WHERE Estado = 'ACTIVO'
                      AND FechaExpiracion <= @Ahora
                ORDER BY FechaExpiracion, IDCheckout;
                
                IF @IDCheckout IS NULL
                    BREAK;
                
                BEGIN TRANSACTION;
                
                -- Misma disciplina de bloqueo que SP_Checkout_Iniciar.
                SET @Recurso = CONCAT(N'Carrito:Usuario:', @IDUsuario);
                
                EXECUTE @Resultado = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
                
                IF @Resultado < 0
                    THROW 51721, N'No se pudo bloquear el carrito.', 1;
                
                SET @Estado = NULL;
                
                SELECT @Estado = Estado,
                       @Vence = FechaExpiracion
                FROM dbo.Checkout WITH (UPDLOCK, HOLDLOCK)
                WHERE IDCheckout = @IDCheckout
                      AND IDCarrito = @IDCarrito
                      AND IDUsuario = @IDUsuario;
                
                SET @Ahora = SYSUTCDATETIME();
                
                IF @Estado = 'ACTIVO'
                   AND @Vence <= @Ahora
                    BEGIN
                        -- Orden global por variante/ubicación, igual en operaciones comerciales.
                        DECLARE Reservas CURSOR LOCAL FAST_FORWARD
                            FOR SELECT r.IDReservaInventario,
                                       r.IDInventarioPorUbicacion,
                                       i.IDVariante,
                                       i.IDUbicacion,
                                       r.Cantidad
                                FROM dbo.ReservaInventario AS r
                                     INNER JOIN
                                     dbo.InventarioPorUbicacion AS i
                                     ON i.IDInventarioPorUbicacion = r.IDInventarioPorUbicacion
                                WHERE r.IDCheckout = @IDCheckout
                                      AND r.Estado = 'ACTIVA'
                                ORDER BY i.IDVariante, i.IDUbicacion;
                        
                        OPEN Reservas;
                        
                        FETCH NEXT FROM Reservas INTO @IDReserva, @IDInventario, @IDVariante, @IDUbicacion, @Cantidad;
                        
                        WHILE @@FETCH_STATUS = 0
                            BEGIN
                                SET @Recurso = CONCAT(N'Inventario:', @IDVariante, N':', @IDUbicacion);
                                
                                EXECUTE @Resultado = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
                                
                                IF @Resultado < 0
                                    THROW 51722, N'No se pudo bloquear el inventario.', 1;
                                
                                UPDATE dbo.InventarioPorUbicacion
                                SET CantidadReservada  = CantidadReservada - @Cantidad,
                                    FechaActualizacion = @Ahora
                                WHERE IDInventarioPorUbicacion = @IDInventario
                                      AND CantidadReservada >= @Cantidad;
                                
                                IF @@ROWCOUNT <> 1
                                    THROW 51723, N'Inconsistencia entre inventario y reservas.', 1;
                                
                                UPDATE dbo.ReservaInventario
                                SET Estado          = 'EXPIRADA',
                                    FechaResolucion = @Ahora
                                WHERE IDReservaInventario = @IDReserva
                                      AND Estado = 'ACTIVA';
                                
                                IF @@ROWCOUNT <> 1
                                    THROW 51724, N'La reserva cambió durante la expiración.', 1;
                                
                                FETCH NEXT FROM Reservas INTO @IDReserva, @IDInventario, @IDVariante, @IDUbicacion, @Cantidad;
                            END
                        
                        CLOSE Reservas;
                        
                        DEALLOCATE Reservas;
                        
                        UPDATE dbo.CompromisoCupon
                        SET Estado = 'EXPIRADO'
                        WHERE IDCheckout = @IDCheckout
                              AND Estado = 'ACTIVO';
                        
                        UPDATE dbo.Checkout
                        SET Estado          = 'EXPIRADO',
                            FechaResolucion = @Ahora
                        WHERE IDCheckout = @IDCheckout
                              AND Estado = 'ACTIVO';
                        
                        -- Un pedido pendiente puede existir cuando se implemente RF-06 pago.
                        -- El estado se actualizará aquí junto al historial en ese bloque.
                        SET @Procesados += 1;
                    END
                
                COMMIT TRANSACTION;
            END
        
        EXECUTE sys.sp_releaseapplock @Resource = N'Checkout:Expiracion', @LockOwner = 'Session';
        
        SELECT @Procesados AS CheckoutsExpirados;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'Reservas') >= 0
            CLOSE Reservas;
        
        IF CURSOR_STATUS('local', 'Reservas') >= -1
            DEALLOCATE Reservas;
        
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        EXECUTE sys.sp_releaseapplock @Resource = N'Checkout:Expiracion', @LockOwner = 'Session';
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Checkout_Cancelar
    @IDCheckout BIGINT,
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @IDCheckout IS NULL
       OR @IDCheckout <= 0
       OR @IDUsuario IS NULL
       OR @IDUsuario <= 0
        THROW 51730, N'Identificadores invalidos.', 1;
    
    DECLARE @IDCarrito AS BIGINT;
    
    DECLARE @Estado AS VARCHAR(20);
    
    DECLARE @FechaExpiracion AS DATETIME2(3);
    
    DECLARE @Ahora AS DATETIME2(3);
    
    DECLARE @Resultado AS INT;
    
    DECLARE @Recurso AS NVARCHAR(255);
    
    DECLARE @IDReserva AS BIGINT;
    
    DECLARE @IDInventario AS INT;
    
    DECLARE @IDVariante AS INT;
    
    DECLARE @IDUbicacion AS INT;
    
    DECLARE @Cantidad AS INT;
    
    DECLARE @Cancelado AS BIT = 0;
    
    BEGIN TRY
        -- Identificar propietario antes de bloquear.
        SELECT @IDCarrito = IDCarrito
        FROM dbo.Checkout
        WHERE IDCheckout = @IDCheckout
              AND IDUsuario = @IDUsuario;
        
        IF @IDCarrito IS NULL
            THROW 51731, N'Checkout no encontrado.', 1;
        
        BEGIN TRANSACTION;
        
        -- Mantener el orden de bloqueo del carrito.
        SET @Recurso = CONCAT(N'Carrito:Usuario:', @IDUsuario);
        
        EXECUTE @Resultado = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @Resultado < 0
            THROW 51732, N'No se pudo bloquear el carrito.', 1;
        
        -- Revalidar el checkout con bloqueo exclusivo de actualizacion.
        SELECT @Estado = Estado,
               @FechaExpiracion = FechaExpiracion
        FROM dbo.Checkout WITH (UPDLOCK, HOLDLOCK)
        WHERE IDCheckout = @IDCheckout
              AND IDUsuario = @IDUsuario
              AND IDCarrito = @IDCarrito;
        
        IF @Estado IS NULL
            THROW 51731, N'Checkout no encontrado.', 1;
        
        -- Reintento idempotente.
        IF @Estado = 'CANCELADO'
            BEGIN
                COMMIT TRANSACTION;
                
                SELECT @IDCheckout AS IDCheckout,
                       CAST ('CANCELADO' AS VARCHAR(20)) AS Estado,
                       CAST (0 AS BIT) AS Cancelado;
                
                RETURN;
            END
        
        IF @Estado <> 'ACTIVO'
            THROW 51733, N'El checkout no puede cancelarse.', 1;
        
        SET @Ahora = SYSUTCDATETIME();
        
        IF @FechaExpiracion <= @Ahora
            THROW 51734, N'El checkout ya vencio.', 1;
        
        -- La cancelacion de pedidos pertenece a RF-07.
        -- No cancelar aqui un checkout que ya tiene pedido.
        IF EXISTS (SELECT 1
                   FROM dbo.Pedido WITH (UPDLOCK, HOLDLOCK)
                   WHERE IDCheckout = @IDCheckout)
            THROW 51735, N'El checkout ya tiene un pedido.', 1;
        
        -- Liberar en orden estable para reducir deadlocks.
        DECLARE Reservas CURSOR LOCAL FAST_FORWARD
            FOR SELECT r.IDReservaInventario,
                       r.IDInventarioPorUbicacion,
                       i.IDVariante,
                       i.IDUbicacion,
                       r.Cantidad
                FROM dbo.ReservaInventario AS r
                     INNER JOIN
                     dbo.InventarioPorUbicacion AS i
                     ON i.IDInventarioPorUbicacion = r.IDInventarioPorUbicacion
                WHERE r.IDCheckout = @IDCheckout
                      AND r.Estado = 'ACTIVA'
                ORDER BY i.IDVariante, i.IDUbicacion;
        
        OPEN Reservas;
        
        FETCH NEXT FROM Reservas INTO @IDReserva, @IDInventario, @IDVariante, @IDUbicacion, @Cantidad;
        
        WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @Recurso = CONCAT(N'Inventario:', @IDVariante, N':', @IDUbicacion);
                
                EXECUTE @Resultado = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
                
                IF @Resultado < 0
                    THROW 51736, N'No se pudo bloquear el inventario.', 1;
                
                UPDATE dbo.InventarioPorUbicacion
                SET CantidadReservada  = CantidadReservada - @Cantidad,
                    FechaActualizacion = @Ahora
                WHERE IDInventarioPorUbicacion = @IDInventario
                      AND CantidadReservada >= @Cantidad;
                
                IF @@ROWCOUNT <> 1
                    THROW 51737, N'Inconsistencia en inventario reservado.', 1;
                
                UPDATE dbo.ReservaInventario
                SET Estado          = 'LIBERADA',
                    FechaResolucion = @Ahora
                WHERE IDReservaInventario = @IDReserva
                      AND Estado = 'ACTIVA';
                
                IF @@ROWCOUNT <> 1
                    THROW 51738, N'La reserva cambio de estado.', 1;
                
                FETCH NEXT FROM Reservas INTO @IDReserva, @IDInventario, @IDVariante, @IDUbicacion, @Cantidad;
            END
        
        CLOSE Reservas;
        
        DEALLOCATE Reservas;
        
        -- Liberar el compromiso de cupon, cuando exista.
        UPDATE dbo.CompromisoCupon
        SET Estado = 'LIBERADO'
        WHERE IDCheckout = @IDCheckout
              AND Estado = 'ACTIVO';
        
        UPDATE dbo.Checkout
        SET Estado          = 'CANCELADO',
            FechaResolucion = @Ahora
        WHERE IDCheckout = @IDCheckout
              AND Estado = 'ACTIVO';
        
        IF @@ROWCOUNT <> 1
            THROW 51739, N'El checkout cambio de estado.', 1;
        
        COMMIT TRANSACTION;
        
        SET @Cancelado = 1;
        
        SELECT @IDCheckout AS IDCheckout,
               CAST ('CANCELADO' AS VARCHAR(20)) AS Estado,
               @Cancelado AS Cancelado;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'Reservas') >= 0
            CLOSE Reservas;
        
        IF CURSOR_STATUS('local', 'Reservas') >= -1
            DEALLOCATE Reservas;
        
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Checkout_ConfirmarPago
    @IDCheckout BIGINT,
    @IDUsuario INT,
    @IDDireccion BIGINT,
    @ClaveIdempotencia UNIQUEIDENTIFIER,
    @HuellaSolicitud VARBINARY(32),
    @ReferenciaProcesador VARCHAR(100),
    @MetodoEnvio NVARCHAR(80),
    @CostoEnvio DECIMAL(18,2)
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
       OR @ReferenciaProcesador IS NULL
       OR LEN(LTRIM(RTRIM(@ReferenciaProcesador))) = 0
       OR @MetodoEnvio IS NULL
       OR LEN(LTRIM(RTRIM(@MetodoEnvio))) = 0
       OR @CostoEnvio IS NULL
       OR @CostoEnvio <> 0
       OR @MetodoEnvio <> N'ESTANDAR'
       OR DATALENGTH(@HuellaSolicitud) <> 32
        THROW 51740, N'Parametros de confirmacion invalidos.', 1;
    
    DECLARE @IDCarrito AS BIGINT;
    
    DECLARE @EstadoCheckout AS VARCHAR(20);
    
    DECLARE @FechaExpiracion AS DATETIME2(3);
    
    DECLARE @IDPedido AS BIGINT;
    
    DECLARE @IDIntento AS BIGINT;
    
    DECLARE @HuellaExistente AS VARBINARY(32);
    
    DECLARE @EstadoIntento AS VARCHAR(20);
    
    DECLARE @IDCheckoutIntento AS BIGINT;
    
    DECLARE @MontoIntento AS DECIMAL(18,2);
    
    DECLARE @Resultado AS INT;
    
    DECLARE @Recurso AS NVARCHAR(255);
    
    DECLARE @Ahora AS DATETIME2(3);
    
    DECLARE @SubtotalAmplio AS DECIMAL(38,2);
    
    DECLARE @Subtotal AS DECIMAL(18,2);
    
    DECLARE @Total AS DECIMAL(18,2);
    
    DECLARE @IDEstadoPagado AS INT;
    
    DECLARE @IDInventario AS INT;
    
    DECLARE @IDReserva AS BIGINT;
    
    DECLARE @IDVariante AS INT;
    
    DECLARE @IDUbicacion AS INT;
    
    DECLARE @Cantidad AS INT;
    
    DECLARE @Precio AS DECIMAL(18,2);
    
    DECLARE @SubtotalLinea AS DECIMAL(18,2);
    
    DECLARE @DescuentoLinea AS DECIMAL(18,2);
    
    DECLARE @TotalLinea AS DECIMAL(18,2);
    
    DECLARE @SKU AS VARCHAR(64);
    
    DECLARE @Nombre AS NVARCHAR(250);
    
    DECLARE @IDDetallePedido AS BIGINT;
    
    DECLARE @IDMovimientoInventario AS BIGINT;
    
    DECLARE @SaldosVenta TABLE (
        ExistenciaAnterior INT NOT NULL,
        ReservadaAnterior  INT NOT NULL,
        ExistenciaNueva    INT NOT NULL,
        ReservadaNueva     INT NOT NULL);
    
    BEGIN TRY
        -- Lectura preliminar: la propiedad se revalida bajo bloqueo.
        SELECT @IDCarrito = IDCarrito
        FROM dbo.Checkout
        WHERE IDCheckout = @IDCheckout
              AND IDUsuario = @IDUsuario;
        
        IF @IDCarrito IS NULL
            THROW 51741, N'Checkout no encontrado.', 1;
        
        BEGIN TRANSACTION;
        
        -- Mismo orden que cancelar y expirar: carrito -> checkout -> inventario.
        SET @Recurso = CONCAT(N'Carrito:Usuario:', @IDUsuario);
        
        EXECUTE @Resultado = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @Resultado < 0
            THROW 51742, N'No se pudo bloquear el carrito.', 1;
        
        -- Serializar la misma clave usada al registrar y resolver el intento.
        SET @Recurso = CONCAT(N'Pago:Clave:', CONVERT (VARCHAR(36), @ClaveIdempotencia));
        
        EXECUTE @Resultado = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @Resultado < 0
            THROW 51758, N'No se pudo bloquear el intento de pago.', 1;
        
        -- El intento ya debe existir. No se inserta uno nuevo al confirmar.
        SELECT @IDIntento = p.IDIntentoPago,
               @IDCheckoutIntento = p.IDCheckout,
               @IDPedido = p.IDPedido,
               @HuellaExistente = p.HuellaSolicitud,
               @EstadoIntento = p.Estado,
               @MontoIntento = p.Monto
        FROM dbo.IntentoPago AS p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.ClaveIdempotencia = @ClaveIdempotencia;
        
        IF @IDIntento IS NULL
            THROW 51759, N'El intento de pago no existe.', 1;
        
        IF @IDCheckoutIntento <> @IDCheckout
           OR @HuellaExistente <> @HuellaSolicitud
            THROW 51743, N'Clave de idempotencia reutilizada.', 1;
        
        -- Un reintento exitoso devuelve el mismo pedido, sin nuevos efectos.
        IF @EstadoIntento = 'EXITOSO'
            BEGIN
                IF @IDPedido IS NULL
                   OR NOT EXISTS (SELECT 1
                                  FROM dbo.Pedido
                                  WHERE IDPedido = @IDPedido
                                        AND IDCheckout = @IDCheckout
                                        AND IDUsuario = @IDUsuario
                                        AND Total = @MontoIntento)
                    THROW 51760, N'El pago confirmado no tiene un pedido valido.', 1;
                
                COMMIT TRANSACTION;
                
                SELECT @IDPedido AS IDPedido,
                       @IDIntento AS IDIntentoPago,
                       CAST ('PAGADO' AS VARCHAR(25)) AS Estado,
                       CAST (1 AS BIT) AS Reutilizado;
                
                RETURN;
            END
        
        IF @EstadoIntento <> 'PENDIENTE'
            THROW 51744, N'El intento de pago no esta pendiente.', 1;
        
        IF @IDPedido IS NOT NULL
            THROW 51760, N'El intento pendiente ya tiene un pedido.', 1;
        
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
            THROW 51745, N'Checkout no activo o vencido.', 1;
        
        IF EXISTS (SELECT 1
                   FROM dbo.Pedido WITH (UPDLOCK, HOLDLOCK)
                   WHERE IDCheckout = @IDCheckout)
            THROW 51746, N'El checkout ya tiene un pedido.', 1;
        
        IF EXISTS (SELECT 1
                   FROM dbo.CompromisoCupon
                   WHERE IDCheckout = @IDCheckout
                         AND Estado = 'ACTIVO')
            THROW 51747, N'Los cupones requieren confirmacion comercial.', 1;
        
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Direccion
                       WHERE IDDireccion = @IDDireccion
                             AND IDUsuario = @IDUsuario
                             AND Activa = 1)
            THROW 51748, N'Direccion de entrega no disponible.', 1;
        
        IF NOT EXISTS (SELECT 1
                       FROM dbo.DetalleCarrito
                       WHERE IDCarrito = @IDCarrito)
            THROW 51749, N'Carrito vacio.', 1;
        
        -- Utilizar exclusivamente los importes congelados
        -- al iniciar el checkout.
        SELECT @SubtotalAmplio = SUM(CONVERT (DECIMAL(38,2), d.Subtotal))
        FROM dbo.DetalleCheckout AS d
        WHERE d.IDCheckout = @IDCheckout;
        
        IF @SubtotalAmplio IS NULL
           OR @SubtotalAmplio > 9999999999999999.99
           OR @SubtotalAmplio + @CostoEnvio > 9999999999999999.99
           OR EXISTS (SELECT 1
                      FROM dbo.DetalleCheckout
                      WHERE IDCheckout = @IDCheckout
                            AND Descuento <> 0)
            THROW 51750, N'Importes congelados no validos.', 1;
        
        -- Descuentos y cupones pendientes de RF-05.
        SET @Subtotal = CONVERT (DECIMAL(18,2), @SubtotalAmplio);
        
        SET @Total = CONVERT (DECIMAL(18,2), @SubtotalAmplio + @CostoEnvio);
        
        IF @MontoIntento <> @Total
            THROW 51761, N'El monto del intento no coincide con el pedido.', 1;
        
        INSERT INTO dbo.Pedido (
            IDCheckout,
            IDUsuario,
            IDDireccionEntrega,
            Estado,
            Subtotal,
            DescuentoTotal,
            CostoEnvio,
            Total,
            Destinatario,
            TelefonoEntrega,
            DepartamentoEntrega,
            MunicipioEntrega,
            DireccionEntregaTexto,
            ReferenciaEntrega,
            MetodoEnvio,
            FechaCreacion,
            FechaPago
        )
        SELECT @IDCheckout,
               @IDUsuario,
               IDDireccion,
               'PAGADO',
               @Subtotal,
               0,
               @CostoEnvio,
               @Total,
               NombreDestinatario,
               Telefono,
               Departamento,
               Municipio,
               DireccionTexto,
               Referencia,
               @MetodoEnvio,
               @Ahora,
               @Ahora
        FROM dbo.Direccion
        WHERE IDDireccion = @IDDireccion
              AND IDUsuario = @IDUsuario
              AND Activa = 1;
        
        IF @@ROWCOUNT <> 1
            THROW 51748, N'Direccion de entrega no disponible.', 1;
        
        SET @IDPedido = CONVERT (BIGINT, SCOPE_IDENTITY());
        
        -- Procesar las reservas con sus datos comerciales congelados.
        DECLARE Lineas CURSOR LOCAL FAST_FORWARD
            FOR SELECT r.IDReservaInventario,
                       r.IDInventarioPorUbicacion,
                       i.IDVariante,
                       i.IDUbicacion,
                       r.Cantidad,
                       d.PrecioUnitario,
                       d.SKUHistorico,
                       d.NombreHistorico,
                       d.Subtotal,
                       d.Descuento,
                       d.Total
                FROM dbo.ReservaInventario AS r
                     INNER JOIN
                     dbo.InventarioPorUbicacion AS i
                     ON i.IDInventarioPorUbicacion = r.IDInventarioPorUbicacion
                     INNER JOIN
                     dbo.DetalleCheckout AS d
                     ON d.IDCheckout = r.IDCheckout
                        AND d.IDVariante = i.IDVariante
                        AND d.Cantidad = r.Cantidad
                WHERE r.IDCheckout = @IDCheckout
                      AND r.Estado = 'ACTIVA'
                ORDER BY i.IDVariante, i.IDUbicacion;
        
        -- Cada línea del carrito debe coincidir con
        -- su cotización congelada y reserva vigente.
        IF EXISTS (SELECT 1
                   FROM dbo.DetalleCarrito AS c
                   WHERE c.IDCarrito = @IDCarrito
                         AND NOT EXISTS (SELECT 1
                                         FROM dbo.DetalleCheckout AS d
                                              INNER JOIN
                                              dbo.ReservaInventario AS r
                                              ON r.IDCheckout = d.IDCheckout
                                              INNER JOIN
                                              dbo.InventarioPorUbicacion AS i
                                              ON i.IDInventarioPorUbicacion = r.IDInventarioPorUbicacion
                                         WHERE d.IDCheckout = @IDCheckout
                                               AND d.IDVariante = c.IDVariante
                                               AND d.Cantidad = c.Cantidad
                                               AND i.IDVariante = d.IDVariante
                                               AND r.Cantidad = d.Cantidad
                                               AND r.Estado = 'ACTIVA'
                                               AND r.FechaExpiracion > @Ahora))
           OR (SELECT COUNT_BIG(*)
               FROM dbo.DetalleCheckout
               WHERE IDCheckout = @IDCheckout) <> (SELECT COUNT_BIG(*)
                                                   FROM dbo.DetalleCarrito
                                                   WHERE IDCarrito = @IDCarrito)
           OR (SELECT COUNT_BIG(*)
               FROM dbo.ReservaInventario
               WHERE IDCheckout = @IDCheckout
                     AND Estado = 'ACTIVA') <> (SELECT COUNT_BIG(*)
                                                FROM dbo.DetalleCarrito
                                                WHERE IDCarrito = @IDCarrito)
            THROW 51751, N'La cotizacion y las reservas no coinciden.', 1;
        
        OPEN Lineas;
        
        FETCH NEXT FROM Lineas INTO @IDReserva, @IDInventario, @IDVariante, @IDUbicacion, @Cantidad, @Precio, @SKU, @Nombre, @SubtotalLinea, @DescuentoLinea, @TotalLinea;
        
        WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @Recurso = CONCAT(N'Inventario:', @IDVariante, N':', @IDUbicacion);
                
                EXECUTE @Resultado = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
                
                IF @Resultado < 0
                    THROW 51752, N'No se pudo bloquear el inventario.', 1;
                
                -- Los importes de la linea proceden de la cotizacion persistida.
                IF @DescuentoLinea <> 0
                   OR @TotalLinea <> @SubtotalLinea
                    THROW 51750, N'Importes de cotizacion inconsistentes.', 1;
                
                DELETE @SaldosVenta;
                
                UPDATE dbo.InventarioPorUbicacion
                SET ExistenciaFisica   = ExistenciaFisica - @Cantidad,
                    CantidadReservada  = CantidadReservada - @Cantidad,
                    FechaActualizacion = @Ahora
                OUTPUT deleted.ExistenciaFisica, deleted.CantidadReservada, inserted.ExistenciaFisica, inserted.CantidadReservada INTO @SaldosVenta (ExistenciaAnterior, ReservadaAnterior, ExistenciaNueva, ReservadaNueva)
                WHERE IDInventarioPorUbicacion = @IDInventario
                      AND ExistenciaFisica >= @Cantidad
                      AND CantidadReservada >= @Cantidad;
                
                IF @@ROWCOUNT <> 1
                    THROW 51753, N'Existencias reservadas inconsistentes.', 1;
                
                INSERT INTO dbo.DetallePedido (
                    IDPedido,
                    IDVariante,
                    SKUHistorico,
                    NombreHistorico,
                    Cantidad,
                    CantidadDevuelta,
                    PrecioUnitario,
                    Subtotal,
                    Descuento,
                    Total,
                    MontoDevuelto
                )
                VALUES                        (@IDPedido, @IDVariante, @SKU, @Nombre, @Cantidad, 0, @Precio, @SubtotalLinea, @DescuentoLinea, @TotalLinea, 0);
                
                SET @IDDetallePedido = CONVERT (BIGINT, SCOPE_IDENTITY());
                
                INSERT INTO dbo.MovimientoInventario (
                    IDInventarioPorUbicacion,
                    IDUsuario,
                    IDDetallePedido,
                    TipoMovimiento,
                    CantidadCambio,
                    Motivo
                )
                VALUES                               (@IDInventario, @IDUsuario, @IDDetallePedido, 'SALIDA_VENTA', -@Cantidad, N'Venta confirmada');
                
                SET @IDMovimientoInventario = CONVERT (BIGINT, SCOPE_IDENTITY());
                
                INSERT INTO dbo.Bitacora (
                    IDUsuario,
                    Modulo,
                    Entidad,
                    IDEntidad,
                    Accion,
                    ValorAnterior,
                    ValorNuevo
                )
                SELECT @IDUsuario,
                       'INVENTARIO',
                       'InventarioPorUbicacion',
                       @IDInventario,
                       'SALIDA_VENTA',
                       (SELECT s.ExistenciaAnterior AS ExistenciaFisica,
                               s.ReservadaAnterior AS CantidadReservada
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                       (SELECT s.ExistenciaNueva AS ExistenciaFisica,
                               s.ReservadaNueva AS CantidadReservada,
                               @IDPedido AS IDPedido,
                               @IDVariante AS IDVariante,
                               @Cantidad AS Cantidad,
                               @IDMovimientoInventario AS IDMovimientoInventario
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
                FROM @SaldosVenta AS s;
                
                UPDATE dbo.ReservaInventario
                SET Estado          = 'CONSUMIDA',
                    FechaResolucion = @Ahora
                WHERE IDReservaInventario = @IDReserva
                      AND Estado = 'ACTIVA';
                
                IF @@ROWCOUNT <> 1
                    THROW 51754, N'La reserva cambio de estado.', 1;
                
                FETCH NEXT FROM Lineas INTO @IDReserva, @IDInventario, @IDVariante, @IDUbicacion, @Cantidad, @Precio, @SKU, @Nombre, @SubtotalLinea, @DescuentoLinea, @TotalLinea;
            END
        
        CLOSE Lineas;
        
        DEALLOCATE Lineas;
        
        -- Confirmar el mismo intento PENDIENTE, dentro de la transaccion.
        UPDATE dbo.IntentoPago
        SET IDPedido             = @IDPedido,
            Estado               = 'EXITOSO',
            ReferenciaProcesador = @ReferenciaProcesador,
            FechaResolucion      = @Ahora
        WHERE IDIntentoPago = @IDIntento
              AND IDCheckout = @IDCheckout
              AND ClaveIdempotencia = @ClaveIdempotencia
              AND HuellaSolicitud = @HuellaSolicitud
              AND Estado = 'PENDIENTE'
              AND IDPedido IS NULL
              AND Monto = @Total;
        
        IF @@ROWCOUNT <> 1
            THROW 51762, N'No se pudo confirmar el intento de pago.', 1;
        
        SELECT @IDEstadoPagado = IDEstadoPedido
        FROM dbo.EstadoPedido
        WHERE Codigo = 'PAGADO';
        
        IF @IDEstadoPagado IS NULL
            THROW 51755, N'Falta el estado PAGADO en datos base.', 1;
        
        INSERT INTO dbo.HistorialEstadoPedido (
            IDPedido,
            IDEstadoAnterior,
            IDEstadoNuevo,
            IDUsuario,
            Motivo
        )
        VALUES                                (@IDPedido, NULL, @IDEstadoPagado, @IDUsuario, N'Pedido creado con pago confirmado');
        
        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Entidad,
            IDEntidad,
            Accion,
            ValorAnterior,
            ValorNuevo
        )
        VALUES                   (@IDUsuario, 'PEDIDOS', 'Pedido', @IDPedido, 'CREAR', NULL, (SELECT @IDPedido AS IDPedido,
                                                                                                     @IDCheckout AS IDCheckout,
                                                                                                     'PAGADO' AS Estado,
                                                                                                     @Total AS Total
                                                                                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
        
        UPDATE dbo.Checkout
        SET Estado          = 'CONFIRMADO',
            FechaResolucion = @Ahora
        WHERE IDCheckout = @IDCheckout
              AND Estado = 'ACTIVO';
        
        IF @@ROWCOUNT <> 1
            THROW 51756, N'Checkout modificado concurrentemente.', 1;
        
        UPDATE dbo.Carrito
        SET Estado               = 'CONVERTIDO',
            FechaUltimaActividad = @Ahora
        WHERE IDCarrito = @IDCarrito
              AND Estado = 'ACTIVO';
        
        IF @@ROWCOUNT <> 1
            THROW 51757, N'Carrito modificado concurrentemente.', 1;
        
        COMMIT TRANSACTION;
        
        SELECT @IDPedido AS IDPedido,
               @IDIntento AS IDIntentoPago,
               CAST ('PAGADO' AS VARCHAR(25)) AS Estado,
               CAST (0 AS BIT) AS Reutilizado;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'Lineas') >= 0
            CLOSE Lineas;
        
        IF CURSOR_STATUS('local', 'Lineas') >= -1
            DEALLOCATE Lineas;
        
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        THROW;
    END CATCH
END