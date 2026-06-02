import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Nanolink",
  description: "Shorten URLs with optional account history.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
