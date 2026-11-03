export interface AuditQuery {
  modulo?: string;
  pagina: number;
  tamanoPagina: number;
}

export interface AuditRecord {
  IDBitacora: string;
  IDUsuario: number;
  Modulo: string;
  Entidad: string;
  IDEntidad: string;
  Accion: string;
  ValorAnterior: string | null;
  ValorNuevo: string | null;
  FechaAccion: Date;
}

export interface AuditResult {
  records: AuditRecord[];
  totalRegistros: string;
}
