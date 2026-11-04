/*
 ShopCart | 017_SP_Usuarios.sql
 Crea:
 - SP_Auth_ValidarUsuarioActivo
 - SP_Usuarios_Consultar
 - SP_Usuarios_CambiarEstado
*/
USE ShopCartDB;


GO

-- Consulta utilizada por el middleware de autenticación.
CREATE OR ALTER PROCEDURE dbo.SP_Auth_ValidarUsuarioActivo
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT u.IDUsuario,
           u.Activo,
           r.Codigo AS Rol,
           u.VersionSeguridad
    FROM dbo.Usuario AS u
         INNER JOIN
         dbo.Rol AS r
         ON r.IDRol = u.IDRol
    WHERE u.IDUsuario = @IDUsuario;
END


GO

-- Listado administrativo con filtros y paginación.
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_Consultar
    @Buscar NVARCHAR(150)=NULL,
    @Estado VARCHAR(10)='TODOS',
    @Pagina INT=1,
    @TamanoPagina INT=20,
    @TotalRegistros BIGINT=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @Pagina IS NULL
       OR @Pagina < 1
       OR @TamanoPagina IS NULL
       OR @TamanoPagina NOT BETWEEN 1 AND 100
        THROW 52100, N'La paginacion no es valida.', 1;
    
    IF @Estado IS NULL
       OR @Estado NOT IN ('TODOS', 'ACTIVO', 'INACTIVO')
        THROW 52101, N'El filtro de estado no es valido.', 1;
    
    SET @Buscar = NULLIF (LTRIM(RTRIM(@Buscar)), N'');
    
    DECLARE @Offset AS BIGINT = (CONVERT (BIGINT, @Pagina) - 1) * @TamanoPagina;
    
    -- Un único conjunto para el total y la página.
    SELECT u.IDUsuario,
           u.Correo,
           u.Nombre,
           r.Codigo AS Rol,
           u.Activo,
           u.FechaCreacion,
           u.FechaActualizacion
    INTO #UsuariosFiltrados
    FROM dbo.Usuario AS u
         INNER JOIN
         dbo.Rol AS r
         ON r.IDRol = u.IDRol
    WHERE (@Buscar IS NULL
           OR CHARINDEX(@Buscar, u.Nombre COLLATE Latin1_General_100_CI_AI) > 0
           OR CHARINDEX(@Buscar, u.Correo) > 0)
          AND (@Estado = 'TODOS'
               OR (@Estado = 'ACTIVO'
                   AND u.Activo = 1)
               OR (@Estado = 'INACTIVO'
                   AND u.Activo = 0));
    
    SELECT @TotalRegistros = COUNT_BIG(*)
    FROM #UsuariosFiltrados;
    
    SELECT IDUsuario,
           Correo,
           Nombre,
           Rol,
           Activo,
           FechaCreacion,
           FechaActualizacion
    FROM #UsuariosFiltrados
    ORDER BY Nombre ASC, IDUsuario ASC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END


GO

-- Cambio administrativo de estado con revocación y auditoría.
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_CambiarEstado
    @IDUsuario INT,
    @Activo BIT,
    @IDAdministrador INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET XACT_ABORT ON;
    
    IF @IDUsuario IS NULL
       OR @IDUsuario <= 0
       OR @IDAdministrador IS NULL
       OR @IDAdministrador <= 0
       OR @Activo IS NULL
        THROW 52102, N'Los parametros no son validos.', 1;
    
    DECLARE @EstadoAnterior AS BIT;
    
    DECLARE @Ahora AS DATETIME2(3);
    
    DECLARE @Accion AS VARCHAR(30);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Defensa adicional al middleware administrativo.
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Usuario AS u
                            INNER JOIN
                            dbo.Rol AS r
                            ON r.IDRol = u.IDRol
                       WHERE u.IDUsuario = @IDAdministrador
                             AND u.Activo = 1
                             AND r.Codigo = 'ADMINISTRADOR')
            THROW 52103, N'Administrador no autorizado.', 1;
        
        -- No permitir la autodesactivación.
        IF @IDUsuario = @IDAdministrador
           AND @Activo = 0
            THROW 52104, N'No puedes desactivar tu propia cuenta.', 1;
        
        SELECT @EstadoAnterior = Activo
        FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
        WHERE IDUsuario = @IDUsuario;
        
        IF @EstadoAnterior IS NULL
            THROW 52105, N'El usuario no existe.', 1;
        
        -- Solicitar el estado actual no genera cambios ni auditoría.
        IF @EstadoAnterior <> @Activo
            BEGIN
                SET @Ahora = SYSUTCDATETIME();
                
                -- Evitar desbordamiento del contador.
                IF @Activo = 0
                   AND EXISTS (SELECT 1
                               FROM dbo.Usuario
                               WHERE IDUsuario = @IDUsuario
                                     AND VersionSeguridad = 2147483647)
                    THROW 52112, N'La versión de seguridad alcanzó su límite.', 1;
                
                UPDATE dbo.Usuario
                SET Activo             = @Activo,
                    FechaActualizacion = @Ahora,
                    VersionSeguridad   = CASE WHEN @Activo = 0 THEN VersionSeguridad + 1 ELSE VersionSeguridad END
                WHERE IDUsuario = @IDUsuario;
                
                -- Al desactivar se revocan todos los refresh tokens
                -- vigentes, independientemente de su familia.
                IF @Activo = 0
                    BEGIN
                        UPDATE dbo.RefreshToken
                        SET FechaRevocacion = @Ahora
                        WHERE IDUsuario = @IDUsuario
                              AND FechaRevocacion IS NULL;
                    END
                
                SET @Accion = CASE WHEN @Activo = 1 THEN 'ACTIVAR' ELSE 'DESACTIVAR' END;
                
                INSERT INTO dbo.Bitacora (
                    IDUsuario,
                    Modulo,
                    Entidad,
                    IDEntidad,
                    Accion,
                    ValorAnterior,
                    ValorNuevo,
                    FechaAccion
                )
                VALUES                   (@IDAdministrador, 'USUARIOS', 'Usuario', @IDUsuario, @Accion, CONCAT(N'{"activo":', CONVERT (INT, @EstadoAnterior), N'}'), CONCAT(N'{"activo":', CONVERT (INT, @Activo), N'}'), @Ahora);
            END
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        THROW;
    END CATCH
    
    SELECT u.IDUsuario,
           u.Correo,
           u.Nombre,
           r.Codigo AS Rol,
           u.Activo,
           u.FechaActualizacion
    FROM dbo.Usuario AS u
         INNER JOIN
         dbo.Rol AS r
         ON r.IDRol = u.IDRol
    WHERE u.IDUsuario = @IDUsuario;
END