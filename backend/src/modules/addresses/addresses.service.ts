import type { CreateAddressData } from "./addresses.schemas";
import type { AddressRecord } from "./addresses.types";

import { createAddress, getAddresses } from "./addresses.repository";

function mapAddress(address: AddressRecord) {
  return {
    idDireccion: String(address.IDDireccion),
    nombreDestinatario: address.NombreDestinatario,
    telefono: address.Telefono,
    departamento: address.Departamento,
    municipio: address.Municipio,
    direccionTexto: address.DireccionTexto,
    referencia: address.Referencia,
    activa: address.Activa,
    fechaCreacion: address.FechaCreacion,
  };
}

export async function createAddressService(
  idUsuario: number,
  data: CreateAddressData,
) {
  const address = await createAddress(idUsuario, data);

  return {
    data: mapAddress(address),
  };
}

export async function getAddressesService(idUsuario: number) {
  const addresses = await getAddresses(idUsuario);

  return {
    data: addresses.map(mapAddress),
  };
}
