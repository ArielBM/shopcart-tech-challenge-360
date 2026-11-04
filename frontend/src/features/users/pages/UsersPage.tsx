import { useEffect, useState } from "react";
import type { FormEvent } from "react";

import { Button } from "../../../components/ui/Button";
import {
  DataTable,
  type DataTableColumn,
} from "../../../components/ui/DataTable";
import { Select } from "../../../components/ui/Select";
import { TextInput } from "../../../components/ui/TextInput";
import { getApiErrorMessage } from "../../../lib/api";
import { useAuthStore } from "../../auth/auth.store";

import { changeUserStatusClient, getUsersClient } from "../users.api";
import type { AdminUser, UserStatusFilter } from "../users.types";

const PAGE_SIZE = 20;

const statusOptions = [
  { value: "TODOS", label: "Todos" },
  { value: "ACTIVO", label: "Activos" },
  { value: "INACTIVO", label: "Inactivos" },
];

export function UsersPage() {
  const currentUser = useAuthStore((state) => state.user);

  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<UserStatusFilter>("TODOS");
  const [page, setPage] = useState(1);
  const [revision, setRevision] = useState(0);

  const [users, setUsers] = useState<AdminUser[]>([]);
  const [total, setTotal] = useState("0");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | undefined>();
  const [actionError, setActionError] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  const [updatingId, setUpdatingId] = useState<number | null>(null);

  useEffect(() => {
    let active = true;

    async function loadUsers() {
      setLoading(true);
      setError(undefined);

      try {
        const result = await getUsersClient({
          buscar: search || undefined,
          estado: status,
          pagina: page,
          tamanoPagina: PAGE_SIZE,
        });

        if (!active) return;

        setUsers(result.data);
        setTotal(result.pagination.totalRegistros);
      } catch (err) {
        if (!active) return;

        setUsers([]);
        setError(getApiErrorMessage(err));
      } finally {
        if (active) setLoading(false);
      }
    }

    void loadUsers();

    return () => {
      active = false;
    };
  }, [search, status, page, revision]);

  function handleSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  }

  async function handleChangeStatus(user: AdminUser) {
    if (updatingId !== null) return;

    const nextStatus = !user.activo;
    const action = nextStatus ? "activar" : "desactivar";

    if (
      !window.confirm(
        `¿Deseas ${action} la cuenta de ${user.nombre} (${user.correo})?`,
      )
    ) {
      return;
    }

    setUpdatingId(user.idUsuario);
    setActionError(null);
    setActionMessage(null);

    try {
      await changeUserStatusClient(user.idUsuario, nextStatus);

      setActionMessage(
        `La cuenta de ${user.nombre} fue ${
          nextStatus ? "activada" : "desactivada"
        }.`,
      );

      setRevision((value) => value + 1);
    } catch (err) {
      setActionError(getApiErrorMessage(err));
    } finally {
      setUpdatingId(null);
    }
  }

  const columns: DataTableColumn<AdminUser>[] = [
    {
      id: "nombre",
      header: "Nombre",
      cell: (user) => user.nombre,
    },
    {
      id: "correo",
      header: "Correo",
      cell: (user) => user.correo,
    },
    {
      id: "rol",
      header: "Rol",
      cell: (user) => user.rol,
    },
    {
      id: "estado",
      header: "Estado",
      cell: (user) => (
        <span
          className={
            user.activo ? "font-medium text-ink" : "font-medium text-danger"
          }
        >
          {user.activo ? "Activo" : "Inactivo"}
        </span>
      ),
    },
    {
      id: "acciones",
      header: "Acciones",
      cell: (user) => (
        <Button
          size="sm"
          variant={user.activo ? "outline" : "primary"}
          disabled={
            updatingId !== null ||
            (user.activo && user.idUsuario === currentUser?.idUsuario)
          }
          isLoading={updatingId === user.idUsuario}
          onClick={() => void handleChangeStatus(user)}
        >
          {user.activo ? "Desactivar" : "Activar"}
        </Button>
      ),
    },
  ];

  return (
    <section className="min-w-0 space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-ink">
          Administración de usuarios
        </h1>
        <p className="mt-2 text-sm text-muted">
          Consulta usuarios y administra el acceso a sus cuentas.
        </p>
      </div>

      <form
        onSubmit={handleSearch}
        className="grid gap-4 rounded-xl border border-line bg-white p-4 md:grid-cols-[minmax(0,1fr)_12rem_auto] md:items-end"
      >
        <TextInput
          label="Buscar usuario"
          type="search"
          placeholder="Nombre o correo"
          maxLength={150}
          value={searchInput}
          onChange={(event) => setSearchInput(event.target.value)}
        />

        <Select
          label="Estado"
          options={statusOptions}
          value={status}
          onChange={(event) => {
            setStatus(event.target.value as UserStatusFilter);
            setPage(1);
          }}
        />

        <Button type="submit" disabled={loading}>
          Buscar
        </Button>
      </form>

      {actionError && (
        <p role="alert" className="text-sm text-danger">
          {actionError}
        </p>
      )}

      {actionMessage && (
        <p role="status" className="text-sm text-ink">
          {actionMessage}
        </p>
      )}

      <DataTable
        caption="Listado de usuarios"
        data={users}
        columns={columns}
        getRowKey={(user) => user.idUsuario}
        page={page}
        pageSize={PAGE_SIZE}
        totalRecords={total}
        onPageChange={setPage}
        loading={loading}
        error={error}
        emptyMessage="No se encontraron usuarios."
      />
    </section>
  );
}
