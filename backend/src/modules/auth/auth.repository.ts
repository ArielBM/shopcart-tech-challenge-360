import sql from "mssql";
import { getConnection } from "../../database/connection";
import type {
  RegisteredUser,
  CreateUserData,
  LoginUser,
  CreatedSession,
  RotatedSession,
} from "./auth.types";

export async function createUser(
  data: CreateUserData,
): Promise<RegisteredUser> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("Correo", sql.NVarChar(254), data.correo)
    .input("HashContrasena", sql.VarChar(255), data.hashContrasena)
    .input("Nombre", sql.NVarChar(150), data.nombre)
    .execute<RegisteredUser>("dbo.SP_Auth_RegistrarCliente");

  const user = result.recordset[0];

  if (!user) {
    throw new Error("El registro no devolvió un usuario.");
  }

  return user;
}

export async function findUserByEmail(
  correo: string,
): Promise<LoginUser | undefined> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("Correo", sql.NVarChar(254), correo)
    .execute<LoginUser>("dbo.SP_Auth_ObtenerUsuarioPorCorreo");

  return result.recordset[0];
}

export async function createSession(
  idUsuario: number,
  tokenHash: Buffer,
): Promise<CreatedSession> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDUsuario", sql.Int, idUsuario)
    .input("TokenHas", sql.VarBinary(32), tokenHash)
    .execute<CreatedSession>("dbo.SP_Auth_CrearSesion");

  const session = result.recordset[0];

  if (!session)
    throw new Error("La creación de sesión no devolvió resultados.");

  return session;
}

export async function rotateSession(
  currentToken: Buffer,
  newTokenHash: Buffer,
): Promise<RotatedSession> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("TokenHashActual", sql.VarBinary(32), currentToken)
    .input("TokenHashNuevo", sql.VarBinary(32), newTokenHash)
    .execute<RotatedSession>("dbo.SP_Auth_RotarSesion");

  const session = result.recordset[0];

  if (!session) throw new Error("La rotación no devolvió una sesión.");

  return session;
}
