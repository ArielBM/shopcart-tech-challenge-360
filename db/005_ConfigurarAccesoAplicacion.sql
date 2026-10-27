USE master;


GO
CREATE LOGIN shopcart_app
    WITH PASSWORD = 'REEMPLAZAR_POR_CONTRASENA_SEGURA', CHECK_POLICY = ON;


GO
USE ShopCartDB;


GO
CREATE USER shopcart_app FOR LOGIN shopcart_app;


GO
GRANT EXECUTE
    ON SCHEMA::dbo TO shopcart_app;