/* ShopCart | 012_SP_Carrito.sql
   Crea:
   - SP_Carrito_AgregarProducto
   - SP_Carrito_Consultar
   - SP_Carrito_ActualizarCantidad
   - SP_Carrito_EliminarProducto
*/
USE ShopCartDB;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Carrito_AgregarProducto
    @IDVariante INT,
    @Cantidad INT,
    @IDUsuario INT=NULL,
    @TokenInvitadoHash VARBINARY(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @Cantidad IS NULL
       OR @Cantidad <= 0
        THROW 51600, N'La cantidad debe ser positiva.', 1;
    
    IF (@IDUsuario IS NULL
        AND @TokenInvitadoHash IS NULL)
       OR (@IDUsuario IS NOT NULL
           AND @TokenInvitadoHash IS NOT NULL)
       OR (@TokenInvitadoHash IS NOT NULL
           AND DATALENGTH(@TokenInvitadoHash) <> 32)
        THROW 51601, N'Propietario del carrito inválido.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @IDCarrito AS BIGINT;
        
        DECLARE @IDDetalleCarrito AS BIGINT;
        
        DECLARE @CantidadActual AS INT = 0;
        
        DECLARE @CantidadNueva AS BIGINT;
        
        DECLARE @Disponible AS BIGINT;
        
        DECLARE @ResultadoBloqueo AS INT;
        
        DECLARE @Recurso AS NVARCHAR(255);
        
        DECLARE @IDUbicacion AS INT;
        
        -- Serializar operaciones del mismo propietario.
        SET @Recurso = CASE WHEN @IDUsuario IS NOT NULL THEN CONCAT(N'Carrito:Usuario:', @IDUsuario) ELSE CONCAT(N'Carrito:Invitado:', CONVERT (VARCHAR(64), @TokenInvitadoHash, 2)) END;
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51602, N'No fue posible bloquear el carrito.', 1;
        
        -- Buscar un carrito activo del propietario.
        SELECT TOP (1) @IDCarrito = IDCarrito
        FROM dbo.Carrito WITH (UPDLOCK, HOLDLOCK)
        WHERE Estado = 'ACTIVO'
              AND ((@IDUsuario IS NOT NULL
                    AND IDUsuario = @IDUsuario)
                   OR (@TokenInvitadoHash IS NOT NULL
                       AND TokenInvitadoHash = @TokenInvitadoHash))
        ORDER BY IDCarrito DESC;
        
        IF @IDCarrito IS NULL
            BEGIN
                INSERT INTO dbo.Carrito (
                    IDUsuario,
                    TokenInvitadoHash,
                    Estado
                )
                VALUES                  (@IDUsuario, @TokenInvitadoHash, 'ACTIVO');
                
                SET @IDCarrito = CONVERT (BIGINT, SCOPE_IDENTITY());
            END
        
        -- Solo permitir variantes comercializables.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Variante AS v
                            INNER JOIN
                            dbo.Producto AS p
                            ON p.IDProducto = v.IDProducto
                            INNER JOIN
                            dbo.Categoria AS c
                            ON c.IDCategoria = p.IDCategoria
                       WHERE v.IDVariante = @IDVariante
                             AND v.Activa = 1
                             AND p.Activo = 1
                             AND c.Activa = 1)
            THROW 51603, N'La variante no está disponible.', 1;
        
        -- F2: validar la bodega antes de construir el recurso.
        SELECT @IDUbicacion = IDUbicacion
        FROM dbo.Ubicacion
        WHERE Codigo = 'BOD-CENTRAL'
              AND Activa = 1;
        
        IF @IDUbicacion IS NULL
            THROW 51604, N'La bodega central no está disponible.', 1;
        
        -- Sincronizar con las operaciones de inventario de RF-03.
        SET @Recurso = CONCAT(N'Inventario:', @IDVariante, N':', @IDUbicacion);
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51605, N'No fue posible consultar el inventario.', 1;
        
        -- Consultar disponibilidad en la ubicación validada.
        SELECT @Disponible = CONVERT (BIGINT, i.ExistenciaFisica) - i.CantidadReservada
        FROM dbo.InventarioPorUbicacion AS i
        WHERE i.IDVariante = @IDVariante
              AND i.IDUbicacion = @IDUbicacion;
        
        SET @Disponible = ISNULL(@Disponible, 0);
        
        -- Buscar la cantidad acumulada en el carrito.
        SELECT @IDDetalleCarrito = IDDetalleCarrito,
               @CantidadActual = Cantidad
        FROM dbo.DetalleCarrito WITH (UPDLOCK, HOLDLOCK)
        WHERE IDCarrito = @IDCarrito
              AND IDVariante = @IDVariante;
        
        SET @CantidadNueva = CONVERT (BIGINT, @CantidadActual) + @Cantidad;
        
        IF @CantidadNueva > @Disponible
            THROW 51606, N'Existencia disponible insuficiente.', 1;
        
        IF @CantidadNueva > 2147483647
            THROW 51607, N'La cantidad supera el límite permitido.', 1;
        
        IF @IDDetalleCarrito IS NULL
            BEGIN
                INSERT INTO dbo.DetalleCarrito (
                    IDCarrito,
                    IDVariante,
                    Cantidad
                )
                VALUES                         (@IDCarrito, @IDVariante, CONVERT (INT, @CantidadNueva));
                
                SET @IDDetalleCarrito = CONVERT (BIGINT, SCOPE_IDENTITY());
            END
        ELSE
            BEGIN
                UPDATE dbo.DetalleCarrito
                SET Cantidad           = CONVERT (INT, @CantidadNueva),
                    FechaActualizacion = SYSUTCDATETIME()
                WHERE IDDetalleCarrito = @IDDetalleCarrito;
            END
        
        UPDATE dbo.Carrito
        SET FechaUltimaActividad = SYSUTCDATETIME()
        WHERE IDCarrito = @IDCarrito;
        
        COMMIT TRANSACTION;
        
        SELECT @IDCarrito AS IDCarrito,
               @IDDetalleCarrito AS IDDetalleCarrito,
               @IDVariante AS IDVariante,
               CONVERT (INT, @CantidadNueva) AS Cantidad;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Carrito_Consultar
    @IDUsuario INT=NULL,
    @TokenInvitadoHash VARBINARY(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF (@IDUsuario IS NULL
        AND @TokenInvitadoHash IS NULL)
       OR (@IDUsuario IS NOT NULL
           AND @TokenInvitadoHash IS NOT NULL)
       OR (@TokenInvitadoHash IS NOT NULL
           AND DATALENGTH(@TokenInvitadoHash) <> 32)
        THROW 51601, N'Propietario del carrito inválido.', 1;
    
    DECLARE @IDCarrito AS BIGINT;
    
    SELECT TOP (1) @IDCarrito = IDCarrito
    FROM dbo.Carrito
    WHERE Estado = 'ACTIVO'
          AND ((@IDUsuario IS NOT NULL
                AND IDUsuario = @IDUsuario)
               OR (@TokenInvitadoHash IS NOT NULL
                   AND TokenInvitadoHash = @TokenInvitadoHash))
    ORDER BY IDCarrito DESC;
    
    -- Materializar las líneas para mantener coherencia
    -- entre el detalle y el resumen del carrito.
    SELECT d.IDDetalleCarrito,
           d.IDVariante,
           v.SKU,
           p.Nombre AS Producto,
           d.Cantidad,
           v.PrecioActual AS PrecioUnitario,
           CONVERT (DECIMAL(38,2), d.Cantidad * v.PrecioActual) AS Subtotal
    INTO #LineasCarrito
    FROM dbo.DetalleCarrito AS d
         INNER JOIN
         dbo.Variante AS v
         ON v.IDVariante = d.IDVariante
         INNER JOIN
         dbo.Producto AS p
         ON p.IDProducto = v.IDProducto
    WHERE d.IDCarrito = @IDCarrito;
    
    -- Resultado 1: líneas del carrito.
    SELECT IDDetalleCarrito,
           IDVariante,
           SKU,
           Producto,
           Cantidad,
           CONVERT (VARCHAR(40), PrecioUnitario) AS PrecioUnitario,
           CONVERT (VARCHAR(50), Subtotal) AS Subtotal
    FROM #LineasCarrito
    ORDER BY IDDetalleCarrito;
    
    -- Resultado 2: resumen del mismo conjunto de líneas.
    SELECT @IDCarrito AS IDCarrito,
           ISNULL(SUM(CONVERT (BIGINT, Cantidad)), 0) AS CantidadArticulos,
           CONVERT (VARCHAR(50), ISNULL(SUM(Subtotal), 0)) AS Subtotal,
           CAST ('0.00' AS VARCHAR(40)) AS Descuento,
           CONVERT (VARCHAR(50), ISNULL(SUM(Subtotal), 0)) AS Total
    FROM #LineasCarrito;
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Carrito_ActualizarCantidad
    @IDVariante INT,
    @Cantidad INT,
    @IDUsuario INT=NULL,
    @TokenInvitadoHash VARBINARY(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @Cantidad IS NULL
       OR @Cantidad <= 0
        THROW 51600, N'La cantidad debe ser positiva.', 1;
    
    IF (@IDUsuario IS NULL
        AND @TokenInvitadoHash IS NULL)
       OR (@IDUsuario IS NOT NULL
           AND @TokenInvitadoHash IS NOT NULL)
       OR (@TokenInvitadoHash IS NOT NULL
           AND DATALENGTH(@TokenInvitadoHash) <> 32)
        THROW 51601, N'Propietario del carrito inválido.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @IDCarrito AS BIGINT;
        
        DECLARE @IDDetalleCarrito AS BIGINT;
        
        DECLARE @IDUbicacion AS INT;
        
        DECLARE @Disponible AS BIGINT;
        
        DECLARE @ResultadoBloqueo AS INT;
        
        DECLARE @Recurso AS NVARCHAR(255);
        
        -- Serializar las operaciones del mismo carrito.
        SET @Recurso = CASE WHEN @IDUsuario IS NOT NULL THEN CONCAT(N'Carrito:Usuario:', @IDUsuario) ELSE CONCAT(N'Carrito:Invitado:', CONVERT (VARCHAR(64), @TokenInvitadoHash, 2)) END;
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51602, N'No fue posible bloquear el carrito.', 1;
        
        -- Verificar carrito activo del propietario.
        SELECT TOP (1) @IDCarrito = IDCarrito
        FROM dbo.Carrito WITH (UPDLOCK, HOLDLOCK)
        WHERE Estado = 'ACTIVO'
              AND ((@IDUsuario IS NOT NULL
                    AND IDUsuario = @IDUsuario)
                   OR (@TokenInvitadoHash IS NOT NULL
                       AND TokenInvitadoHash = @TokenInvitadoHash))
        ORDER BY IDCarrito DESC;
        
        IF @IDCarrito IS NULL
            THROW 51608, N'No existe un carrito activo.', 1;
        
        -- Verificar que la variante esté en el carrito.
        SELECT @IDDetalleCarrito = IDDetalleCarrito
        FROM dbo.DetalleCarrito WITH (UPDLOCK, HOLDLOCK)
        WHERE IDCarrito = @IDCarrito
              AND IDVariante = @IDVariante;
        
        IF @IDDetalleCarrito IS NULL
            THROW 51609, N'La variante no existe en el carrito.', 1;
        
        -- Verificar que la variante siga comercializable.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Variante AS v
                            INNER JOIN
                            dbo.Producto AS p
                            ON p.IDProducto = v.IDProducto
                            INNER JOIN
                            dbo.Categoria AS c
                            ON c.IDCategoria = p.IDCategoria
                       WHERE v.IDVariante = @IDVariante
                             AND v.Activa = 1
                             AND p.Activo = 1
                             AND c.Activa = 1)
            THROW 51603, N'La variante no está disponible.', 1;
        
        -- Obtener y validar la bodega central.
        SELECT @IDUbicacion = IDUbicacion
        FROM dbo.Ubicacion
        WHERE Codigo = 'BOD-CENTRAL'
              AND Activa = 1;
        
        IF @IDUbicacion IS NULL
            THROW 51604, N'La bodega central no está disponible.', 1;
        
        -- Sincronizar con las operaciones de inventario.
        SET @Recurso = CONCAT(N'Inventario:', @IDVariante, N':', @IDUbicacion);
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51605, N'No fue posible consultar el inventario.', 1;
        
        SELECT @Disponible = CONVERT (BIGINT, ExistenciaFisica) - CantidadReservada
        FROM dbo.InventarioPorUbicacion
        WHERE IDVariante = @IDVariante
              AND IDUbicacion = @IDUbicacion;
        
        SET @Disponible = ISNULL(@Disponible, 0);
        
        IF @Cantidad > @Disponible
            THROW 51606, N'Existencia disponible insuficiente.', 1;
        
        -- Establecer la cantidad solicitada.
        UPDATE dbo.DetalleCarrito
        SET Cantidad           = @Cantidad,
            FechaActualizacion = SYSUTCDATETIME()
        WHERE IDDetalleCarrito = @IDDetalleCarrito;
        
        UPDATE dbo.Carrito
        SET FechaUltimaActividad = SYSUTCDATETIME()
        WHERE IDCarrito = @IDCarrito;
        
        COMMIT TRANSACTION;
        
        SELECT @IDCarrito AS IDCarrito,
               @IDDetalleCarrito AS IDDetalleCarrito,
               @IDVariante AS IDVariante,
               @Cantidad AS Cantidad;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Carrito_EliminarProducto
    @IDVariante INT,
    @IDUsuario INT=NULL,
    @TokenInvitadoHash VARBINARY(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @IDVariante IS NULL
       OR @IDVariante <= 0
        THROW 51610, N'La variante es inválida.', 1;
    
    IF (@IDUsuario IS NULL
        AND @TokenInvitadoHash IS NULL)
       OR (@IDUsuario IS NOT NULL
           AND @TokenInvitadoHash IS NOT NULL)
       OR (@TokenInvitadoHash IS NOT NULL
           AND DATALENGTH(@TokenInvitadoHash) <> 32)
        THROW 51601, N'Propietario del carrito inválido.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @IDCarrito AS BIGINT;
        
        DECLARE @IDDetalleCarrito AS BIGINT;
        
        DECLARE @ResultadoBloqueo AS INT;
        
        DECLARE @Recurso AS NVARCHAR(255);
        
        -- Serializar operaciones del mismo propietario.
        SET @Recurso = CASE WHEN @IDUsuario IS NOT NULL THEN CONCAT(N'Carrito:Usuario:', @IDUsuario) ELSE CONCAT(N'Carrito:Invitado:', CONVERT (VARCHAR(64), @TokenInvitadoHash, 2)) END;
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51602, N'No fue posible bloquear el carrito.', 1;
        
        -- Buscar carrito activo del propietario.
        SELECT TOP (1) @IDCarrito = IDCarrito
        FROM dbo.Carrito WITH (UPDLOCK, HOLDLOCK)
        WHERE Estado = 'ACTIVO'
              AND ((@IDUsuario IS NOT NULL
                    AND IDUsuario = @IDUsuario)
                   OR (@TokenInvitadoHash IS NOT NULL
                       AND TokenInvitadoHash = @TokenInvitadoHash))
        ORDER BY IDCarrito DESC;
        
        IF @IDCarrito IS NULL
            THROW 51608, N'No existe un carrito activo.', 1;
        
        -- Buscar la línea solicitada.
        SELECT @IDDetalleCarrito = IDDetalleCarrito
        FROM dbo.DetalleCarrito WITH (UPDLOCK, HOLDLOCK)
        WHERE IDCarrito = @IDCarrito
              AND IDVariante = @IDVariante;
        
        IF @IDDetalleCarrito IS NULL
            THROW 51609, N'La variante no existe en el carrito.', 1;
        
        -- Eliminar únicamente la línea del carrito.
        DELETE dbo.DetalleCarrito
        WHERE IDDetalleCarrito = @IDDetalleCarrito
              AND IDCarrito = @IDCarrito;
        
        UPDATE dbo.Carrito
        SET FechaUltimaActividad = SYSUTCDATETIME()
        WHERE IDCarrito = @IDCarrito;
        
        COMMIT TRANSACTION;
        
        SELECT @IDCarrito AS IDCarrito,
               @IDVariante AS IDVariante,
               CAST (1 AS BIT) AS Eliminado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;
        
        THROW;
    END CATCH
END