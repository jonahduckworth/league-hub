import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Open announcement | League Hub",
  description: "Open this announcement in the League Hub mobile app.",
  robots: { index: false, follow: false },
};

export default function OpenAnnouncementPage() {
  return (
    <main className="app-link-page">
      <section className="app-link-card" aria-labelledby="app-link-title">
        <Image
          className="app-link-icon"
          src="/league-hub-icon.png"
          width={88}
          height={88}
          alt="League Hub"
          priority
        />
        <p className="app-link-eyebrow">League Hub announcement</p>
        <h1 id="app-link-title">Open this announcement in the app.</h1>
        <p>
          If League Hub is installed, return to the email and tap the link
          again. Otherwise, install the app through your organization&apos;s
          onboarding instructions.
        </p>
        <Link className="button button-primary" href="/">
          Visit League Hub
        </Link>
      </section>
    </main>
  );
}
