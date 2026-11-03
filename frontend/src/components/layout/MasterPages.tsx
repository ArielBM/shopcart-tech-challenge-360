import { useEffect, useId, useRef } from "react";
import type { ReactNode } from "react";
import { Link, NavLink, Outlet } from "react-router";

type NavigationItem = Readonly<{ label: string; to: string }>;
type BreadcrumbItem = Readonly<{ label: string; to?: string }>;

function Brand({ inverse = false }: { inverse?: boolean }) {
  return (
    <Link
      to="/"
      aria-label="ShopCart, inicio"
      className={`inline-flex shrink-0 items-center gap-3 rounded-lg ${inverse ? "text-white" : "text-ink"}`}
    >
      <span className="flex size-10 items-center justify-center rounded-xl bg-brand text-white">
        <svg width="23" height="23" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M5 7h14l1 13H4L5 7Z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />
          <path d="M8 8V6a4 4 0 0 1 8 0v2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
        </svg>
      </span>
      <span className="text-xl font-bold tracking-tight">ShopCart<span className="text-brand">.</span></span>
    </Link>
  );
}

function SkipLink({ target }: { target: string }) {
  return (
    <a href={`#${target}`} className="sr-only z-50 rounded-lg bg-white px-4 py-3 text-brand focus:not-sr-only focus:fixed focus:top-3 focus:left-3">
      Saltar al contenido
    </a>
  );
}

// Native dialog provides focus trapping, Escape and return to the opening button.
function MobileNavigation({ label, children }: { label: string; children: ReactNode }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const id = useId();

  useEffect(() => {
    const desktop = window.matchMedia("(min-width: 64rem)");
    const closeOnDesktop = () => {
      if (desktop.matches) dialogRef.current?.close();
    };
    desktop.addEventListener("change", closeOnDesktop);
    return () => desktop.removeEventListener("change", closeOnDesktop);
  }, []);

  return (
    <>
      <button
        type="button"
        aria-label={`Abrir ${label.toLowerCase()}`}
        aria-haspopup="dialog"
        aria-controls={id}
        onClick={() => dialogRef.current?.showModal()}
        className="flex size-11 shrink-0 items-center justify-center rounded-lg border border-line bg-white text-ink hover:bg-canvas lg:hidden"
      >
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M4 6h16M4 12h16M4 18h16" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
        </svg>
      </button>
      <dialog
        id={id}
        ref={dialogRef}
        aria-labelledby={`${id}-title`}
        className="m-0 h-dvh max-h-none w-72 max-w-[calc(100%_-_2rem)] border-0 bg-sidebar p-0 text-white backdrop:bg-ink/50 lg:hidden"
        onClick={(event) => {
          if (event.target === event.currentTarget) dialogRef.current?.close();
        }}
        onClickCapture={(event) => {
          if (event.target instanceof Element && event.target.closest("a")) dialogRef.current?.close();
        }}
      >
        <div className="flex min-h-full flex-col p-6">
          <div className="mb-9 flex items-center justify-between gap-3">
            <h2 id={`${id}-title`} className="text-sm font-semibold">{label}</h2>
            <button
              type="button"
              aria-label="Cerrar navegación"
              onClick={() => dialogRef.current?.close()}
              className="flex size-11 items-center justify-center rounded-lg text-xl text-white hover:bg-white/10"
            >
              <span aria-hidden="true">×</span>
            </button>
          </div>
          {children}
        </div>
      </dialog>
    </>
  );
}

function Navigation({ items, dark = false }: { items: readonly NavigationItem[]; dark?: boolean }) {
  return (
    <nav aria-label="Navegación principal" className="flex flex-col gap-1">
      {items.map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          end
          className={({ isActive }) => `rounded-lg px-4 py-3 text-sm font-medium ${isActive ? "bg-brand text-white" : dark ? "text-slate-300 hover:bg-white/10 hover:text-white" : "text-muted hover:bg-brand-soft hover:text-brand"}`}
        >
          {item.label}
        </NavLink>
      ))}
    </nav>
  );
}

type AdminLayoutProps = {
  title?: string;
  navigation?: readonly NavigationItem[];
  breadcrumbs?: readonly BreadcrumbItem[];
  headerActions?: ReactNode;
};

