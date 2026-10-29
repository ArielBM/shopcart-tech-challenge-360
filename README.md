# shopcart-tech-challenge-360
Plataforma de comercio electrónico lista para producción, desarrollada con React, Express, TypeScript y SQL Server. Creada para el Tech Challenge 360°.

## Autenticación y sesiones (RF-01)

El registro usa Argon2id. Login emite un JWT HS256 de 15 minutos y un refresh token
aleatorio de 256 bits. SQL Server guarda únicamente su hash SHA-256. Cada login
crea una familia independiente, con vencimiento absoluto a siete días; las
rotaciones conservan ese vencimiento. La duración del refresh se define en
`db/006_SP_Autenticacion.sql`, sin una segunda configuración en Node.

Aplicar los scripts 001-006 en orden sobre una instalación nueva; en una base ya
preparada, ejecutar nuevamente 006 actualiza los procedimientos de autenticación.
El 005 configura el acceso de aplicación y requiere adaptar sus valores de ejemplo;
si el login/usuario/permisos ya existen, no volver a ejecutarlo sin revisar.
El backend usa exclusivamente procedimientos almacenados con parámetros tipados.
`cookie-parser` permite leer la cookie del refresh; `jose` firma y verifica los JWT.

### API e integración con React

Todas las rutas siguientes son `POST` bajo `/api/v1/auth`:

- `/register`: JSON con `nombre`, `correo` y `contrasena`; devuelve 201.
- `/login`: JSON con `correo` y `contrasena`; devuelve 200 con `data.user`,
  `accessToken`, `tokenType` y `expiresIn` (900 segundos), y establece la cookie.
- `/refresh`: usa únicamente la cookie; devuelve el mismo formato del login y
  reemplaza la cookie. No recibe tokens en el body, URL ni cabeceras propias.
- `/logout`: revoca la familia identificada por la cookie y la elimina; devuelve
  204, también si la cookie falta, es desconocida o ya estaba revocada.

Enviar `X-CSRF-Protection: 1` en las cuatro rutas y `credentials: "include"`
en las llamadas de autenticación. El navegador envía `Origin`, que debe coincidir
exactamente con `CORS_ORIGIN`. Las herramientas de prueba también deben enviar
ambas cabeceras. CORS permite credenciales únicamente para ese origen y permite
las cabeceras `Content-Type`, `Authorization` y `X-CSRF-Protection`.

```ts
const response = await fetch(`${apiUrl}/api/v1/auth/refresh`, {
  method: "POST",
  credentials: "include",
  headers: { "X-CSRF-Protection": "1" },
});
```

El refresh nunca se devuelve en JSON. Guardar el access token en memoria y
enviarlo como `Authorization: Bearer ...` en rutas protegidas. Las respuestas
de autenticación llevan `Cache-Control: no-store`. No registrar bodies, cookies
ni cabeceras de autorización en proxies o herramientas de observabilidad; el
manejador del backend tampoco registra objetos o mensajes de errores SQL.

### Cookies y despliegue

Despliegue acordado: React y API en el mismo sitio, con HTTPS en producción.
Cookie `refreshToken`: `HttpOnly`, `SameSite=Lax`, `Secure` cuando
`NODE_ENV=production`, sin `Domain` (host de la API) y con ruta `/api/v1/auth`.
Su fecha de expiración viene de SQL; borrarla usa los mismos atributos.
En producción `CORS_ORIGIN` debe ser HTTPS. Usar `NODE_ENV=production` y terminar
TLS en el servidor o proxy. No se confía automáticamente en `X-Forwarded-For`;
si se introduce un proxy, configurar los saltos de confianza antes de usar el
rate limiting por IP detrás de él. No ampliar `trust proxy` a cualquier origen.

La combinación de origen exacto y cabecera propia impide solicitudes de formularios
de otros sitios y exige preflight para llamadas cross-origin. `SameSite` añade
defensa adicional. Esta política sigue las recomendaciones de
[OWASP sobre CSRF para APIs](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html).
Publicar frontend y API en sitios distintos requiere revisar esta política; no
basta con cambiar la cookie a `SameSite=None`.

### Rotación, concurrencia y duplicados

Rotación y logout obtienen el mismo bloqueo exclusivo por `IDFamilia` mediante
[`sp_getapplock`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-getapplock-transact-sql),
con propietario transaccional y espera máxima de diez segundos. El SP identifica
la familia sin retener bloqueos de filas, toma el bloqueo y después relee el estado.
Revocar el anterior e insertar el nuevo son una sola transacción. El instante de
validación se toma después de esperar el bloqueo. Un fallo de inserción revierte
también el consumo del anterior. La respuesta usa la instantánea validada dentro
de la transacción, sin releer el token después del commit.

