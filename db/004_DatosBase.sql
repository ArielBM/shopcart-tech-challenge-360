/* ShopCart | 004_DatosBase.sql
   Inserta: Rol (3), Ubicacion (1), EstadoPedido (7),
            TransicionEstadoPedido (7).
*/
USE ShopCartDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Roles del sistema.
    IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'CLIENTE')
        INSERT INTO dbo.Rol (Codigo, Nombre) VALUES ('CLIENTE', N'Cliente');
    IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'OPERADOR')
        INSERT INTO dbo.Rol (Codigo, Nombre) VALUES ('OPERADOR', N'Operador');
    IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'ADMINISTRADOR')
        INSERT INTO dbo.Rol (Codigo, Nombre) VALUES ('ADMINISTRADOR', N'Administrador');

    -- Bodega inicial del ecommerce.
    IF NOT EXISTS (SELECT 1 FROM dbo.Ubicacion WHERE Codigo = N'BOD-CENTRAL')
        INSERT INTO dbo.Ubicacion (Codigo, Nombre, Tipo)
        VALUES (N'BOD-CENTRAL', N'Bodega Central', 'BODEGA');

    -- Estados del pedido.
    INSERT INTO dbo.EstadoPedido (Codigo, Nombre)
    SELECT s.Codigo, s.Nombre
    FROM (VALUES
        ('PENDIENTE_PAGO', N'Pendiente de pago'),
        ('EXPIRADO', N'Expirado'),
        ('PAGADO', N'Pagado'),
        ('EN_PREPARACION', N'En preparacion'),
        ('DESPACHADO', N'Despachado'),
        ('ENTREGADO', N'Entregado'),
        ('CANCELADO', N'Cancelado')
    ) AS s(Codigo, Nombre)
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.EstadoPedido AS e WHERE e.Codigo = s.Codigo
    );

    -- Transiciones permitidas del pedido.
    INSERT INTO dbo.TransicionEstadoPedido (IDEstadoOrigen, IDEstadoDestino)
    SELECT origen.IDEstadoPedido, destino.IDEstadoPedido
    FROM (VALUES
        ('PENDIENTE_PAGO', 'PAGADO'),
        ('PENDIENTE_PAGO', 'EXPIRADO'),
        ('PAGADO', 'EN_PREPARACION'),
        ('PAGADO', 'CANCELADO'),
        ('EN_PREPARACION', 'DESPACHADO'),
        ('EN_PREPARACION', 'CANCELADO'),
        ('DESPACHADO', 'ENTREGADO')
    ) AS t(Origen, Destino)
    INNER JOIN dbo.EstadoPedido AS origen ON origen.Codigo = t.Origen
    INNER JOIN dbo.EstadoPedido AS destino ON destino.Codigo = t.Destino
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.TransicionEstadoPedido AS existente
        WHERE existente.IDEstadoOrigen = origen.IDEstadoPedido
          AND existente.IDEstadoDestino = destino.IDEstadoPedido
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
