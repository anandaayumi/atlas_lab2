import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = { title: 'Atlas CRM', description: 'Carteira de propostas comerciais Atlas' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="pt-BR"><body>{children}</body></html>;
}
