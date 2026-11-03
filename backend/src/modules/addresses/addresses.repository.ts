import sql from "mssql";
import { getConnection } from "../../database/connection";

import type { CreateAddressData } from "./addresses.schemas";
import type { AddressRecord } from "./addresses.types";

export async function createAddress(
  idUsuario: number,
  data: CreateAddressData,
): Promise<AddressRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDUsuario", sql.Int, idUsuario)
    .input("NombreDestinatario", sql.NVarChar(150), data.nombreDestinatario)
    .input("Telefono", sql.VarChar(30), data.telefono)
    .input("Departamento", sql.NVarChar(100), data.departamento)
    .input("Municipio", sql.NVarChar(100), data.municipio)
    .input("DireccionTexto", sql.NVarChar(500), data.direccionTexto)
    .input("Referencia", sql.NVarChar(300), data.referencia)
    .execute<AddressRecord>("dbo.SP_Direcciones_Registrar");

  const address = result.recordset[0];

  if (!address) {
    throw new Error("El registro de dirección no devolvió un resultado.");
  }

  return address;
}

export async function getAddresses(
  idUsuario: number,
): Promise<AddressRecord[]> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDUsuario", sql.Int, idUsuario)
    .execute<AddressRecord>("dbo.SP_Direcciones_Consultar");

  return result.recordset;
}
