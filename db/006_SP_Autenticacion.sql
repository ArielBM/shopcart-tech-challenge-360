/* ShopCart | 006_SP_Autenticacion.sql
 Crea:
 - SP_Auth_RegistrarCliente
 - SP_Auth_ObtenerUsuarioPorCorreo
 - SP_Auth_CrearSesion
 */
USE ShopCartDB;

SET QUOTED_IDENTIFIER ON;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Auth_RegistrarCliente
    @Correo NVARCHAR(254),
    @HashContrasena VARCHAR(255),
    @Nombre NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @Correo = LOWER(LTRIM(RTRIM(@Correo)));
    
    SET @Nombre = LTRIM(RTRIM(@Nombre));
    
    IF @Correo IS NULL
       OR @Correo = N''
       OR @Nombre IS NULL
       OR @Nombre = N''
       OR @HashContrasena IS NULL
       OR @HashContrasena = ''
        THROW 51010, N'Datos de registro obligatorios.', 1;
    
    DECLARE @IDRol AS INT;
    
    SELECT @IDRol = IDRol
    FROM dbo.Rol
    WHERE Codigo = 'CLIENTE';
    
    IF @IDRol IS NULL
        THROW 51011, N'El rol Cliente no existe.', 1;
    
    INSERT INTO dbo.Usuario (
        IDRol,
        Correo,
        HashContrasena,
        Nombre
    )
    OUTPUT INSERTED.IDUsuario, INSERTED.Correo, INSERTED.Nombre
    VALUES                  (@IDRol, @Correo, @HashContrasena, @Nombre);
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Auth_ObtenerUsuarioPorCorreo
    @Correo NVARCHAR(254)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT u.IDUsuario,
           u.Correo,
           u.Nombre,
           u.HashContrasena,
           r.Codigo AS Rol
    FROM dbo.Usuario AS u
         INNER JOIN
         dbo.Rol AS r
         ON r.IDRol = u.IDRol
    WHERE u.Correo = LOWER(LTRIM(RTRIM(@Correo)))
          AND u.Activo = 1;
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Auth_CrearSesion
    @IDUsuario INT,
    @TokenHash VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validar antes de guardar evita aceptar hashes incompletos o truncados.
    IF @TokenHash IS NULL
       OR DATALENGTH(@TokenHash) <> 32
        THROW 51021, N'El hash del token debe contener exactamente 32 bytes.', 1;
    
    DECLARE @Ahora AS DATETIME2(3) = SYSUTCDATETIME();
    
    INSERT INTO dbo.RefreshToken (
        IDUsuario,
        TokenHash,
        IDFamilia,
        FechaCreacion,
        FechaExpiracion
    )
    OUTPUT INSERTED.IDRefreshToken, INSERTED.IDFamilia, INSERTED.FechaExpiracion
    SELECT u.IDUsuario,
           @TokenHash,
           NEWID(),
           @Ahora,
           DATEADD(DAY, 7, @Ahora)
    FROM dbo.Usuario AS u
    WHERE u.IDUsuario = @IDUsuario
          AND u.Activo = 1;
    
    IF @@ROWCOUNT = 0
        THROW 51020, N'No se puede crear la sesión.', 1;
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Auth_RotarSesion
    @TokenHashActual VARBINARY(MAX),
    @TokenHashNuevo VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @TokenHashActual IS NULL
       OR DATALENGTH(@TokenHashActual) <> 32
       OR @TokenHashNuevo IS NULL
       OR DATALENGTH(@TokenHashNuevo) <> 32
        THROW 51021, N'Los hashes deben contener exactamente 32 bytes.', 1;
    
    IF @TokenHashActual = @TokenHashNuevo
        THROW 51025, N'El nuevo token debe ser diferente.', 1;
    
    DECLARE @Ahora AS DATETIME2(3) = SYSUTCDATETIME();
    
    DECLARE @IDAnterior AS BIGINT;
    
    DECLARE @IDNuevo AS BIGINT;
    
    DECLARE @IDUsuario AS INT;
    
    DECLARE @IDFamilia AS UNIQUEIDENTIFIER;
    
    DECLARE @Expiracion AS DATETIME2(3);
    
    DECLARE @Revocacion AS DATETIME2(3);
    
    DECLARE @Activo AS BIT;
    
    DECLARE @Reutilizado AS BIT = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        SELECT @IDAnterior = rt.IDRefreshToken,
               @IDUsuario = rt.IDUsuario,
               @IDFamilia = rt.IDFamilia,
               @Expiracion = rt.FechaExpiracion,
               @Revocacion = rt.FechaRevocacion,
               @Activo = u.Activo
        FROM dbo.RefreshToken AS rt WITH (UPDLOCK, HOLDLOCK)
             INNER JOIN
             dbo.Usuario AS u
             ON u.IDUsuario = rt.IDUsuario
        WHERE rt.TokenHash = @TokenHashActual;
        
        IF @IDAnterior IS NULL
            THROW 51022, N'Token desconocido.', 1;
        
        IF @Revocacion IS NOT NULL
            BEGIN
                -- El token ya fue consumido o revocado.
                -- Invalidar toda la familia ante posible reutilización.
                UPDATE dbo.RefreshToken
                SET FechaRevocacion = @Ahora
                WHERE IDFamilia = @IDFamilia
                      AND FechaRevocacion IS NULL;
                
                SET @Reutilizado = 1;
            END
        ELSE
            BEGIN
                IF @Expiracion <= @Ahora
                   OR @Activo = 0
                    THROW 51023, N'Sesion no vigente.', 1;
                
                UPDATE dbo.RefreshToken
                SET FechaRevocacion = @Ahora
                WHERE IDRefreshToken = @IDAnterior;
                
                INSERT INTO dbo.RefreshToken (
                    IDUsuario,
                    TokenHash,
                    IDFamilia,
                    IDTokenAnterior,
                    FechaCreacion,
                    FechaExpiracion
                )
                VALUES                       (@IDUsuario, @TokenHashNuevo, @IDFamilia, @IDAnterior, @Ahora, @Expiracion);
                
                SET @IDNuevo = CONVERT (BIGINT, SCOPE_IDENTITY());
            END
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
    
    -- Fuera de la transacción para conservar la revocación.
    IF @Reutilizado = 1
        THROW 51024, N'Reutilizacion de token detectada.', 1;
    
    SELECT u.IDUsuario,
           u.Correo,
           u.Nombre,
           r.Codigo AS Rol,
           rt.FechaExpiracion
    FROM dbo.RefreshToken AS rt
         INNER JOIN
         dbo.Usuario AS u
         ON u.IDUsuario = rt.IDUsuario
         INNER JOIN
         dbo.Rol AS r
         ON r.IDRol = u.IDRol
    WHERE rt.IDRefreshToken = @IDNuevo;
END
