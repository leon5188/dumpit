import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "DumpIt. | Voice Brain Dump to Notion - ADHD Friendly Productivity App",
  description: "Tired of blank-page procrastination? Open your mic and dump chaotic thoughts. DumpIt. automatically filters noise, clones your tone, generates action item lists, and syncs directly to Notion in 1-click.",
  keywords: [
    "voice to notion",
    "brain dump template",
    "adhd productivity tool",
    "voice note taker",
    "mind map generator",
    "tone cloning AI",
    "notion sync automation"
  ],
  authors: [{ name: "DumpIt Team" }],
  openGraph: {
    title: "DumpIt. | Voice Brain Dump to Notion",
    description: "Tired of blank-page procrastination? Open your mic and dump chaotic thoughts. DumpIt. automatically filters noise, clones your tone, generates action items, and syncs directly to Notion in 1-click.",
    url: "https://dumpit.site",
    siteName: "DumpIt. - ADHD Brain Dump",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "DumpIt. | Voice Brain Dump to Notion",
    description: "Open your mic, dump chaotic thoughts. AI structures, tone-clones, and syncs to Notion in 1-click.",
  }
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
