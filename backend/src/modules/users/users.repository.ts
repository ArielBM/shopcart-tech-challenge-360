import sql from "mssql";
import { getConnection } from "../../database/connection";

import type {
  UserQuery,
  UserRecord,
  UsersResult,
  ChangeUserStatus,
} from "./users.types";

export async function getUsers(filters: UserQuery): Promise<UsersResult> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("Buscar", sql.NVarChar(150), filters.buscar ?? null)
    .input("Estado", sql.VarChar(10), filters.estado)
    .input("Pagina", sql.Int, filters.pagina)
    .input("TamanoPagina", sql.Int, filters.tamanoPagina)
    .output("TotalRegistros", sql.BigInt)
    .execute<UserRecord>("dbo.SP_Usuarios_Consultar");

  return {
    records: result.recordset,
    totalRegistros: String(result.output.TotalRegistros),
  };
}

export async function changeUserStatus(
  input: ChangeUserStatus,
): Promise<UserRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDUsuario", sql.Int, input.idUsuario)
    .input("Activo", sql.Bit, input.activo)
    .input("IDAdministrador", sql.Int, input.idAdministrador)
    .execute<UserRecord>("dbo.SP_Usuarios_CambiarEstado");

  const user = result.recordset[0];

  if (!user) {
    throw new Error("El cambio de estado no devolvió un usuario.");
  }

  return user;
}
