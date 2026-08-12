import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "League Hub Admin",
  description: "League Hub admin operations dashboard",
  icons: {
    icon: [{ url: "/league-hub-icon.png", type: "image/png" }],
    apple: "/league-hub-icon.png"
  }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
