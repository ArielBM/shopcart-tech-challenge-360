/* ShopCart | 006_SP_Autenticacion.sql
 Crea: SP_Auth_RegistrarCliente.
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

    DECLARE @IDRol INT;

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
