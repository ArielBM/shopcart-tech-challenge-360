/*
 ShopCart | 016_SP_Bitacora.sql
 Crea: SP_Bitacora_Consultar.
 Consulta paginada de auditoria, con filtro por modulo.
*/
USE ShopCartDB;


GO

CREATE OR ALTER PROCEDURE dbo.SP_Bitacora_Consultar
    @Modulo VARCHAR(30)=NULL,
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
        THROW 52000, N'La paginacion no es valida.', 1;
    
    SET @Modulo = NULLIF (LTRIM(RTRIM(@Modulo)), '');
    
    DECLARE @Offset AS BIGINT = (CONVERT (BIGINT, @Pagina) - 1) * @TamanoPagina;
    
    SELECT @TotalRegistros = COUNT_BIG(*)
    FROM dbo.Bitacora
    WHERE @Modulo IS NULL
          OR Modulo = @Modulo;
    
    SELECT IDBitacora,
           IDUsuario,
           Modulo,
           Entidad,
           IDEntidad,
           Accion,
           ValorAnterior,
           ValorNuevo,
           FechaAccion
    FROM dbo.Bitacora
    WHERE @Modulo IS NULL
          OR Modulo = @Modulo
    ORDER BY FechaAccion DESC, IDBitacora DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END