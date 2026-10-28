import sql from "mssql";
import { getConnection } from "../../database/connection";
import type { RegisteredUser, CreateUserData, LoginUser } from "./auth.types";

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
