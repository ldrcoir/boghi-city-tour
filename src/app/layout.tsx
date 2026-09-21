import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Toaster } from "@/components/ui/toaster";

export const metadata: Metadata = {
  title: "بوقی: تور شهرها — دانلود نسخه تست",
  description: "دانلود نسخه تست اندروید بازی بوقی: تور شهرها — فصل ۱ تهران با ۵۰ مأموریت، نیترو و کارگاه استاد فنر",
  icons: {
    icon: "/apk/boghi_icon.png",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#7c2d12",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fa" dir="rtl">
      <body className="font-body-fa antialiased">
        {children}
        <Toaster />
      </body>
    </html>
  );
}
