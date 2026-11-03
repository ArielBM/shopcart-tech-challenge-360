/*
 ShopCart | 016_SP_Bitacora.sql
 Crea: SP_Bitacora_Consultar.
 Consulta paginada consistente de auditoría,
 con filtro opcional por módulo.
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
    
    -- Fijar el conjunto de registros de esta consulta.
    -- No se copian los snapshots JSON a la tabla temporal.
    CREATE TABLE #BitacoraFiltrada (
        IDBitacora  BIGINT       NOT NULL PRIMARY KEY,
        FechaAccion DATETIME2(3) NOT NULL
    );
    
    INSERT INTO #BitacoraFiltrada (
        IDBitacora,
        FechaAccion
    )
    SELECT IDBitacora,
           FechaAccion
    FROM dbo.Bitacora
    WHERE @Modulo IS NULL
          OR Modulo = @Modulo;
    
    -- Total y página provienen del mismo conjunto fijo.
    SELECT @TotalRegistros = COUNT_BIG(*)
    FROM #BitacoraFiltrada;
    
    SELECT b.IDBitacora,
           b.IDUsuario,
           b.Modulo,
           b.Entidad,
           b.IDEntidad,
           b.Accion,
           b.ValorAnterior,
           b.ValorNuevo,
           b.FechaAccion
    FROM #BitacoraFiltrada AS f
         INNER JOIN
         dbo.Bitacora AS b
         ON b.IDBitacora = f.IDBitacora
    ORDER BY f.FechaAccion DESC, f.IDBitacora DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END