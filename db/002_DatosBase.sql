/* ShopCart | 002_DatosBase.sql | Ejecutar tras 001 */
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'CLIENTE')
     INSERT dbo.Rol(Codigo,Nombre) VALUES ('CLIENTE', N'Cliente');
 IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'OPERADOR')
     INSERT dbo.Rol(Codigo,Nombre) VALUES ('OPERADOR', N'Operador');
 IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'ADMINISTRADOR')
     INSERT dbo.Rol(Codigo,Nombre) VALUES ('ADMINISTRADOR', N'Administrador');
 IF NOT EXISTS (SELECT 1 FROM dbo.Ubicacion WHERE Codigo = N'BOD-CENTRAL')
     INSERT dbo.Ubicacion(Codigo,Nombre,Tipo) VALUES (N'BOD-CENTRAL',N'Bodega Central','BODEGA');
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
