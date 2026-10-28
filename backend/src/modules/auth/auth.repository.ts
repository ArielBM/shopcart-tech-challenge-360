import sql from "mssql";
import { getConnection } from "../../database/connection";
import type { RegisteredUser, CreateUserData } from "./auth.types";

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
