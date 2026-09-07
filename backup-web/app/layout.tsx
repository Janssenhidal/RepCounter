import type { Metadata } from 'next';
import './backup.css';
export const metadata: Metadata = {
  title: 'Rep Counter — Backup & Restore',
  description: 'Save and restore your Rep Counter workout history.',
};
export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
