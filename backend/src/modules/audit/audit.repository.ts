import sql from "mssql";
import { getConnection } from "../../database/connection";

import type { AuditQuery, AuditRecord, AuditResult } from "./audit.types";

export async function getAuditRecords(
  filters: AuditQuery,
): Promise<AuditResult> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("Modulo", sql.VarChar(30), filters.modulo ?? null)
    .input("Pagina", sql.Int, filters.pagina)
    .input("TamanoPagina", sql.Int, filters.tamanoPagina)
    .output("TotalRegistros", sql.BigInt)
    .execute<AuditRecord>("dbo.SP_Bitacora_Consultar");

  return {
    records: result.recordset,
    totalRegistros: String(result.output.TotalRegistros),
  };
}
