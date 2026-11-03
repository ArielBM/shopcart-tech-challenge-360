import { getAuditRecords } from "./audit.repository";

import type { AuditQuery } from "./audit.types";

export async function getAuditRecordsService(filters: AuditQuery) {
  const result = await getAuditRecords(filters);

  return {
    data: result.records.map((record) => ({
      idBitacora: record.IDBitacora,
      idUsuario: record.IDUsuario,
      modulo: record.Modulo,
      entidad: record.Entidad,
      idEntidad: record.IDEntidad,
      accion: record.Accion,
      valorAnterior: record.ValorAnterior,
      valorNuevo: record.ValorNuevo,
      fechaAccion: record.FechaAccion,
    })),
    pagination: {
      pagina: filters.pagina,
      tamanoPagina: filters.tamanoPagina,
      totalRegistros: result.totalRegistros,
    },
  };
}
