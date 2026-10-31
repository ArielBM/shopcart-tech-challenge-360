/* ShopCart | 007_SP_Catalogo_Categorias.sql
   Crea: SP_Catalogo_CrearCategoria
         SP_Catalogo_ListarCategorias
         SP_Catalogo_ActualizarCategoria
*/
USE ShopCartDB;


GO

SET NOCOUNT ON;

SET XACT_ABORT ON;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CrearCategoria
    @Nombre NVARCHAR(120),
    @Descripcion NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @Nombre = NULLIF (LTRIM(RTRIM(@Nombre)), N'');
    
    IF @Nombre IS NULL
        THROW 51100, N'El nombre de la categoría es obligatorio.', 1;
    
    INSERT INTO dbo.Categoria (
        Nombre,
        Descripcion
    )
    OUTPUT INSERTED.IDCategoria, INSERTED.Nombre, INSERTED.Descripcion, INSERTED.Activa, INSERTED.FechaCreacion
    VALUES                    (@Nombre, @Descripcion);
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ListarCategorias
    @SoloActivas BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT IDCategoria,
           Nombre,
           Descripcion,
           Activa,
           FechaCreacion
    FROM dbo.Categoria
    WHERE @SoloActivas = 0
          OR Activa = 1
    ORDER BY Nombre, IDCategoria;
END


GO

-- 3. Actualizar una categoría existente.
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ActualizarCategoria
    @IDCategoria INT,
    @Nombre NVARCHAR(120),
    @Descripcion NVARCHAR(500)=NULL,
    @Activa BIT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @Nombre = NULLIF (LTRIM(RTRIM(@Nombre)), N'');
    
    IF @Nombre IS NULL
        THROW 51100, N'El nombre de la categoría es obligatorio.', 1;
    
    UPDATE dbo.Categoria
    SET Nombre      = @Nombre,
        Descripcion = @Descripcion,
        Activa      = @Activa
    WHERE IDCategoria = @IDCategoria;
    
    IF @@ROWCOUNT = 0
        THROW 51101, N'La categoría no existe.', 1;
    
    SELECT IDCategoria,
           Nombre,
           Descripcion,
           Activa,
           FechaCreacion
    FROM dbo.Categoria
    WHERE IDCategoria = @IDCategoria;
END