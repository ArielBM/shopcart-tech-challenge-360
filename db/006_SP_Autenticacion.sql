/* ShopCart | 006_SP_Autenticacion.sql
 Crea:
 - SP_Auth_RegistrarCliente
 - SP_Auth_ObtenerUsuarioPorCorreo
 - SP_Auth_CrearSesion
 - SP_Auth_RotarSesion
 - SP_Auth_RevocarSesion
 - SP_Auth_ObtenerSesionActiva
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

    IF @TokenHashActual IS NULL OR DATALENGTH(@TokenHashActual) <> 32
       OR @TokenHashNuevo IS NULL OR DATALENGTH(@TokenHashNuevo) <> 32
        THROW 51021, N'Los hashes deben contener exactamente 32 bytes.', 1;

    IF @TokenHashActual = @TokenHashNuevo
        THROW 51025, N'El nuevo token debe ser diferente.', 1;

    DECLARE @IDFamilia UNIQUEIDENTIFIER;
    -- Solo descubrir la familia. No retener bloqueos de filas antes del applock.
    SELECT @IDFamilia = IDFamilia
    FROM dbo.RefreshToken
    WHERE TokenHash = @TokenHashActual;

    IF @IDFamilia IS NULL
        THROW 51022, N'Sesión no válida.', 1;

    DECLARE @Recurso NVARCHAR(255) = N'ShopCart:Refresh:' + CONVERT(NVARCHAR(36), @IDFamilia);
    DECLARE @Bloqueo INT, @ErrorSesion INT;
    DECLARE @IDAnterior BIGINT, @IDUsuario INT;
    DECLARE @Expiracion DATETIME2(3), @Revocacion DATETIME2(3), @Ahora DATETIME2(3);
    DECLARE @Activo BIT, @Correo NVARCHAR(254), @Nombre NVARCHAR(150), @Rol VARCHAR(20);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Rotación, replay y logout usan el mismo bloqueo exclusivo por familia.
        EXEC @Bloqueo = sys.sp_getapplock
            @Resource = @Recurso, @LockMode = 'Exclusive',
            @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @Bloqueo < 0
            THROW 51026, N'No se pudo bloquear la sesión.', 1;

        SELECT @IDAnterior = rt.IDRefreshToken,
               @IDUsuario = u.IDUsuario,
               @Expiracion = rt.FechaExpiracion,
               @Revocacion = rt.FechaRevocacion,
               @Activo = u.Activo,
               @Correo = u.Correo,
               @Nombre = u.Nombre,
               @Rol = r.Codigo
        FROM dbo.RefreshToken AS rt
        INNER JOIN dbo.Usuario AS u WITH (HOLDLOCK) ON u.IDUsuario = rt.IDUsuario
        INNER JOIN dbo.Rol AS r ON r.IDRol = u.IDRol
        WHERE rt.TokenHash = @TokenHashActual AND rt.IDFamilia = @IDFamilia;

        SET @Ahora = SYSUTCDATETIME();
        IF @IDAnterior IS NULL
            THROW 51022, N'Sesión no válida.', 1;

        IF @Revocacion IS NOT NULL
            SET @ErrorSesion = 51024;
        ELSE IF @Expiracion <= @Ahora OR @Activo = 0
            SET @ErrorSesion = 51023;

        IF @ErrorSesion IS NOT NULL
        BEGIN
            UPDATE dbo.RefreshToken
            SET FechaRevocacion = @Ahora
            WHERE IDFamilia = @IDFamilia AND FechaRevocacion IS NULL;
        END
        ELSE
        BEGIN
            UPDATE dbo.RefreshToken
            SET FechaRevocacion = @Ahora
            WHERE IDRefreshToken = @IDAnterior;

            INSERT INTO dbo.RefreshToken (
                IDUsuario, TokenHash, IDFamilia, IDTokenAnterior,
                FechaCreacion, FechaExpiracion
            )
            VALUES (
                @IDUsuario, @TokenHashNuevo, @IDFamilia, @IDAnterior,
                @Ahora, @Expiracion
            );
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    -- El error se lanza después del COMMIT para conservar la revocación.
    IF @ErrorSesion = 51024
        THROW 51024, N'Sesión no válida.', 1;
    IF @ErrorSesion = 51023
        THROW 51023, N'Sesión no vigente.', 1;

    -- Devolver la instantánea validada, sin releer fuera del bloqueo.
    SELECT @IDUsuario AS IDUsuario, @IDFamilia AS IDFamilia, @Correo AS Correo, @Nombre AS Nombre,
           @Rol AS Rol, @Expiracion AS FechaExpiracion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Auth_RevocarSesion
    @TokenHash VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @TokenHash IS NULL OR DATALENGTH(@TokenHash) <> 32
        THROW 51021, N'El hash debe contener exactamente 32 bytes.', 1;

    DECLARE @IDFamilia UNIQUEIDENTIFIER;
    SELECT @IDFamilia = IDFamilia FROM dbo.RefreshToken WHERE TokenHash = @TokenHash;
    -- Logout idempotente, incluso con un token desconocido.
    IF @IDFamilia IS NULL RETURN;

    DECLARE @Recurso NVARCHAR(255) = N'ShopCart:Refresh:' + CONVERT(NVARCHAR(36), @IDFamilia);
    DECLARE @Bloqueo INT;

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @Bloqueo = sys.sp_getapplock
            @Resource = @Recurso, @LockMode = 'Exclusive',
            @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @Bloqueo < 0
            THROW 51026, N'No se pudo bloquear la sesión.', 1;

        DECLARE @Ahora DATETIME2(3) = SYSUTCDATETIME();
        UPDATE dbo.RefreshToken
        SET FechaRevocacion = @Ahora
        WHERE IDFamilia = @IDFamilia AND FechaRevocacion IS NULL;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Auth_ObtenerSesionActiva
    @IDUsuario INT,
    @IDFamilia UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IDUsuario, r.Codigo AS Rol
    FROM dbo.Usuario AS u
    INNER JOIN dbo.Rol AS r ON r.IDRol = u.IDRol
    WHERE u.IDUsuario = @IDUsuario AND u.Activo = 1
      AND EXISTS (
          SELECT 1 FROM dbo.RefreshToken AS rt
          WHERE rt.IDUsuario = u.IDUsuario AND rt.IDFamilia = @IDFamilia
            AND rt.FechaRevocacion IS NULL AND rt.FechaExpiracion > SYSUTCDATETIME()
      );
END;
