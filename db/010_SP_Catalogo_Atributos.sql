/* ShopCart | 010_SP_Catalogo_Atributos.sql
   Crea: 
   - SP_Catalogo_CrearAtributo
   - SP_Catalogo_CrearValorAtributo
*/
USE ShopCartDB;


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