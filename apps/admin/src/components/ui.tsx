import { clsx } from "clsx";
import type { ButtonHTMLAttributes, InputHTMLAttributes, SelectHTMLAttributes, TextareaHTMLAttributes } from "react";

export function Button({
  className,
  variant = "primary",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "danger" | "ghost" }) {
  return (
    <button
      className={clsx(
        "inline-flex min-h-11 cursor-pointer items-center justify-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal disabled:cursor-not-allowed disabled:opacity-55",
        variant === "primary" && "bg-teal text-white hover:bg-[#066a75]",
        variant === "secondary" && "border border-line bg-white text-ink hover:bg-shell",
        variant === "danger" && "bg-coral text-white hover:bg-[#bd493d]",
        variant === "ghost" && "bg-transparent text-ink hover:bg-white",
        className
      )}
      {...props}
    />
  );
}

export function Badge({
  children,
  tone = "neutral"
}: {
  children: React.ReactNode;
  tone?: "neutral" | "good" | "warning" | "danger" | "info";
}) {
  return (
    <span
      className={clsx(
        "inline-flex min-h-6 items-center rounded-md border px-2 text-xs font-semibold",
        tone === "neutral" && "border-line bg-shell text-muted",
        tone === "good" && "border-mint/30 bg-mint/10 text-[#1f765a]",
        tone === "warning" && "border-amber/30 bg-amber/10 text-[#8b5a17]",
        tone === "danger" && "border-coral/30 bg-coral/10 text-[#a83d32]",
        tone === "info" && "border-teal/25 bg-teal/10 text-teal"
      )}
    >
      {children}
    </span>
  );
}

export function Card({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <section className={clsx("rounded-lg border border-line bg-panel p-4 shadow-soft", className)}>
      {children}
    </section>
  );
}

export function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-1 text-sm font-semibold text-ink">
      <span>{label}</span>
      {children}
    </label>
  );
}

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={clsx("min-h-11 w-full rounded-md border border-line bg-white px-3 py-2 text-sm text-ink placeholder:text-muted focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal", className)}
      {...props}
    />
  );
}

export function Textarea({ className, ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      className={clsx("min-h-24 w-full rounded-md border border-line bg-white px-3 py-2 text-sm text-ink placeholder:text-muted focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal", className)}
      {...props}
    />
  );
}

export function Select({ className, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={clsx("min-h-11 w-full rounded-md border border-line bg-white px-3 py-2 text-sm text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal", className)}
      {...props}
    />
  );
}

export function TableWrap({ children }: { children: React.ReactNode }) {
  return <div className="overflow-x-auto rounded-lg border border-line bg-white">{children}</div>;
}

export function Th({ children }: { children: React.ReactNode }) {
  return <th className="whitespace-nowrap px-3 py-3 text-left text-xs font-bold uppercase text-muted">{children}</th>;
}

export function Td({ children, className }: { children: React.ReactNode; className?: string }) {
  return <td className={clsx("max-w-[240px] px-3 py-3 text-sm text-ink", className)}>{children}</td>;
}
