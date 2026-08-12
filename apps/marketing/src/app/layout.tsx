import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://leaguehub.ca"),
  title: "League Hub | Your league, connected",
  description:
    "Schedules, chats, announcements, policies, contacts, and league operations in one clean mobile app.",
  openGraph: {
    title: "League Hub | Your league, connected",
    description:
      "One trusted place for every game, update, conversation, and league resource.",
    type: "website",
    locale: "en_CA",
    siteName: "League Hub",
  },
  twitter: {
    card: "summary_large_image",
    title: "League Hub | Your league, connected",
    description:
      "One trusted place for every game, update, conversation, and league resource.",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#06182c",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
