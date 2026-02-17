import { Poppins } from 'next/font/google'
import './globals.css'
import LayoutWrapper from './LayoutWrapper'

const font = Poppins({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
})

export const metadata = {
  title: 'Nexacore - Future Company Building innovative Software Solutions',
  description: 'Nexacore is an innovative software company building solutions for the future.',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang='en' suppressHydrationWarning>
      <body className={`${font.className}`}>
        <LayoutWrapper>{children}</LayoutWrapper>
      </body>
    </html>
  )
}
