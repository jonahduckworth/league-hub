import Image from "next/image";
import Link from "next/link";
import { ReactNode } from "react";

type LegalPageProps = {
  eyebrow: string;
  title: string;
  intro: string;
  updated: string;
  children: ReactNode;
};

export function LegalPage({ eyebrow, title, intro, updated, children }: LegalPageProps) {
  return (
    <main className="legal-page">
      <header className="legal-header">
        <Link className="brand" href="/" aria-label="League Hub home">
          <span className="brand-mark" aria-hidden="true">
            <Image src="/league-hub-icon.png" width={42} height={42} alt="" priority />
          </span>
          <span>League Hub</span>
        </Link>
        <Link className="legal-back" href="/">Back to League Hub</Link>
      </header>
      <section className="legal-hero">
        <p className="eyebrow eyebrow-light">{eyebrow}</p>
        <h1>{title}</h1>
        <p>{intro}</p>
        <span>Last updated {updated}</span>
      </section>
      <article className="legal-content">{children}</article>
      <footer className="legal-footer">
        <p>© {new Date().getFullYear()} League Hub, a product of JD Builds.</p>
        <nav aria-label="Legal links">
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
          <Link href="/support">Support</Link>
        </nav>
      </footer>
    </main>
  );
}
