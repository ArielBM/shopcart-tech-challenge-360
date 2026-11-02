/* ShopCart | 008_SP_Catalogo_Productos.sql
   Crea: 
   - SP_Catalogo_CrearProducto
   - SP_Catalogo_ActualizarProducto
   - SP_Catalogo_ListarProductos
   - SP_Catalogo_CrearVariante
   - SP_Catalogo_AsignarAtributoVariante
   - SP_Catalogo_CrearAtributo
   - SP_Catalogo_CrearValorAtributo
   - SP_Catalogo_GuardarAtributosVariante
   - SP_Catalogo_ActualizarVariante
   - SP_Catalogo_ListarVariantesProducto
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
    
    IF NOT EXISTS (SELECT 1
                   FROM dbo.Categoria
                   WHERE IDCategoria = @IDCategoria
                         AND Activa = 1)
        THROW 51201, N'La categoría no existe o está inactiva.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
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
        
        -- Un producto activo requiere categoría activa.
        IF @Activo = 1
           AND NOT EXISTS (SELECT 1
                           FROM dbo.Categoria WITH (UPDLOCK, HOLDLOCK)
                           WHERE IDCategoria = @IDCategoria
                                 AND Activa = 1)
            THROW 51201, N'La categoría no existe o está inactiva.', 1;
        
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
    @PrecioMinimo DECIMAL(18,2)=NULL,
    @PrecioMaximo DECIMAL(18,2)=NULL,
    @SoloDisponibles BIT=0,
    @SoloActivos BIT=1,
    @Pagina INT=1,
    @TamanoPagina INT=20,
    @Orden VARCHAR(20)='NOMBRE_ASC'
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @Pagina < 1
       OR @TamanoPagina NOT BETWEEN 1 AND 100
       OR @Pagina IS NULL
       OR @TamanoPagina IS NULL
        THROW 51203, N'Paginación inválida.', 1;
    
    IF @PrecioMinimo < 0
       OR @PrecioMaximo < 0
       OR (@PrecioMinimo IS NOT NULL
           AND @PrecioMaximo IS NOT NULL
           AND @PrecioMinimo > @PrecioMaximo)
        THROW 51204, N'Rango de precios inválido.', 1;
    
    IF @Orden IS NULL
       OR @Orden NOT IN ('NOMBRE_ASC', 'NOMBRE_DESC', 'PRECIO_ASC', 'PRECIO_DESC')
        THROW 51205, N'Ordenamiento inválido.', 1;
    
    DECLARE @Offset AS BIGINT = (CONVERT (BIGINT, @Pagina) - 1) * @TamanoPagina;
    
    SET @Busqueda = NULLIF (LTRIM(RTRIM(@Busqueda)), N''); -- Variantes activas con disponibilidad por ubicación.
    
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
        HAVING (@PrecioMinimo IS NULL
                AND @PrecioMaximo IS NULL
                OR SUM(CASE WHEN (@PrecioMinimo IS NULL
                                  OR V.PrecioActual >= @PrecioMinimo)
                                 AND (@PrecioMaximo IS NULL
                                      OR V.PrecioActual <= @PrecioMaximo) THEN 1 ELSE 0 END) > 0)
               AND (@SoloDisponibles = 0
                    OR SUM(CASE WHEN V.Disponible > 0
                                     AND (@PrecioMinimo IS NULL
                                          OR V.PrecioActual >= @PrecioMinimo)
                                     AND (@PrecioMaximo IS NULL
                                          OR V.PrecioActual <= @PrecioMaximo) THEN 1 ELSE 0 END) > 0))
    SELECT *,
           COUNT(*) OVER () AS TotalRegistros
    FROM ProductosFiltrados
    ORDER BY CASE WHEN @Orden = 'NOMBRE_ASC' THEN Nombre END ASC, CASE WHEN @Orden = 'NOMBRE_DESC' THEN Nombre END DESC, CASE WHEN @Orden = 'PRECIO_ASC' THEN PrecioDesde END ASC, CASE WHEN @Orden = 'PRECIO_DESC' THEN PrecioDesde END DESC, IDProducto ASC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CrearVariante
    @IDProducto INT,
    @SKU VARCHAR(64),
    @PrecioActual DECIMAL(18,2),
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @SKU = NULLIF (LTRIM(RTRIM(@SKU)), '');
    
    IF @SKU IS NULL
        THROW 51300, N'El SKU es obligatorio.', 1;
    
    IF @PrecioActual IS NULL
       OR @PrecioActual < 0
        THROW 51301, N'El precio no puede ser negativo.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validar el producto y su categoría.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Producto AS P WITH (UPDLOCK, HOLDLOCK)
                            INNER JOIN
                            dbo.Categoria AS C
                            ON C.IDCategoria = P.IDCategoria
                       WHERE P.IDProducto = @IDProducto
                             AND P.Activo = 1
                             AND C.Activa = 1)
            THROW 51302, N'El producto no existe o está inactivo.', 1;
        
        -- La restricción UQ_Variante_SKU garantiza
        -- unicidad incluso con solicitudes simultáneas.
        INSERT INTO dbo.Variante (
            IDProducto,
            SKU,
            PrecioActual
        )
        VALUES                   (@IDProducto, @SKU, @PrecioActual);
        
        DECLARE @IDVariante AS INT = CONVERT (INT, SCOPE_IDENTITY());
        
        -- Auditoría de la creación.
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
               'Variante',
               @IDVariante,
               'CREAR',
               NULL,
               (SELECT IDVariante,
                       IDProducto,
                       SKU,
                       PrecioActual,
                       Activa
                FROM dbo.Variante
                WHERE IDVariante = @IDVariante
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        
        COMMIT TRANSACTION;
        
        SELECT IDVariante,
               IDProducto,
               SKU,
               PrecioActual,
               Activa,
               FechaCreacion,
               FechaActualizacion
        FROM dbo.Variante
        WHERE IDVariante = @IDVariante;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        -- Error específico para SKU duplicado.
        IF ERROR_NUMBER() IN (2601, 2627)
           AND ERROR_MESSAGE() LIKE '%UQ_Variante_SKU%'
            THROW 51303, N'El SKU ya está registrado.', 1;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CrearAtributo
    @Nombre NVARCHAR(80)
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @Nombre = NULLIF (LTRIM(RTRIM(@Nombre)), N'');
    
    IF @Nombre IS NULL
        THROW 51400, N'El nombre del atributo es obligatorio.', 1;
    
    BEGIN TRY
        INSERT INTO dbo.Atributo (
            Nombre
        )
        OUTPUT INSERTED.IDAtributo, INSERTED.Nombre
        VALUES                   (@Nombre);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
           AND ERROR_MESSAGE() LIKE '%UQ_Atributo_Nombre%'
            THROW 51401, N'El atributo ya existe.', 1;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CrearValorAtributo
    @IDAtributo INT,
    @Valor NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @Valor = NULLIF (LTRIM(RTRIM(@Valor)), N'');
    
    IF @Valor IS NULL
        THROW 51402, N'El valor es obligatorio.', 1;
    
    IF NOT EXISTS (SELECT 1
                   FROM dbo.Atributo
                   WHERE IDAtributo = @IDAtributo)
        THROW 51403, N'El atributo no existe.', 1;
    
    BEGIN TRY
        INSERT INTO dbo.ValorAtributo (
            IDAtributo,
            Valor
        )
        OUTPUT INSERTED.IDValorAtributo, INSERTED.IDAtributo, INSERTED.Valor
        VALUES                        (@IDAtributo, @Valor);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
           AND ERROR_MESSAGE() LIKE '%UQ_ValorAtributo_Atributo_Valor%'
            THROW 51404, N'El valor ya existe para este atributo.', 1;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_GuardarAtributosVariante
    @IDVariante INT,
    @ValoresJSON NVARCHAR(MAX),
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @ValoresJSON IS NULL
       OR ISJSON(@ValoresJSON) <> 1
       OR LEFT(LTRIM(@ValoresJSON), 1) <> N'['
        THROW 51306, N'Se requiere un arreglo JSON válido.', 1;
    
    DECLARE @Valores TABLE (
        IDAtributo      INT PRIMARY KEY,
        IDValorAtributo INT NOT NULL);
    
    DECLARE @Entrada TABLE (
        IDValorAtributo INT NULL);
    
    -- Solo se aceptan identificadores enteros positivos.
    IF EXISTS (SELECT 1
               FROM OPENJSON (@ValoresJSON)
               WHERE [type] <> 2
                     OR TRY_CONVERT (INT, [value]) IS NULL
                     OR TRY_CONVERT (INT, [value]) <= 0
                     OR [value] LIKE '%.%'
                     OR [value] LIKE '%e%'
                     OR [value] LIKE '%E%')
        THROW 51307, N'Los identificadores deben ser enteros positivos.', 1;
    
    INSERT INTO @Entrada (
        IDValorAtributo
    )
    SELECT TRY_CONVERT (INT, [value])
    FROM OPENJSON (@ValoresJSON);
    
    IF NOT EXISTS (SELECT 1
                   FROM @Entrada)
        THROW 51308, N'Debe seleccionar al menos un atributo.', 1;
    
    IF EXISTS (SELECT IDValorAtributo
               FROM @Entrada
               GROUP BY IDValorAtributo
               HAVING COUNT(*) > 1)
        THROW 51309, N'Hay valores de atributo repetidos.', 1;
    
    IF EXISTS (SELECT 1
               FROM @Entrada AS E
                    LEFT OUTER JOIN
                    dbo.ValorAtributo AS V
                    ON V.IDValorAtributo = E.IDValorAtributo
               WHERE V.IDValorAtributo IS NULL)
        THROW 51305, N'Un valor de atributo no existe.', 1;
    
    -- No se permiten dos valores del mismo atributo.
    IF EXISTS (SELECT V.IDAtributo
               FROM @Entrada AS E
                    INNER JOIN
                    dbo.ValorAtributo AS V
                    ON V.IDValorAtributo = E.IDValorAtributo
               GROUP BY V.IDAtributo
               HAVING COUNT(*) > 1)
        THROW 51310, N'No puede asignar dos valores del mismo atributo.', 1;
    
    INSERT INTO @Valores (
        IDAtributo,
        IDValorAtributo
    )
    SELECT V.IDAtributo,
           V.IDValorAtributo
    FROM @Entrada AS E
         INNER JOIN
         dbo.ValorAtributo AS V
         ON V.IDValorAtributo = E.IDValorAtributo;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @IDProducto AS INT;
        
        DECLARE @Anterior AS NVARCHAR(MAX);
        
        DECLARE @Nuevo AS NVARCHAR(MAX);
        
        -- Determinar el producto propietario.
        SELECT @IDProducto = IDProducto
        FROM dbo.Variante
        WHERE IDVariante = @IDVariante;
        
        IF @IDProducto IS NULL
            THROW 51304, N'La variante no existe.', 1;
        
        -- Serializar operaciones de atributos por producto.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Producto WITH (UPDLOCK, HOLDLOCK)
                       WHERE IDProducto = @IDProducto)
            THROW 51302, N'El producto no existe.', 1;
        
        -- Revalidar que la variante sigue perteneciendo al producto.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Variante WITH (UPDLOCK, HOLDLOCK)
                       WHERE IDVariante = @IDVariante
                             AND IDProducto = @IDProducto)
            THROW 51304, N'La variante cambió durante la operación.', 1;
        
        -- Rechazar otra variante con la combinación exacta.
        IF EXISTS (SELECT 1
                   FROM dbo.Variante AS V
                   WHERE V.IDProducto = @IDProducto
                         AND V.IDVariante <> @IDVariante
                         AND NOT EXISTS (SELECT IDAtributo,
                                                IDValorAtributo
                                         FROM @Valores
                                         EXCEPT
                                         SELECT VA.IDAtributo,
                                                VA.IDValorAtributo
                                         FROM dbo.VarianteAtributo AS VA
                                         WHERE VA.IDVariante = V.IDVariante)
                         AND NOT EXISTS (SELECT VA.IDAtributo,
                                                VA.IDValorAtributo
                                         FROM dbo.VarianteAtributo AS VA
                                         WHERE VA.IDVariante = V.IDVariante
                                         EXCEPT
                                         SELECT IDAtributo,
                                                IDValorAtributo
                                         FROM @Valores))
            THROW 51311, N'Ya existe una variante con esta combinación.', 1;
        
        SELECT @Anterior = (SELECT IDAtributo,
                                   IDValorAtributo
                            FROM dbo.VarianteAtributo
                            WHERE IDVariante = @IDVariante
                            ORDER BY IDAtributo
                            FOR JSON PATH);
        
        -- Reemplazar toda la combinación.
        DELETE dbo.VarianteAtributo
        WHERE IDVariante = @IDVariante;
        
        INSERT INTO dbo.VarianteAtributo (
            IDVariante,
            IDAtributo,
            IDValorAtributo
        )
        SELECT @IDVariante AS IDVariante,
               IDAtributo,
               IDValorAtributo
        FROM @Valores;
        
        UPDATE dbo.Variante
        SET FechaActualizacion = SYSUTCDATETIME()
        WHERE IDVariante = @IDVariante;
        
        SELECT @Nuevo = (SELECT IDAtributo,
                                IDValorAtributo
                         FROM dbo.VarianteAtributo
                         WHERE IDVariante = @IDVariante
                         ORDER BY IDAtributo
                         FOR JSON PATH);
        
        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Entidad,
            IDEntidad,
            Accion,
            ValorAnterior,
            ValorNuevo
        )
        VALUES                   (@IDUsuario, 'CATALOGO', 'VarianteAtributo', @IDVariante, 'ACTUALIZAR', @Anterior, @Nuevo);
        
        COMMIT TRANSACTION;
        
        SELECT VA.IDVariante,
               A.IDAtributo,
               A.Nombre AS Atributo,
               V.IDValorAtributo,
               V.Valor
        FROM dbo.VarianteAtributo AS VA
             INNER JOIN
             dbo.Atributo AS A
             ON A.IDAtributo = VA.IDAtributo
             INNER JOIN
             dbo.ValorAtributo AS V
             ON V.IDValorAtributo = VA.IDValorAtributo
        WHERE VA.IDVariante = @IDVariante
        ORDER BY A.Nombre;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ActualizarVariante
    @IDVariante INT,
    @SKU VARCHAR(64),
    @PrecioActual DECIMAL(18,2),
    @Activa BIT,
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @SKU = NULLIF (LTRIM(RTRIM(@SKU)), '');
    
    IF @SKU IS NULL
        THROW 51300, N'El SKU es obligatorio.', 1;
    
    IF @PrecioActual IS NULL
       OR @PrecioActual < 0
        THROW 51301, N'El precio no puede ser negativo.', 1;
    
    IF @Activa IS NULL
        THROW 51312, N'El estado de la variante es obligatorio.', 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @IDProducto AS INT;
        
        DECLARE @Anterior AS NVARCHAR(MAX);
        
        DECLARE @Nuevo AS NVARCHAR(MAX);
        
        -- Bloquear la variante durante la actualización.
        SELECT @IDProducto = IDProducto
        FROM dbo.Variante WITH (UPDLOCK, HOLDLOCK)
        WHERE IDVariante = @IDVariante;
        
        IF @IDProducto IS NULL
            THROW 51304, N'La variante no existe.', 1;
        
        -- Una variante activa requiere producto y categoría activos.
        IF @Activa = 1
           AND NOT EXISTS (SELECT 1
                           FROM dbo.Producto AS P WITH (UPDLOCK, HOLDLOCK)
                                INNER JOIN
                                dbo.Categoria AS C
                                ON C.IDCategoria = P.IDCategoria
                           WHERE P.IDProducto = @IDProducto
                                 AND P.Activo = 1
                                 AND C.Activa = 1)
            THROW 51302, N'El producto o su categoría están inactivos.', 1;
        
        SELECT @Anterior = (SELECT IDVariante,
                                   IDProducto,
                                   SKU,
                                   PrecioActual,
                                   Activa
                            FROM dbo.Variante
                            WHERE IDVariante = @IDVariante
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        
        UPDATE dbo.Variante
        SET SKU                = @SKU,
            PrecioActual       = @PrecioActual,
            Activa             = @Activa,
            FechaActualizacion = SYSUTCDATETIME()
        WHERE IDVariante = @IDVariante;
        
        SELECT @Nuevo = (SELECT IDVariante,
                                IDProducto,
                                SKU,
                                PrecioActual,
                                Activa
                         FROM dbo.Variante
                         WHERE IDVariante = @IDVariante
                         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        
        -- Auditar el cambio, incluyendo el precio anterior.
        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Entidad,
            IDEntidad,
            Accion,
            ValorAnterior,
            ValorNuevo
        )
        VALUES                   (@IDUsuario, 'CATALOGO', 'Variante', @IDVariante, 'ACTUALIZAR', @Anterior, @Nuevo);
        
        COMMIT TRANSACTION;
        
        SELECT IDVariante,
               IDProducto,
               SKU,
               PrecioActual,
               Activa,
               FechaCreacion,
               FechaActualizacion
        FROM dbo.Variante
        WHERE IDVariante = @IDVariante;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        IF ERROR_NUMBER() IN (2601, 2627)
           AND ERROR_MESSAGE() LIKE '%UQ_Variante_SKU%'
            THROW 51303, N'El SKU ya está registrado.', 1;
        
        THROW;
    END CATCH
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ListarVariantesProducto
    @IDProducto INT,
    @SoloActivas BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @IDProducto IS NULL
       OR @IDProducto <= 0
        THROW 51313, N'El producto es obligatorio.', 1;
    
    IF @SoloActivas IS NULL
        THROW 51314, N'El filtro de estado es obligatorio.', 1;
    
    -- En consultas públicas, ocultar productos
    -- y categorías inactivas.
    IF @SoloActivas = 1
       AND NOT EXISTS (SELECT 1
                       FROM dbo.Producto AS P
                            INNER JOIN
                            dbo.Categoria AS C
                            ON C.IDCategoria = P.IDCategoria
                       WHERE P.IDProducto = @IDProducto
                             AND P.Activo = 1
                             AND C.Activa = 1)
        THROW 51202, N'El producto no existe.', 1;
    
    -- En administración, permitir productos inactivos.
    IF @SoloActivas = 0
       AND NOT EXISTS (SELECT 1
                       FROM dbo.Producto
                       WHERE IDProducto = @IDProducto)
        THROW 51202, N'El producto no existe.', 1;
    
    SELECT V.IDVariante,
           V.IDProducto,
           V.SKU,
           V.PrecioActual,
           V.Activa,
           V.FechaCreacion,
           V.FechaActualizacion,
           COALESCE (I.ExistenciaFisica, 0) AS ExistenciaFisica,
           COALESCE (I.CantidadReservada, 0) AS CantidadReservada,
           COALESCE (I.Disponible, 0) AS Disponible,
           COALESCE (A.AtributosJSON, N'[]') AS AtributosJSON
    FROM dbo.Variante AS V
         OUTER APPLY (SELECT SUM(CONVERT (BIGINT, IU.ExistenciaFisica)) AS ExistenciaFisica,
                             SUM(CONVERT (BIGINT, IU.CantidadReservada)) AS CantidadReservada,
                             SUM(CONVERT (BIGINT, IU.ExistenciaFisica) - IU.CantidadReservada) AS Disponible
                      FROM dbo.InventarioPorUbicacion AS IU
                           INNER JOIN
                           dbo.Ubicacion AS U
                           ON U.IDUbicacion = IU.IDUbicacion
                      WHERE IU.IDVariante = V.IDVariante
                            AND U.Activa = 1) AS I
         OUTER APPLY (SELECT (SELECT A.IDAtributo,
                                     A.Nombre AS Atributo,
                                     VA.IDValorAtributo,
                                     VA2.Valor
                              FROM dbo.VarianteAtributo AS VA
                                   INNER JOIN
                                   dbo.Atributo AS A
                                   ON A.IDAtributo = VA.IDAtributo
                                   INNER JOIN
                                   dbo.ValorAtributo AS VA2
                                   ON VA2.IDValorAtributo = VA.IDValorAtributo
                              WHERE VA.IDVariante = V.IDVariante
                              ORDER BY A.Nombre, A.IDAtributo
                              FOR JSON PATH) AS AtributosJSON) AS A
    WHERE V.IDProducto = @IDProducto
          AND (@SoloActivas = 0
               OR V.Activa = 1)
    ORDER BY V.IDVariante;
END