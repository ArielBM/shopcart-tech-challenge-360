/* ShopCart | 008_SP_Catalogo_Productos.sql
   Crea: 
   - SP_Catalogo_CrearProducto
   - SP_Catalogo_ActualizarProducto
   - SP_Catalogo_ListarProductos
*/
USE ShopCartDB;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CrearProducto
    @IDCategoria INT,
    @Nombre NVARCHAR(200),
    @Descripcion NVARCHAR(MAX)=NULL,
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @Nombre = NULLIF (LTRIM(RTRIM(@Nombre)), N'');
    
    IF @Nombre IS NULL
        THROW 51200, N'El nombre del producto es obligatorio.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Bloquear la categoría hasta finalizar la transacción.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Categoria WITH (UPDLOCK, HOLDLOCK)
                       WHERE IDCategoria = @IDCategoria
                             AND Activa = 1)
            THROW 51201, N'La categoría no existe o está inactiva.', 1;
        
        INSERT INTO dbo.Producto (
            IDCategoria,
            Nombre,
            Descripcion
        )
        VALUES                   (@IDCategoria, @Nombre, @Descripcion);
        
        DECLARE @IDProducto AS INT = CONVERT (INT, SCOPE_IDENTITY());
        
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
               'CATALOGO',
               'Producto',
               @IDProducto,
               'CREAR',
               NULL,
               (SELECT IDProducto,
                       IDCategoria,
                       Nombre,
                       Descripcion,
                       Activo
                FROM dbo.Producto
                WHERE IDProducto = @IDProducto
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        
        COMMIT TRANSACTION;
        
        SELECT IDProducto,
               IDCategoria,
               Nombre,
               Descripcion,
               Activo,
               FechaCreacion,
               FechaActualizacion
        FROM dbo.Producto
        WHERE IDProducto = @IDProducto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ActualizarProducto
    @IDProducto INT,
    @IDCategoria INT,
    @Nombre NVARCHAR(200),
    @Descripcion NVARCHAR(MAX)=NULL,
    @Activo BIT,
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @Nombre = NULLIF (LTRIM(RTRIM(@Nombre)), N'');
    
    IF @Nombre IS NULL
        THROW 51200, N'El nombre del producto es obligatorio.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @ValorAnterior AS NVARCHAR(MAX);
        
        DECLARE @ValorNuevo AS NVARCHAR(MAX);
        
        -- Validar y bloquear primero la categoría.
        DECLARE @CategoriaActiva AS BIT;
        
        SELECT @CategoriaActiva = Activa
        FROM dbo.Categoria WITH (UPDLOCK, HOLDLOCK)
        WHERE IDCategoria = @IDCategoria;
        
        IF @CategoriaActiva IS NULL
            THROW 51201, N'La categoría no existe.', 1;
        
        IF @Activo = 1
           AND @CategoriaActiva = 0
            THROW 51201, N'La categoría está inactiva.', 1;
        
        -- Bloquear la ficha durante la actualización.
        SELECT @ValorAnterior = (SELECT IDProducto,
                                        IDCategoria,
                                        Nombre,
                                        Descripcion,
                                        Activo
                                 FROM dbo.Producto
                                 WHERE IDProducto = @IDProducto
                                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM dbo.Producto WITH (UPDLOCK, HOLDLOCK)
        WHERE IDProducto = @IDProducto;
        
        IF @ValorAnterior IS NULL
            THROW 51202, N'El producto no existe.', 1;
        
        UPDATE dbo.Producto
        SET IDCategoria        = @IDCategoria,
            Nombre             = @Nombre,
            Descripcion        = @Descripcion,
            Activo             = @Activo,
            FechaActualizacion = SYSUTCDATETIME()
        WHERE IDProducto = @IDProducto;
        
        SELECT @ValorNuevo = (SELECT IDProducto,
                                     IDCategoria,
                                     Nombre,
                                     Descripcion,
                                     Activo
                              FROM dbo.Producto
                              WHERE IDProducto = @IDProducto
                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        
        -- Registrar el cambio dentro de la misma transacción.
        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Entidad,
            IDEntidad,
            Accion,
            ValorAnterior,
            ValorNuevo
        )
        VALUES                   (@IDUsuario, 'CATALOGO', 'Producto', @IDProducto, 'ACTUALIZAR', @ValorAnterior, @ValorNuevo);
        
        COMMIT TRANSACTION;
        
        SELECT IDProducto,
               IDCategoria,
               Nombre,
               Descripcion,
               Activo,
               FechaCreacion,
               FechaActualizacion
        FROM dbo.Producto
        WHERE IDProducto = @IDProducto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ListarProductos
    @Busqueda NVARCHAR(200)=NULL,
    @IDCategoria INT=NULL,
    @PrecioMinimo VARCHAR(20)=NULL,
    @PrecioMaximo VARCHAR(20)=NULL,
    @SoloDisponibles BIT=0,
    @SoloActivos BIT=1,
    @Pagina INT=1,
    @TamanoPagina INT=20,
    @Orden VARCHAR(20)='NOMBRE_ASC',
    @TotalRegistros INT=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Validar paginación.
    IF @Pagina IS NULL
       OR @Pagina < 1
       OR @TamanoPagina IS NULL
       OR @TamanoPagina NOT BETWEEN 1 AND 100
        THROW 51203, N'Paginación inválida.', 1;
    
    -- 2. Validar precisión y formato monetario.
    -- Se aceptan hasta 16 enteros y 2 decimales.
    IF (@PrecioMinimo IS NOT NULL
        AND (@PrecioMinimo = ''
             OR @PrecioMinimo COLLATE Latin1_General_BIN2 LIKE '%[^0-9.]%'
             OR LEN(@PrecioMinimo) - LEN(REPLACE(@PrecioMinimo, '.', '')) > 1
             OR CHARINDEX('.', @PrecioMinimo) = 1
             OR RIGHT(@PrecioMinimo, 1) = '.'
             OR LEN(LEFT(@PrecioMinimo, CHARINDEX('.', @PrecioMinimo + '.') - 1)) > 16
             OR (CHARINDEX('.', @PrecioMinimo) > 0
                 AND LEN(@PrecioMinimo) - CHARINDEX('.', @PrecioMinimo) > 2)))
       OR (@PrecioMaximo IS NOT NULL
           AND (@PrecioMaximo = ''
                OR @PrecioMaximo COLLATE Latin1_General_BIN2 LIKE '%[^0-9.]%'
                OR LEN(@PrecioMaximo) - LEN(REPLACE(@PrecioMaximo, '.', '')) > 1
                OR CHARINDEX('.', @PrecioMaximo) = 1
                OR RIGHT(@PrecioMaximo, 1) = '.'
                OR LEN(LEFT(@PrecioMaximo, CHARINDEX('.', @PrecioMaximo + '.') - 1)) > 16
                OR (CHARINDEX('.', @PrecioMaximo) > 0
                    AND LEN(@PrecioMaximo) - CHARINDEX('.', @PrecioMaximo) > 2)))
        THROW 51204, N'Formato de precios inválido.', 1;
    
    DECLARE @PrecioMinimoValor AS DECIMAL(18,2) = TRY_CONVERT (DECIMAL(18,2), @PrecioMinimo);
    
    DECLARE @PrecioMaximoValor AS DECIMAL(18,2) = TRY_CONVERT (DECIMAL(18,2), @PrecioMaximo);
    
    IF (@PrecioMinimo IS NOT NULL
        AND @PrecioMinimoValor IS NULL)
       OR (@PrecioMaximo IS NOT NULL
           AND @PrecioMaximoValor IS NULL)
       OR (@PrecioMinimoValor IS NOT NULL
           AND @PrecioMaximoValor IS NOT NULL
           AND @PrecioMinimoValor > @PrecioMaximoValor)
        THROW 51204, N'Rango de precios inválido.', 1;
    
    -- 3. Validar ordenamiento.
    IF @Orden IS NULL
       OR @Orden NOT IN ('NOMBRE_ASC', 'NOMBRE_DESC', 'PRECIO_ASC', 'PRECIO_DESC')
        THROW 51205, N'Ordenamiento inválido.', 1;
    
    DECLARE @Offset AS BIGINT = (CONVERT (BIGINT, @Pagina) - 1) * @TamanoPagina;
    
    SET @Busqueda = NULLIF (LTRIM(RTRIM(@Busqueda)), N''); -- 4. Calcular disponibilidad y filtrar productos.
    
    WITH Disponibilidad
    AS (SELECT IDVariante,
               SUM(CONVERT (BIGINT, ExistenciaFisica) - CantidadReservada) AS Disponible
        FROM dbo.InventarioPorUbicacion
        GROUP BY IDVariante),
     Variantes
    AS (SELECT V.IDProducto,
               V.IDVariante,
               V.PrecioActual,
               COALESCE (D.Disponible, 0) AS Disponible
        FROM dbo.Variante AS V
             LEFT OUTER JOIN
             Disponibilidad AS D
             ON D.IDVariante = V.IDVariante
        WHERE V.Activa = 1),
     ProductosFiltrados
    AS (SELECT P.IDProducto,
               P.IDCategoria,
               C.Nombre AS Categoria,
               P.Nombre,
               P.Descripcion,
               P.Activo,
               P.FechaCreacion,
               P.FechaActualizacion,
               MIN(V.PrecioActual) AS PrecioDesde,
               COUNT(V.IDVariante) AS CantidadVariantes,
               COALESCE (SUM(V.Disponible), 0) AS DisponibleTotal
        FROM dbo.Producto AS P
             INNER JOIN
             dbo.Categoria AS C
             ON C.IDCategoria = P.IDCategoria
             LEFT OUTER JOIN
             Variantes AS V
             ON V.IDProducto = P.IDProducto
        WHERE (@SoloActivos = 0
               OR (P.Activo = 1
                   AND C.Activa = 1))
              AND (@IDCategoria IS NULL
                   OR P.IDCategoria = @IDCategoria)
              AND (@Busqueda IS NULL
                   OR P.Nombre LIKE N'%' + @Busqueda + N'%'
                   OR P.Descripcion LIKE N'%' + @Busqueda + N'%')
        GROUP BY P.IDProducto, P.IDCategoria, C.Nombre, P.Nombre, P.Descripcion, P.Activo, P.FechaCreacion, P.FechaActualizacion
        HAVING ((@PrecioMinimoValor IS NULL
                 AND @PrecioMaximoValor IS NULL)
                OR SUM(CASE WHEN (@PrecioMinimoValor IS NULL
                                  OR V.PrecioActual >= @PrecioMinimoValor)
                                 AND (@PrecioMaximoValor IS NULL
                                      OR V.PrecioActual <= @PrecioMaximoValor) THEN 1 ELSE 0 END) > 0)
               AND (@SoloDisponibles = 0
                    OR SUM(CASE WHEN V.Disponible > 0
                                     AND (@PrecioMinimoValor IS NULL
                                          OR V.PrecioActual >= @PrecioMinimoValor)
                                     AND (@PrecioMaximoValor IS NULL
                                          OR V.PrecioActual <= @PrecioMaximoValor) THEN 1 ELSE 0 END) > 0))
    SELECT -- 5. Materializar antes de paginar.
           *
    INTO #ProductosFiltrados
    FROM ProductosFiltrados;
    
    -- 6. Obtener el total independientemente
    -- de las filas de la página solicitada.
    SELECT @TotalRegistros = COUNT(*)
    FROM #ProductosFiltrados;
    
    -- 7. Devolver la página solicitada.
    SELECT IDProducto,
           IDCategoria,
           Categoria,
           Nombre,
           Descripcion,
           Activo,
           FechaCreacion,
           FechaActualizacion,
           PrecioDesde,
           CantidadVariantes,
           DisponibleTotal
    FROM #ProductosFiltrados
    ORDER BY CASE WHEN @Orden = 'NOMBRE_ASC' THEN Nombre END ASC, CASE WHEN @Orden = 'NOMBRE_DESC' THEN Nombre END DESC, CASE WHEN @Orden = 'PRECIO_ASC' THEN PrecioDesde END ASC, CASE WHEN @Orden = 'PRECIO_DESC' THEN PrecioDesde END DESC, IDProducto ASC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END