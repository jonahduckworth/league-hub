import { clsx } from "clsx";
import type { ButtonHTMLAttributes, InputHTMLAttributes, SelectHTMLAttributes, TextareaHTMLAttributes } from "react";

export type BadgeTone = "neutral" | "good" | "warning" | "danger" | "info";

export function Button({
  className,
  variant = "primary",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "danger" | "ghost" }) {
  return (
    <button
      className={clsx(
        "inline-flex min-h-11 cursor-pointer items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-bold transition-[background-color,border-color,color,box-shadow,transform] duration-200 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/20 disabled:cursor-not-allowed disabled:opacity-50",
        variant === "primary" && "bg-teal text-white shadow-[0_10px_24px_-14px_rgba(15,118,110,0.9)] hover:bg-[#0b665f] hover:shadow-[0_14px_28px_-16px_rgba(15,118,110,0.95)] active:translate-y-px",
        variant === "secondary" && "border border-line bg-white text-ink shadow-sm hover:border-[#b8c4d2] hover:bg-[#f8fafc]",
        variant === "danger" && "bg-coral text-white shadow-[0_10px_24px_-14px_rgba(194,65,58,0.8)] hover:bg-[#a93630] active:translate-y-px",
        variant === "ghost" && "bg-transparent text-muted hover:bg-[#eef2f6] hover:text-ink",
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
  tone?: BadgeTone;
}) {
  return (
    <span
      className={clsx(
        "inline-flex min-h-6 items-center rounded-full border px-2.5 py-0.5 text-xs font-bold leading-5",
        tone === "neutral" && "border-line bg-[#f8fafc] text-muted",
        tone === "good" && "border-mint/20 bg-mint/10 text-[#166534]",
        tone === "warning" && "border-amber/20 bg-amber/10 text-[#854d0e]",
        tone === "danger" && "border-coral/20 bg-coral/10 text-[#a93630]",
        tone === "info" && "border-teal/20 bg-teal/10 text-teal"
      )}
    >
      {children}
    </span>
  );
}

export function Card({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <section className={clsx("rounded-2xl border border-line/80 bg-panel p-5 shadow-card", className)}>
      {children}
    </section>
  );
}

export function Field({ label, children, hint }: { label: string; children: React.ReactNode; hint?: string }) {
  return (
    <label className="grid gap-2 text-sm font-bold text-ink">
      <span className="flex items-baseline justify-between gap-3">
        <span>{label}</span>
        {hint && <span className="text-xs font-medium text-muted">{hint}</span>}
      </span>
      {children}
    </label>
  );
}

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={clsx("min-h-12 w-full rounded-xl border border-line bg-white px-3.5 py-2.5 text-base text-ink shadow-sm outline-none transition-[border-color,box-shadow,background-color] placeholder:text-[#98a2b3] hover:border-[#b8c4d2] focus:border-teal focus:ring-4 focus:ring-teal/10 sm:text-sm", className)}
      {...props}
    />
  );
}

export function Textarea({ className, ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      className={clsx("min-h-28 w-full resize-y rounded-xl border border-line bg-white px-3.5 py-3 text-base leading-6 text-ink shadow-sm outline-none transition-[border-color,box-shadow,background-color] placeholder:text-[#98a2b3] hover:border-[#b8c4d2] focus:border-teal focus:ring-4 focus:ring-teal/10 sm:text-sm", className)}
      {...props}
    />
  );
}

export function Select({ className, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={clsx("min-h-12 w-full rounded-xl border border-line bg-white px-3.5 py-2.5 text-base text-ink shadow-sm outline-none transition-[border-color,box-shadow,background-color] hover:border-[#b8c4d2] focus:border-teal focus:ring-4 focus:ring-teal/10 sm:text-sm", className)}
      {...props}
    />
  );
}

export function TableWrap({ children }: { children: React.ReactNode }) {
  return <div className="overflow-x-auto rounded-2xl border border-line bg-white shadow-card">{children}</div>;
}

export function Th({ children }: { children: React.ReactNode }) {
  return <th className="whitespace-nowrap px-4 py-3 text-left text-[11px] font-extrabold uppercase tracking-[0.08em] text-muted">{children}</th>;
}

export function Td({ children, className }: { children: React.ReactNode; className?: string }) {
  return <td className={clsx("max-w-[240px] px-4 py-3.5 text-sm text-ink", className)}>{children}</td>;
}
