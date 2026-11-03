import type { ButtonHTMLAttributes, Ref } from "react";

type ButtonVariant = "primary" | "secondary" | "outline" | "danger" | "ghost";
type ButtonSize = "sm" | "md" | "lg";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  isLoading?: boolean;
  ref?: Ref<HTMLButtonElement>;
}

const variants: Record<ButtonVariant, string> = {
  primary: "border-brand bg-brand text-white enabled:hover:bg-brand/90 enabled:active:bg-brand/80",
  secondary: "border-transparent bg-brand-soft text-ink enabled:hover:bg-brand/15 enabled:active:bg-brand/20",
  outline: "border-line bg-transparent text-ink enabled:hover:border-brand enabled:hover:bg-brand-soft enabled:active:bg-brand/15",
  danger: "border-danger bg-danger text-white enabled:hover:bg-danger/90 enabled:active:bg-danger/80",
  ghost: "border-transparent bg-transparent text-muted enabled:hover:bg-canvas enabled:hover:text-ink enabled:active:bg-brand-soft",
};

const sizes: Record<ButtonSize, string> = {
  sm: "min-h-9 min-w-9 px-3 py-1.5 text-sm",
  md: "min-h-11 min-w-11 px-4 py-2.5 text-sm",
  lg: "min-h-12 min-w-12 px-6 py-3 text-base",
};

export function Button({
  variant = "primary",
  size = "md",
  isLoading = false,
  type = "button",
  disabled = false,
  className = "",
  children,
  ref,
  "aria-busy": ariaBusy,
  ...props
}: ButtonProps) {
  return (
    <button
      {...props}
      ref={ref}
      type={type}
      disabled={disabled || isLoading}
      aria-busy={isLoading || ariaBusy}
      className={`relative inline-flex max-w-full items-center justify-center rounded-lg border font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:opacity-50 motion-reduce:transition-none ${variants[variant]} ${sizes[size]} ${className}`}
    >
      {/* Keep the label's dimensions and accessible name while the spinner is shown. */}
      <span className={`inline-flex items-center justify-center gap-2 ${isLoading ? "opacity-0" : ""}`}>
        {children}
      </span>
      {isLoading && (
        <span aria-hidden="true" className="pointer-events-none absolute inset-0 m-auto size-4 rounded-full border-2 border-current border-r-transparent motion-safe:animate-spin" />
      )}
    </button>
  );
}
