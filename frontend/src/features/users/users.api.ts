import { api } from "../../lib/api";
import type { AdminUser, UsersQuery, UsersResponse } from "./users.types";

export async function getUsersClient(
  query: UsersQuery,
): Promise<UsersResponse> {
  const { data } = await api.get<UsersResponse>("/users", {
    params: query,
  });

  return data;
}

export async function changeUserStatusClient(
  idUsuario: number,
  activo: boolean,
): Promise<AdminUser> {
  const { data } = await api.patch<{ data: AdminUser }>(
    `/users/${idUsuario}/status`,
    { activo },
  );

  return data.data;
}
