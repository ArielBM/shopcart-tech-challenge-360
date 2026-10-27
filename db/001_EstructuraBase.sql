/* ShopCart | 001_EstructuraBase.sql
   Base de datos: ShopCartDB.
   Crea: Rol, Usuario, Categoria, Producto, Variante,
         Atributo, ValorAtributo, VarianteAtributo, ImagenProducto,
         Ubicacion, InventarioPorUbicacion.
   Define: PK, DEFAULT, UNIQUE, CHECK, FK e indices de consulta.
*/
-- Crear la base de datos solo si no existe.
IF DB_ID(N'ShopCartDB') IS NULL
    EXEC(N'CREATE DATABASE ShopCartDB');
GO

-- Seleccionar explicitamente la base de datos de ShopCart.
USE ShopCartDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Rol', N'U') IS NOT NULL
    THROW 51001, N'La migracion 001 ya parece aplicada: dbo.Rol existe.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- 1. Rol | Identifica los perfiles permitidos.
    CREATE TABLE dbo.Rol (
        IDRol INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Rol PRIMARY KEY,
        Codigo VARCHAR(20) NOT NULL,
        Nombre NVARCHAR(60) NOT NULL
    );
    -- Un codigo por rol.
    ALTER TABLE dbo.Rol ADD CONSTRAINT UQ_Rol_Codigo UNIQUE (Codigo);

    -- 2. Usuario | Cuentas y datos de acceso.
    CREATE TABLE dbo.Usuario (
        IDUsuario INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuario PRIMARY KEY,
        IDRol INT NOT NULL,
        Correo NVARCHAR(254) COLLATE Latin1_General_100_CI_AS NOT NULL,
        HashContrasena NVARCHAR(255) NOT NULL,
        Nombre NVARCHAR(150) NOT NULL,
        Activo BIT NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaActualizacion DATETIME2(3) NOT NULL
    );
    -- Cuenta activa y fechas UTC por defecto.
    ALTER TABLE dbo.Usuario ADD CONSTRAINT DF_Usuario_Activo DEFAULT (1) FOR Activo;
    ALTER TABLE dbo.Usuario ADD CONSTRAINT DF_Usuario_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.Usuario ADD CONSTRAINT DF_Usuario_FechaActualizacion DEFAULT (SYSUTCDATETIME()) FOR FechaActualizacion;
    -- El correo no puede estar vacio.
    ALTER TABLE dbo.Usuario ADD CONSTRAINT CK_Usuario_CorreoNoVacio CHECK (LEN(LTRIM(RTRIM(Correo))) > 0);
    -- El rol debe existir.
    ALTER TABLE dbo.Usuario ADD CONSTRAINT FK_Usuario_Rol FOREIGN KEY (IDRol) REFERENCES dbo.Rol (IDRol);
    -- Busqueda unica por correo.
    CREATE UNIQUE INDEX UX_Usuario_Correo ON dbo.Usuario (Correo);

    -- 3. Categoria | Clasificacion del catalogo.
    CREATE TABLE dbo.Categoria (
        IDCategoria INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Categoria PRIMARY KEY,
        Nombre NVARCHAR(120) NOT NULL,
        Descripcion NVARCHAR(500) NULL,
        Activa BIT NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL
    );
    -- Categoria activa y fecha UTC por defecto.
    ALTER TABLE dbo.Categoria ADD CONSTRAINT DF_Categoria_Activa DEFAULT (1) FOR Activa;
    ALTER TABLE dbo.Categoria ADD CONSTRAINT DF_Categoria_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    -- Exige nombre no vacio.
    ALTER TABLE dbo.Categoria ADD CONSTRAINT CK_Categoria_NombreNoVacio CHECK (LEN(LTRIM(RTRIM(Nombre))) > 0);

    -- 4. Producto | Ficha comercial y categoria.
    CREATE TABLE dbo.Producto (
        IDProducto INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Producto PRIMARY KEY,
        IDCategoria INT NOT NULL,
        Nombre NVARCHAR(200) NOT NULL,
        Descripcion NVARCHAR(MAX) NULL,
        Activo BIT NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaActualizacion DATETIME2(3) NOT NULL
    );
    -- Producto activo y fechas UTC por defecto.
    ALTER TABLE dbo.Producto ADD CONSTRAINT DF_Producto_Activo DEFAULT (1) FOR Activo;
    ALTER TABLE dbo.Producto ADD CONSTRAINT DF_Producto_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.Producto ADD CONSTRAINT DF_Producto_FechaActualizacion DEFAULT (SYSUTCDATETIME()) FOR FechaActualizacion;
    -- Exige nombre no vacio.
    ALTER TABLE dbo.Producto ADD CONSTRAINT CK_Producto_NombreNoVacio CHECK (LEN(LTRIM(RTRIM(Nombre))) > 0);
    -- La categoria debe existir.
    ALTER TABLE dbo.Producto ADD CONSTRAINT FK_Producto_Categoria FOREIGN KEY (IDCategoria) REFERENCES dbo.Categoria (IDCategoria);
    -- Filtrado por categoria y estado.
    CREATE INDEX IX_Producto_Categoria_Activo ON dbo.Producto (IDCategoria, Activo, IDProducto);

    -- 5. Variante | SKU vendible con precio propio.
    CREATE TABLE dbo.Variante (
        IDVariante INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Variante PRIMARY KEY,
        IDProducto INT NOT NULL,
        SKU NVARCHAR(64) NOT NULL,
        PrecioActual DECIMAL(18,2) NOT NULL,
        Activa BIT NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL,
        FechaActualizacion DATETIME2(3) NOT NULL
    );
    -- Variante activa y fechas UTC por defecto.
    ALTER TABLE dbo.Variante ADD CONSTRAINT DF_Variante_Activa DEFAULT (1) FOR Activa;
    ALTER TABLE dbo.Variante ADD CONSTRAINT DF_Variante_FechaCreacion DEFAULT (SYSUTCDATETIME()) FOR FechaCreacion;
    ALTER TABLE dbo.Variante ADD CONSTRAINT DF_Variante_FechaActualizacion DEFAULT (SYSUTCDATETIME()) FOR FechaActualizacion;
    -- No permite SKU repetidos.
    ALTER TABLE dbo.Variante ADD CONSTRAINT UQ_Variante_SKU UNIQUE (SKU);
    -- Precio no negativo y SKU no vacio.
    ALTER TABLE dbo.Variante ADD CONSTRAINT CK_Variante_PrecioNoNegativo CHECK (PrecioActual >= 0);
    ALTER TABLE dbo.Variante ADD CONSTRAINT CK_Variante_SKUNoVacio CHECK (LEN(LTRIM(RTRIM(SKU))) > 0);
    -- El producto debe existir.
    ALTER TABLE dbo.Variante ADD CONSTRAINT FK_Variante_Producto FOREIGN KEY (IDProducto) REFERENCES dbo.Producto (IDProducto);
    -- Filtrado por producto y estado.
    CREATE INDEX IX_Variante_Producto_Activa ON dbo.Variante (IDProducto, Activa);

    -- 6. Atributo | Evita atributos repetidos.
    CREATE TABLE dbo.Atributo (
        IDAtributo INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Atributo PRIMARY KEY,
        Nombre NVARCHAR(80) NOT NULL
    );
    -- Un nombre por atributo.
    ALTER TABLE dbo.Atributo ADD CONSTRAINT UQ_Atributo_Nombre UNIQUE (Nombre);

    -- 7. ValorAtributo | Evita valores repetidos y valida su atributo.
    CREATE TABLE dbo.ValorAtributo (
        IDValorAtributo INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ValorAtributo PRIMARY KEY,
        IDAtributo INT NOT NULL,
        Valor NVARCHAR(100) NOT NULL
    );
    -- No repite valores dentro de un atributo.
    ALTER TABLE dbo.ValorAtributo ADD CONSTRAINT UQ_ValorAtributo_Atributo_Valor UNIQUE (IDAtributo, Valor);
    ALTER TABLE dbo.ValorAtributo ADD CONSTRAINT UQ_ValorAtributo_ID_Atributo UNIQUE (IDValorAtributo, IDAtributo);
    -- Cada valor pertenece a un atributo.
    ALTER TABLE dbo.ValorAtributo ADD CONSTRAINT FK_ValorAtributo_Atributo FOREIGN KEY (IDAtributo) REFERENCES dbo.Atributo (IDAtributo);

    -- 8. VarianteAtributo | Garantiza coherencia entre atributo y valor.
    CREATE TABLE dbo.VarianteAtributo (
        IDVariante INT NOT NULL,
        IDAtributo INT NOT NULL,
        IDValorAtributo INT NOT NULL,
        CONSTRAINT PK_VarianteAtributo PRIMARY KEY (IDVariante, IDAtributo)
    );
    -- El valor debe corresponder al atributo seleccionado.
    ALTER TABLE dbo.VarianteAtributo ADD CONSTRAINT FK_VarianteAtributo_Variante FOREIGN KEY (IDVariante) REFERENCES dbo.Variante (IDVariante);
    ALTER TABLE dbo.VarianteAtributo ADD CONSTRAINT FK_VarianteAtributo_ValorAtributo FOREIGN KEY (IDValorAtributo, IDAtributo) REFERENCES dbo.ValorAtributo (IDValorAtributo, IDAtributo);

    -- 9. ImagenProducto | Controla el orden de las imágenes por producto.
    CREATE TABLE dbo.ImagenProducto (
        IDImagenProducto INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImagenProducto PRIMARY KEY,
        IDProducto INT NOT NULL,
        UrlImagen NVARCHAR(1000) NOT NULL,
        Orden INT NOT NULL
    );
    -- Orden cero por defecto.
    ALTER TABLE dbo.ImagenProducto ADD CONSTRAINT DF_ImagenProducto_Orden DEFAULT (0) FOR Orden;
    -- Un orden por imagen dentro del producto.
    ALTER TABLE dbo.ImagenProducto ADD CONSTRAINT UQ_ImagenProducto_Producto_Orden UNIQUE (IDProducto, Orden);
    -- El orden no puede ser negativo.
    ALTER TABLE dbo.ImagenProducto ADD CONSTRAINT CK_ImagenProducto_Orden CHECK (Orden >= 0);
    -- La imagen pertenece a un producto.
    ALTER TABLE dbo.ImagenProducto ADD CONSTRAINT FK_ImagenProducto_Producto FOREIGN KEY (IDProducto) REFERENCES dbo.Producto (IDProducto);

    -- 10. Ubicacion | Limita ubicaciones a tienda o bodega.
    CREATE TABLE dbo.Ubicacion (
        IDUbicacion INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ubicacion PRIMARY KEY,
        Codigo NVARCHAR(30) NOT NULL,
        Nombre NVARCHAR(120) NOT NULL,
        Tipo VARCHAR(15) NOT NULL,
        Activa BIT NOT NULL
    );
    -- Ubicacion activa por defecto.
    ALTER TABLE dbo.Ubicacion ADD CONSTRAINT DF_Ubicacion_Activa DEFAULT (1) FOR Activa;
    -- Codigo unico por ubicacion.
    ALTER TABLE dbo.Ubicacion ADD CONSTRAINT UQ_Ubicacion_Codigo UNIQUE (Codigo);
    -- Solo bodega o tienda.
    ALTER TABLE dbo.Ubicacion ADD CONSTRAINT CK_Ubicacion_Tipo CHECK (Tipo IN ('BODEGA','TIENDA'));

    -- 11. InventarioPorUbicacion | Un saldo por variante y ubicación; sin stock negativo ni sobre-reserva.
    CREATE TABLE dbo.InventarioPorUbicacion (
        IDInventarioPorUbicacion INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InventarioPorUbicacion PRIMARY KEY,
        IDVariante INT NOT NULL,
        IDUbicacion INT NOT NULL,
        ExistenciaFisica INT NOT NULL,
        CantidadReservada INT NOT NULL,
        FechaActualizacion DATETIME2(3) NOT NULL
    );
    -- Saldo inicial cero y fecha UTC.
    ALTER TABLE dbo.InventarioPorUbicacion ADD CONSTRAINT DF_Inventario_Fisica DEFAULT (0) FOR ExistenciaFisica;
    ALTER TABLE dbo.InventarioPorUbicacion ADD CONSTRAINT DF_Inventario_Reservada DEFAULT (0) FOR CantidadReservada;
    ALTER TABLE dbo.InventarioPorUbicacion ADD CONSTRAINT DF_Inventario_FechaActualizacion DEFAULT (SYSUTCDATETIME()) FOR FechaActualizacion;
    -- Un saldo por variante y ubicacion.
    ALTER TABLE dbo.InventarioPorUbicacion ADD CONSTRAINT UQ_Inventario_Variante_Ubicacion UNIQUE (IDVariante, IDUbicacion);
    -- No admite negativos ni reservas superiores al stock.
    ALTER TABLE dbo.InventarioPorUbicacion ADD CONSTRAINT CK_Inventario_NoNegativo CHECK (ExistenciaFisica >= 0 AND CantidadReservada >= 0);
    ALTER TABLE dbo.InventarioPorUbicacion ADD CONSTRAINT CK_Inventario_ReservaNoSuperaFisica CHECK (CantidadReservada <= ExistenciaFisica);
    -- Variante y ubicacion deben existir.
    ALTER TABLE dbo.InventarioPorUbicacion ADD CONSTRAINT FK_Inventario_Variante FOREIGN KEY (IDVariante) REFERENCES dbo.Variante (IDVariante);
    ALTER TABLE dbo.InventarioPorUbicacion ADD CONSTRAINT FK_Inventario_Ubicacion FOREIGN KEY (IDUbicacion) REFERENCES dbo.Ubicacion (IDUbicacion);

    -- Pendiente: validar combinaciones de atributos y conciliar kardex/reservas.
    -- La API no tendra permisos de escritura directa sobre estas tablas.
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
