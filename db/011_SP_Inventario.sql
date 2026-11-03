/* ShopCart | 011_SP_Inventario.sql
   Crea:
   - SP_Inventario_RegistrarEntrada
   - SP_Inventario_RegistrarAjuste
   - SP_Inventario_ConsultarExistencias
   - SP_Inventario_ConsultarKardex
*/
USE ShopCartDB;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Inventario_RegistrarEntrada
    @IDVariante INT,
    @IDUbicacion INT,
    @Cantidad INT,
    @Motivo NVARCHAR(300),
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @Motivo = NULLIF (LTRIM(RTRIM(@Motivo)), N'');
    
    IF @Cantidad IS NULL
       OR @Cantidad <= 0
        THROW 51500, N'La cantidad debe ser positiva.', 1;
    
    IF @Motivo IS NULL
        THROW 51501, N'El motivo es obligatorio.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validar variante existente.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Variante
                       WHERE IDVariante = @IDVariante)
            THROW 51502, N'La variante no existe.', 1;
        
        -- Validar ubicación activa.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Ubicacion
                       WHERE IDUbicacion = @IDUbicacion
                             AND Activa = 1)
            THROW 51503, N'La ubicación no existe o está inactiva.', 1;
        
        -- Serializar las escrituras de esta variante y ubicación.
        DECLARE @ResultadoBloqueo AS INT;
        
        DECLARE @Recurso AS NVARCHAR(255) = CONCAT(N'Inventario:', @IDVariante, N':', @IDUbicacion);
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51504, N'No fue posible bloquear el inventario.', 1;
        
        DECLARE @IDInventario AS INT;
        
        DECLARE @ExistenciaAnterior AS INT = 0;
        
        DECLARE @ExistenciaNueva AS INT;
        
        DECLARE @Reservada AS INT = 0;
        
        DECLARE @TipoMovimiento AS VARCHAR(25);
        
        DECLARE @IDMovimiento AS BIGINT;
        
        SELECT @IDInventario = IDInventarioPorUbicacion,
               @ExistenciaAnterior = ExistenciaFisica,
               @Reservada = CantidadReservada
        FROM dbo.InventarioPorUbicacion WITH (UPDLOCK, HOLDLOCK)
        WHERE IDVariante = @IDVariante
              AND IDUbicacion = @IDUbicacion;
        
        -- Evitar desbordamiento de INT.
        IF CONVERT (BIGINT, @ExistenciaAnterior) + @Cantidad > 2147483647
            THROW 51505, N'La existencia supera el límite permitido.', 1;
        
        SET @ExistenciaNueva = @ExistenciaAnterior + @Cantidad;
        
        IF @IDInventario IS NULL
            BEGIN
                SET @TipoMovimiento = 'ENTRADA_INICIAL';
                
                INSERT INTO dbo.InventarioPorUbicacion (
                    IDVariante,
                    IDUbicacion,
                    ExistenciaFisica,
                    CantidadReservada
                )
                VALUES                                 (@IDVariante, @IDUbicacion, @ExistenciaNueva, 0);
                
                SET @IDInventario = CONVERT (INT, SCOPE_IDENTITY());
            END
        ELSE
            BEGIN
                SET @TipoMovimiento = 'ENTRADA_MANUAL';
                
                UPDATE dbo.InventarioPorUbicacion
                SET ExistenciaFisica   = @ExistenciaNueva,
                    FechaActualizacion = SYSUTCDATETIME()
                WHERE IDInventarioPorUbicacion = @IDInventario;
            END
        
        -- Registrar el incremento físico en kardex.
        INSERT INTO dbo.MovimientoInventario (
            IDInventarioPorUbicacion,
            IDUsuario,
            TipoMovimiento,
            CantidadCambio,
            Motivo
        )
        VALUES                               (@IDInventario, @IDUsuario, @TipoMovimiento, @Cantidad, @Motivo);
        
        SET @IDMovimiento = CONVERT (BIGINT, SCOPE_IDENTITY());
        
        -- Auditar el cambio de existencias.
        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Entidad,
            IDEntidad,
            Accion,
            ValorAnterior,
            ValorNuevo
        )
        VALUES                   (@IDUsuario, 'INVENTARIO', 'InventarioPorUbicacion', @IDInventario, @TipoMovimiento, (SELECT @ExistenciaAnterior AS ExistenciaFisica,
                                                                                                                              @Reservada AS CantidadReservada
                                                                                                                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), (SELECT @ExistenciaNueva AS ExistenciaFisica,
                                                                                                                                                                      @Reservada AS CantidadReservada,
                                                                                                                                                                      @IDMovimiento AS IDMovimientoInventario
                                                                                                                                                               FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
        
        COMMIT TRANSACTION;
        
        SELECT @IDInventario AS IDInventarioPorUbicacion,
               @IDMovimiento AS IDMovimientoInventario,
               @IDVariante AS IDVariante,
               @IDUbicacion AS IDUbicacion,
               @TipoMovimiento AS TipoMovimiento,
               @Cantidad AS CantidadCambio,
               @ExistenciaAnterior AS ExistenciaAnterior,
               @ExistenciaNueva AS ExistenciaFisica,
               @Reservada AS CantidadReservada,
               @ExistenciaNueva - @Reservada AS Disponible;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Inventario_RegistrarAjuste
    @IDVariante INT,
    @IDUbicacion INT,
    @CantidadCambio INT,
    @Motivo NVARCHAR(300),
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @Motivo = NULLIF (LTRIM(RTRIM(@Motivo)), N'');
    
    IF @CantidadCambio IS NULL
       OR @CantidadCambio = 0
        THROW 51506, N'El ajuste debe ser distinto de cero.', 1;
    
    IF @Motivo IS NULL
        THROW 51501, N'El motivo es obligatorio.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @ResultadoBloqueo AS INT;
        
        DECLARE @Recurso AS NVARCHAR(255) = CONCAT(N'Inventario:', @IDVariante, N':', @IDUbicacion);
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51504, N'No fue posible bloquear el inventario.', 1;
        
        DECLARE @IDInventario AS INT;
        
        DECLARE @ExistenciaAnterior AS INT;
        
        DECLARE @Reservada AS INT;
        
        DECLARE @ExistenciaNueva AS BIGINT;
        
        DECLARE @IDMovimiento AS BIGINT;
        
        SELECT @IDInventario = I.IDInventarioPorUbicacion,
               @ExistenciaAnterior = I.ExistenciaFisica,
               @Reservada = I.CantidadReservada
        FROM dbo.InventarioPorUbicacion AS I WITH (UPDLOCK, HOLDLOCK)
             INNER JOIN
             dbo.Ubicacion AS U
             ON U.IDUbicacion = I.IDUbicacion
        WHERE I.IDVariante = @IDVariante
              AND I.IDUbicacion = @IDUbicacion
              AND U.Activa = 1;
        
        IF @IDInventario IS NULL
            THROW 51507, N'No existe inventario para esa variante y ubicación.', 1;
        
        SET @ExistenciaNueva = CONVERT (BIGINT, @ExistenciaAnterior) + @CantidadCambio;
        
        IF @ExistenciaNueva < @Reservada
            THROW 51508, N'El ajuste dejaría existencias inferiores a las reservadas.', 1;
        
        IF @ExistenciaNueva > 2147483647
            THROW 51505, N'La existencia supera el límite permitido.', 1;
        
        UPDATE dbo.InventarioPorUbicacion
        SET ExistenciaFisica   = CONVERT (INT, @ExistenciaNueva),
            FechaActualizacion = SYSUTCDATETIME()
        WHERE IDInventarioPorUbicacion = @IDInventario;
        
        INSERT INTO dbo.MovimientoInventario (
            IDInventarioPorUbicacion,
            IDUsuario,
            TipoMovimiento,
            CantidadCambio,
            Motivo
        )
        VALUES                               (@IDInventario, @IDUsuario, 'AJUSTE', @CantidadCambio, @Motivo);
        
        SET @IDMovimiento = CONVERT (BIGINT, SCOPE_IDENTITY());
        
        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Entidad,
            IDEntidad,
            Accion,
            ValorAnterior,
            ValorNuevo
        )
        VALUES                   (@IDUsuario, 'INVENTARIO', 'InventarioPorUbicacion', @IDInventario, 'AJUSTE', (SELECT @ExistenciaAnterior AS ExistenciaFisica,
                                                                                                                       @Reservada AS CantidadReservada
                                                                                                                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), (SELECT @ExistenciaNueva AS ExistenciaFisica,
                                                                                                                                                               @Reservada AS CantidadReservada,
                                                                                                                                                               @IDMovimiento AS IDMovimientoInventario
                                                                                                                                                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
        
        COMMIT TRANSACTION;
        
        SELECT @IDInventario AS IDInventarioPorUbicacion,
               @IDMovimiento AS IDMovimientoInventario,
               @CantidadCambio AS CantidadCambio,
               CONVERT (INT, @ExistenciaNueva) AS ExistenciaFisica,
               @Reservada AS CantidadReservada,
               CONVERT (INT, @ExistenciaNueva - @Reservada) AS Disponible;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ConsultarExistencias
    @IDVariante INT=NULL,
    @IDUbicacion INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @IDVariante IS NOT NULL
       AND @IDVariante <= 0
        THROW 51509, N'La variante no es válida.', 1;
    
    IF @IDUbicacion IS NOT NULL
       AND @IDUbicacion <= 0
        THROW 51510, N'La ubicación no es válida.', 1;
    
    SELECT I.IDInventarioPorUbicacion,
           I.IDVariante,
           V.SKU,
           P.Nombre AS Producto,
           I.IDUbicacion,
           U.Codigo AS CodigoUbicacion,
           U.Nombre AS Ubicacion,
           I.ExistenciaFisica,
           I.CantidadReservada,
           I.ExistenciaFisica - I.CantidadReservada AS Disponible,
           I.FechaActualizacion
    FROM dbo.InventarioPorUbicacion AS I
         INNER JOIN
         dbo.Variante AS V
         ON V.IDVariante = I.IDVariante
         INNER JOIN
         dbo.Producto AS P
         ON P.IDProducto = V.IDProducto
         INNER JOIN
         dbo.Ubicacion AS U
         ON U.IDUbicacion = I.IDUbicacion
    WHERE (@IDVariante IS NULL
           OR I.IDVariante = @IDVariante)
          AND (@IDUbicacion IS NULL
               OR I.IDUbicacion = @IDUbicacion)
    ORDER BY P.Nombre, V.SKU, U.Codigo;
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ConsultarKardex
    @IDVariante INT,
    @IDUbicacion INT=NULL,
    @FechaDesde DATETIME2(3)=NULL,
    @FechaHasta DATETIME2(3)=NULL,
    @Pagina INT=1,
    @TamanoPagina INT=20,
    @TotalRegistros BIGINT=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @IDVariante IS NULL
       OR @IDVariante <= 0
        THROW 51509, N'La variante no es válida.', 1;
    
    IF @IDUbicacion IS NOT NULL
       AND @IDUbicacion <= 0
        THROW 51510, N'La ubicación no es válida.', 1;
    
    IF @Pagina IS NULL
       OR @Pagina < 1
       OR @TamanoPagina IS NULL
       OR @TamanoPagina NOT BETWEEN 1 AND 100
        THROW 51511, N'La paginación no es válida.', 1;
    
    IF @FechaDesde IS NOT NULL
       AND @FechaHasta IS NOT NULL
       AND @FechaDesde > @FechaHasta
        THROW 51512, N'El rango de fechas no es válido.', 1;
    
    DECLARE @Offset AS BIGINT = (CONVERT (BIGINT, @Pagina) - 1) * @TamanoPagina;
    
    -- Obtener el total independientemente de la página.
    SELECT @TotalRegistros = COUNT_BIG(*)
    FROM dbo.MovimientoInventario AS M
         INNER JOIN
         dbo.InventarioPorUbicacion AS I
         ON I.IDInventarioPorUbicacion = M.IDInventarioPorUbicacion
    WHERE I.IDVariante = @IDVariante
          AND (@IDUbicacion IS NULL
               OR I.IDUbicacion = @IDUbicacion)
          AND (@FechaDesde IS NULL
               OR M.FechaMovimiento >= @FechaDesde)
          AND (@FechaHasta IS NULL
               OR M.FechaMovimiento <= @FechaHasta);
    
    SELECT M.IDMovimientoInventario,
           I.IDVariante,
           I.IDUbicacion,
           U.Codigo AS CodigoUbicacion,
           M.TipoMovimiento,
           M.CantidadCambio,
           M.Motivo,
           M.IDUsuario,
           M.IDDetallePedido,
           M.IDDetalleDevolucion,
           M.FechaMovimiento
    FROM dbo.MovimientoInventario AS M
         INNER JOIN
         dbo.InventarioPorUbicacion AS I
         ON I.IDInventarioPorUbicacion = M.IDInventarioPorUbicacion
         INNER JOIN
         dbo.Ubicacion AS U
         ON U.IDUbicacion = I.IDUbicacion
    WHERE I.IDVariante = @IDVariante
          AND (@IDUbicacion IS NULL
               OR I.IDUbicacion = @IDUbicacion)
          AND (@FechaDesde IS NULL
               OR M.FechaMovimiento >= @FechaDesde)
          AND (@FechaHasta IS NULL
               OR M.FechaMovimiento <= @FechaHasta)
    ORDER BY M.FechaMovimiento DESC, M.IDMovimientoInventario DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END