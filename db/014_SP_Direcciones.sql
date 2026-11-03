/* ShopCart | 014_SP_Direcciones.sql
   Crea:
   - SP_Direcciones_Registrar
   - SP_Direcciones_Consultar
*/
USE ShopCartDB;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Direcciones_Registrar
    @IDUsuario INT,
    @NombreDestinatario NVARCHAR(150),
    @Telefono VARCHAR(30)=NULL,
    @Departamento NVARCHAR(100),
    @Municipio NVARCHAR(100),
    @DireccionTexto NVARCHAR(500),
    @Referencia NVARCHAR(300)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    SET @NombreDestinatario = NULLIF (LTRIM(RTRIM(@NombreDestinatario)), N'');
    
    SET @Telefono = NULLIF (LTRIM(RTRIM(@Telefono)), '');
    
    SET @Departamento = NULLIF (LTRIM(RTRIM(@Departamento)), N'');
    
    SET @Municipio = NULLIF (LTRIM(RTRIM(@Municipio)), N'');
    
    SET @DireccionTexto = NULLIF (LTRIM(RTRIM(@DireccionTexto)), N'');
    
    SET @Referencia = NULLIF (LTRIM(RTRIM(@Referencia)), N'');
    
    IF @IDUsuario IS NULL
       OR @IDUsuario <= 0
        THROW 51800, N'El cliente no es válido.', 1;
    
    IF @NombreDestinatario IS NULL
       OR @Departamento IS NULL
       OR @Municipio IS NULL
       OR @DireccionTexto IS NULL
        THROW 51801, N'Los campos obligatorios de la dirección no son válidos.', 1;
    
    IF NOT EXISTS (SELECT 1
                   FROM dbo.Usuario AS u
                        INNER JOIN
                        dbo.Rol AS r
                        ON r.IDRol = u.IDRol
                   WHERE u.IDUsuario = @IDUsuario
                         AND u.Activo = 1
                         AND r.Codigo = 'CLIENTE')
        THROW 51802, N'El cliente no existe o está inactivo.', 1;
    
    INSERT INTO dbo.Direccion (
        IDUsuario,
        NombreDestinatario,
        Telefono,
        Departamento,
        Municipio,
        DireccionTexto,
        Referencia,
        Activa
    )
    VALUES                    (@IDUsuario, @NombreDestinatario, @Telefono, @Departamento, @Municipio, @DireccionTexto, @Referencia, 1);
    
    DECLARE @IDDireccion AS BIGINT = CONVERT (BIGINT, SCOPE_IDENTITY());
    
    SELECT IDDireccion,
           NombreDestinatario,
           Telefono,
           Departamento,
           Municipio,
           DireccionTexto,
           Referencia,
           Activa,
           FechaCreacion
    FROM dbo.Direccion
    WHERE IDDireccion = @IDDireccion
          AND IDUsuario = @IDUsuario;
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Direcciones_Consultar
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @IDUsuario IS NULL
       OR @IDUsuario <= 0
        THROW 51800, N'El cliente no es válido.', 1;
    
    SELECT IDDireccion,
           NombreDestinatario,
           Telefono,
           Departamento,
           Municipio,
           DireccionTexto,
           Referencia,
           Activa,
           FechaCreacion
    FROM dbo.Direccion
    WHERE IDUsuario = @IDUsuario
          AND Activa = 1
    ORDER BY FechaCreacion DESC, IDDireccion DESC;
END