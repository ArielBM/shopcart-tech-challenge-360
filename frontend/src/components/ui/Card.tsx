import { useId } from "react";
import type { HTMLAttributes, ReactNode, Ref } from "react";

export interface CardProps extends Omit<HTMLAttributes<HTMLElement>, "title"> {
  children: ReactNode;
  title?: string;
  description?: string;
  actions?: ReactNode;
  ref?: Ref<HTMLElement>;
}

export function Card({
  children, title, description, actions, className = "", ref,
  "aria-labelledby": labelledBy, ...props
}: CardProps) {
  const titleId = useId();

  return (
    <section
      {...props}
      ref={ref}
      aria-labelledby={labelledBy ?? (title ? titleId : undefined)}
      className={`min-w-0 rounded-xl border border-line bg-white p-4 text-ink shadow-panel sm:p-6 ${className}`}
    >
      {(title || description || actions) && (
        <header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          {(title || description) && (
            <div className="min-w-0">
              {title && <h2 id={titleId} className="break-words text-base font-semibold">{title}</h2>}
              {description && <p className="mt-1 break-words text-sm text-muted">{description}</p>}
            </div>
          )}
          {actions && <div className="flex min-w-0 flex-wrap items-center gap-2">{actions}</div>}
        </header>
      )}
      {children}
    </section>
  );
}
