/* ShopCart | 006_SP_Autenticacion.sql
 Crea: SP_Auth_RegistrarCliente y SP_Auth_ObtenerUsuarioPorCorreo.
 */
USE ShopCartDB;


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
