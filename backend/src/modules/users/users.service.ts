import { getUsers, changeUserStatus } from "./users.repository";

import type { UserQuery, UserRecord, ChangeUserStatus } from "./users.types";

function toUserResponse(user: UserRecord) {
  return {
    idUsuario: user.IDUsuario,
    correo: user.Correo,
    nombre: user.Nombre,
    rol: user.Rol,
    activo: user.Activo,
    fechaCreacion: user.FechaCreacion,
    fechaActualizacion: user.FechaActualizacion,
  };
}

export async function getUsersService(filters: UserQuery) {
  const result = await getUsers(filters);

  return {
    data: result.records.map(toUserResponse),
    pagination: {
      pagina: filters.pagina,
      tamanoPagina: filters.tamanoPagina,
      totalRegistros: result.totalRegistros,
    },
  };
}

export async function changeUserStatusService(input: ChangeUserStatus) {
  const user = await changeUserStatus(input);
  return toUserResponse(user);
}
