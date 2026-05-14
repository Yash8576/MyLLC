import { Poppins } from 'next/font/google'
import './globals.css'
import LayoutWrapper from './LayoutWrapper'

const font = Poppins({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
})

export const metadata = {
  title: 'Nexacore - Future-Driven Software Projects',
  description: 'Working on innovative software ideas and scalable digital products aimed at solving real-world problems.',
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
