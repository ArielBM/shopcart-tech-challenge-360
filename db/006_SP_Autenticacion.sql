/* ShopCart | 006_SP_Autenticacion.sql
 Crea:
 - SP_Auth_RegistrarCliente
 - SP_Auth_ObtenerUsuarioPorCorreo
 - SP_Auth_CrearSesion
 - SP_Auth_RotarSesion
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
           r.Codigo AS Rol,
           u.VersionSeguridad
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
    
    SET XACT_ABORT ON;
    
    IF @TokenHash IS NULL
       OR DATALENGTH(@TokenHash) <> 32
        THROW 51021, N'El hash del token debe contener exactamente 32 bytes.', 1;
    
    IF @IDUsuario IS NULL
       OR @IDUsuario <= 0
        THROW 51020, N'No se puede crear la sesión.', 1;
    
    DECLARE @RecursoUsuario AS NVARCHAR(255) = N'ShopCart:Usuario:' + CONVERT (NVARCHAR(20), @IDUsuario);
    
    DECLARE @ResultadoBloqueo AS INT;
    
    DECLARE @Activo AS BIT;
    
    DECLARE @VersionSeguridad AS INT;
    
    DECLARE @Ahora AS DATETIME2(3);
    
    DECLARE @SesionCreada TABLE (
        IDRefreshToken  BIGINT          ,
        IDFamilia       UNIQUEIDENTIFIER,
        FechaExpiracion DATETIME2(3)    );
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Mismo bloqueo utilizado por CambiarEstado.
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @RecursoUsuario, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51026, N'No se pudo bloquear el usuario.', 1;
        
        -- La versión se obtiene al crear la sesión,
        -- no antes de verificar la contraseña con Argon2.
        SELECT @Activo = Activo,
               @VersionSeguridad = VersionSeguridad
        FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
        WHERE IDUsuario = @IDUsuario;
        
        IF @Activo IS NULL
           OR @Activo = 0
            THROW 51020, N'No se puede crear la sesión.', 1;
        
        SET @Ahora = SYSUTCDATETIME();
        
        INSERT INTO dbo.RefreshToken (
            IDUsuario,
            TokenHash,
            IDFamilia,
            FechaCreacion,
            FechaExpiracion
        )
        OUTPUT INSERTED.IDRefreshToken, INSERTED.IDFamilia, INSERTED.FechaExpiracion INTO @SesionCreada
        VALUES                       (@IDUsuario, @TokenHash, NEWID(), @Ahora, DATEADD(DAY, 7, @Ahora));
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
    
    SELECT IDRefreshToken,
           IDFamilia,
           FechaExpiracion,
           @VersionSeguridad AS VersionSeguridad
    FROM @SesionCreada;
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
    
    DECLARE @IDUsuario AS INT;
    
    DECLARE @IDFamilia AS UNIQUEIDENTIFIER;
    
    DECLARE @RecursoUsuario AS NVARCHAR(255);
    
    DECLARE @RecursoFamilia AS NVARCHAR(255);
    
    DECLARE @ResultadoBloqueo AS INT;
    
    DECLARE @IDAnterior AS BIGINT;
    
    DECLARE @IDNuevo AS BIGINT;
    
    DECLARE @Expiracion AS DATETIME2(3);
    
    DECLARE @Revocacion AS DATETIME2(3);
    
    DECLARE @Activo AS BIT;
    
    DECLARE @VersionSeguridad AS INT;
    
    DECLARE @Reutilizado AS BIT = 0;
    
    DECLARE @Ahora AS DATETIME2(3);
    
    -- Identificar usuario y familia sin conservar bloqueos.
    -- Estos identificadores son inmutables en RefreshToken.
    SELECT @IDUsuario = IDUsuario,
           @IDFamilia = IDFamilia
    FROM dbo.RefreshToken
    WHERE TokenHash = @TokenHashActual;
    
    IF @IDUsuario IS NULL
       OR @IDFamilia IS NULL
        THROW 51022, N'Token desconocido.', 1;
    
    SET @RecursoUsuario = N'ShopCart:Usuario:' + CONVERT (NVARCHAR(20), @IDUsuario);
    
    SET @RecursoFamilia = N'ShopCart:Refresh:' + CONVERT (NVARCHAR(36), @IDFamilia);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 1. Bloquear primero al usuario.
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @RecursoUsuario, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51026, N'No se pudo bloquear el usuario.', 1;
        
        -- 2. Leer y bloquear el estado vigente del usuario.
        SELECT @Activo = Activo,
               @VersionSeguridad = VersionSeguridad
        FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
        WHERE IDUsuario = @IDUsuario;
        
        IF @Activo IS NULL
           OR @Activo = 0
            THROW 51023, N'Sesion no vigente.', 1;
        
        -- 3. Bloquear la familia después del usuario.
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @RecursoFamilia, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51026, N'No se pudo bloquear la sesión.', 1;
        
        -- 4. Consultar el token bajo bloqueo.
        SELECT @IDAnterior = IDRefreshToken,
               @Expiracion = FechaExpiracion,
               @Revocacion = FechaRevocacion
        FROM dbo.RefreshToken WITH (UPDLOCK, HOLDLOCK)
        WHERE TokenHash = @TokenHashActual
              AND IDFamilia = @IDFamilia
              AND IDUsuario = @IDUsuario;
        
        SET @Ahora = SYSUTCDATETIME();
        
        IF @IDAnterior IS NULL
            THROW 51022, N'Token desconocido.', 1;
        
        IF @Revocacion IS NOT NULL
            BEGIN
                -- Reutilización: revocar la familia completa.
                UPDATE dbo.RefreshToken
                SET FechaRevocacion = @Ahora
                WHERE IDFamilia = @IDFamilia
                      AND FechaRevocacion IS NULL;
                
                SET @Reutilizado = 1;
            END
        ELSE
            BEGIN
                IF @Expiracion <= @Ahora
                    THROW 51023, N'Sesion no vigente.', 1;
                
                -- Consumir el token anterior.
                UPDATE dbo.RefreshToken
                SET FechaRevocacion = @Ahora
                WHERE IDRefreshToken = @IDAnterior;
                
                -- Mantener la familia y la expiración absoluta.
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
           rt.FechaExpiracion,
           @VersionSeguridad AS VersionSeguridad
    FROM dbo.RefreshToken AS rt
         INNER JOIN
         dbo.Usuario AS u
         ON u.IDUsuario = rt.IDUsuario
         INNER JOIN
         dbo.Rol AS r
         ON r.IDRol = u.IDRol
    WHERE rt.IDRefreshToken = @IDNuevo;
END


GO

CREATE OR ALTER PROCEDURE dbo.SP_Auth_RevocarSesion
    @TokenHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @TokenHash IS NULL
       OR DATALENGTH(@TokenHash) <> 32
        THROW 51021, N'Hash de token inválido.', 1;
    
    DECLARE @IDFamilia AS UNIQUEIDENTIFIER;
    
    DECLARE @Recurso AS NVARCHAR(255);
    
    DECLARE @ResultadoBloqueo AS INT;
    
    SELECT @IDFamilia = IDFamilia
    FROM dbo.RefreshToken
    WHERE TokenHash = @TokenHash;
    
    -- Logout repetido o token desconocido: no hay nada que revocar.
    IF @IDFamilia IS NULL
        RETURN;
    
    SET @Recurso = N'ShopCart:Refresh:' + CONVERT (NVARCHAR(36), @IDFamilia);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        EXECUTE @ResultadoBloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        
        IF @ResultadoBloqueo < 0
            THROW 51026, N'No se pudo bloquear la sesión.', 1;
        
        UPDATE dbo.RefreshToken
        SET FechaRevocacion = SYSUTCDATETIME()
        WHERE IDFamilia = @IDFamilia
              AND FechaRevocacion IS NULL;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
END