La política elegida es **replay estricto, sin ventana de gracia**. Usar cualquier
token ya revocado revoca todos los tokens aún activos de su familia. La revocación
se confirma antes de comunicar el error. Esto también cubre la carrera entre un
ancestro reutilizado y la rotación de un descendiente. Otras familias son independientes.
La política es consistente con la detección de replay descrita en
[RFC 9700, sección 4.14.2](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14.2).

Con dos solicitudes simultáneas sobre el mismo token, exactamente una puede
renovar; la otra detecta replay y cierra la familia, incluido el token recién
emitido. No se puede distinguir un duplicado legítimo de un token robado sin
otro protocolo o retener respuestas sensibles. Se prioriza revocación segura
y se evita guardar refresh tokens recuperables en la base de datos.

React debe coordinar un único refresh en curso y compartir su resultado entre
las solicitudes pendientes, también entre pestañas. No reintentar automáticamente
un refresh tras una respuesta perdida o error de red: pudo haberse consumido.
En ese caso puede ser necesario iniciar sesión nuevamente. El orden de llegada
de cookies de respuestas concurrentes también puede dejar una cookie inválida;
coordinar el cliente evita ese escenario, sin relajar la detección en SQL.

### Errores y límites

- 400: validación del body o JSON inválido; 413: cuerpo demasiado grande;
  409: correo duplicado; 429: límite de registro/login
  (cinco solicitudes por IP cada quince minutos, contadores separados en memoria).
- 401: credenciales inválidas o sesión desconocida, expirada, revocada, reutilizada
  o perteneciente a usuario desactivado. No se expone cuál de esos casos ocurrió.
- 403: protección CSRF fallida o permisos insuficientes en rutas protegidas.
- 503: timeout del bloqueo de familia o deadlock SQL. No se convierte en 401.
- 500: fallos internos, incluidos hashes de longitud incorrecta, parámetros SQL
  incorrectos o nuevo hash igual al anterior. No se presentan como credenciales inválidas.

El JWT incluye `sid`, el identificador de su familia. `authenticate` verifica
firma/claims y consulta mediante `SP_Auth_ObtenerSesionActiva` el estado y rol
actuales del usuario y la vigencia de esa familia en cada solicitud. Un usuario
desactivado o una familia cerrada/expirada no conservan acceso por un JWT anterior.
`authorize` aplica los roles permitidos. Esa consulta agrega un acceso SQL por
solicitud protegida y evita una caché de permisos o sesiones obsoletos.
Las futuras rutas de negocio deben aplicar estos middlewares y validar además
la propiedad de pedidos, carritos y direcciones. Esas rutas y React todavía no
están implementados: no se considera probado todo RF-01 en recursos que aún no existen.

Logout y replay revocan la familia completa, por lo que también se rechazan sus
JWT en la siguiente validación del middleware. El límite absoluto de siete días
se aplica aunque el `exp` de un JWT emitido cerca del cierre todavía no se haya
alcanzado. No hace falta una lista de JWT revocados: se consulta la familia que
ya existe en SQL. Una solicitud que ya superó la autenticación antes de una
revocación concurrente puede terminar; no se cancelan operaciones en curso.
Los JWT anteriores a la introducción del claim `sid` se rechazan y requieren
un nuevo login al aplicar esta versión.

### Verificación

Desde `backend`: `npm run typecheck`, `npm run lint`, `npm run build` y `npm test`.
Las pruebas versionadas no requieren SQL Server ni `.env`: cubren generación/hash
de refresh, formato canónico, atributos de cookie, duración/claims/roles/firma del
JWT y separación de errores HTTP sin filtrar mensajes sensibles.

Revisión local del 28 de octubre de 2026: 137 comprobaciones de integración con
HTTP y SQL Server, incluyendo registro/login, tres rotaciones, vigencia absoluta,
tokens inválidos, expiración, desactivación, logout, replay y carreras reales.
Se comprobó un único refresh exitoso en cuatro dobles solicitudes, seis carreras
entre ancestro y descendiente y seis entre logout y rotación; ninguna dejó tokens
activos en la familia revocada. También se probaron familias independientes,
timeout de bloqueo, expiración durante la espera y rollback ante hash duplicado.
Usuarios y sesiones de prueba eliminados. Las pruebas SQL se mantienen fuera del
repositorio conforme a la decisión local del proyecto.

Se verificaron los atributos de producción y CORS sobre HTTP local con repositorio
simulado. HTTPS real, comportamiento de cookies en navegador y coordinación de
React entre pestañas quedan por verificar en el despliegue/frontend.
