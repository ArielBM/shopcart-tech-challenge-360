export interface AddressRecord {
  IDDireccion: string | number;
  NombreDestinatario: string;
  Telefono: string | null;
  Departamento: string;
  Municipio: string;
  DireccionTexto: string;
  Referencia: string | null;
  Activa: boolean;
  FechaCreacion: Date;
}
