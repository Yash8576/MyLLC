'use client'
import { usePathname } from 'next/navigation'
import Header from '@/app/components/Layout/Header'
import Footer from '@/app/components/Layout/Footer'

export default function LayoutWrapper({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const isPortfolio = pathname === '/portfolio'
  const isNexacoreProject = pathname?.startsWith('/nexacore/')
  const isProjectApp =
    pathname === '/projects/todo' ||
    pathname === '/projects/digitalclock' ||
    pathname === '/projects/buzzcart' ||
    pathname === '/projects/buzzcart/login' ||
    pathname === '/projects/buzzcart/signup'

  if (isPortfolio || isNexacoreProject || isProjectApp) {
    return <>{children}</>
  }

  return (
    <>
      <Header />
      {children}
      <Footer />
    </>
  )
}