// Visual shell only. Mount inside a protected route once authorization exists.
// The caller supplies the permitted navigation; this component never infers a role.
export function AdminLayout({ title = "Administración", navigation = [], breadcrumbs = [], headerActions }: AdminLayoutProps) {
  const contentId = useId();
  const sidebarContent = (
    <>
      <Brand inverse />
      <p className="mt-10 mb-4 px-4 text-xs font-semibold tracking-widest text-slate-400 uppercase">Área de gestión</p>
      <Navigation items={navigation} dark />
      <div className="mt-auto border-t border-white/10 pt-5">
        <Link to="/" className="block rounded-lg px-4 py-3 text-sm text-slate-300 hover:bg-white/10 hover:text-white">Ir a la tienda <span aria-hidden="true">↗</span></Link>
      </div>
    </>
  );

  return (
    <div className="min-h-dvh bg-canvas text-ink lg:grid lg:grid-cols-[17.5rem_minmax(0,1fr)]">
      <SkipLink target={contentId} />
      <aside aria-label="Barra lateral" className="sticky top-0 hidden h-dvh flex-col gap-2 overflow-y-auto bg-sidebar p-6 lg:flex">
        {sidebarContent}
      </aside>
      <div className="min-w-0">
        <header className="flex min-h-18 flex-wrap items-center justify-between gap-4 border-b border-line bg-white px-4 py-3 sm:px-6 lg:px-8">
          <div className="flex min-w-0 items-center gap-3">
            <MobileNavigation label="Navegación administrativa">{sidebarContent}</MobileNavigation>
            <span className="break-words text-sm font-semibold">{title}</span>
          </div>
          {headerActions && <div className="flex flex-wrap items-center gap-3">{headerActions}</div>}
        </header>
        <main id={contentId} tabIndex={-1} className="mx-auto w-full max-w-screen-2xl p-4 sm:p-6 lg:p-8">
          {breadcrumbs.length > 0 && (
            <nav aria-label="Ruta de navegación" className="mb-6">
              <ol className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-muted">
                {breadcrumbs.map((item, index) => (
                  <li key={`${index}-${item.label}`} className="flex items-center gap-2">
                    {index > 0 && <span aria-hidden="true" className="text-muted/60">/</span>}
                    {item.to && index < breadcrumbs.length - 1
                      ? <Link to={item.to} className="rounded-sm hover:text-brand">{item.label}</Link>
                      : <span aria-current={index === breadcrumbs.length - 1 ? "page" : undefined} className="break-words">{item.label}</span>}
                  </li>
                ))}
              </ol>
            </nav>
          )}
          <Outlet />
        </main>
      </div>
    </div>
  );
}

type StorefrontLayoutProps = {
  navigation?: readonly NavigationItem[];
  search?: ReactNode;
  cart?: ReactNode;
  account?: ReactNode;
};

// Slots are populated when real search, cart and account features become available.
export function StorefrontLayout({ navigation = [{ label: "Inicio", to: "/" }], search, cart, account }: StorefrontLayoutProps) {
  const contentId = useId();

  return (
    <div className="flex min-h-dvh flex-col bg-canvas text-ink">
      <SkipLink target={contentId} />
      <header className="border-b border-line bg-white">
        <div className="mx-auto flex w-full max-w-7xl flex-wrap items-center gap-4 px-4 py-5 sm:px-6 lg:px-8">
          <Brand />
          <div className="ml-auto hidden lg:block"><Navigation items={navigation} /></div>
          <div className="ml-auto lg:ml-0">
            <MobileNavigation label="Navegación de tienda">
              <Brand inverse />
              <div className="mt-8"><Navigation items={navigation} dark /></div>
            </MobileNavigation>
          </div>
          {(cart || account) && <div className="flex flex-wrap items-center gap-3">{cart}{account}</div>}
          {search && <div className="w-full min-w-0 lg:order-none lg:max-w-sm">{search}</div>}
        </div>
      </header>
      <main id={contentId} tabIndex={-1} className="mx-auto w-full max-w-7xl flex-1 px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
        <Outlet />
      </main>
      <footer className="border-t border-line bg-white">
        <div className="mx-auto flex max-w-7xl flex-col gap-2 px-4 py-6 text-sm text-muted sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
          <span className="font-semibold text-ink">ShopCart</span>
          <span>Tu tienda, en un solo lugar.</span>
        </div>
      </footer>
    </div>
  );
}

export function AuthLayout() {
  const contentId = useId();

  return (
    <div className="flex min-h-dvh flex-col items-center justify-center bg-canvas px-4 py-8 text-ink sm:px-6 sm:py-12">
      <SkipLink target={contentId} />
      <header className="mb-8"><Brand /></header>
      <main id={contentId} tabIndex={-1} className="w-full max-w-md rounded-xl border border-line bg-white p-6 shadow-panel sm:p-10">
        <Outlet />
      </main>
      <footer className="mt-8 text-center text-sm text-muted">
        <Link to="/" className="rounded-sm hover:text-brand">Volver a la tienda</Link>
      </footer>
    </div>
  );
}
