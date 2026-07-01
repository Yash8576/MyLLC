'use client'

import { useEffect } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import BenchmarkTool from './BenchmarkTool'
import './Benchmark.css'

export default function BenchmarkPage() {
  const pathname = usePathname()
  const router = useRouter()
  const isProjectsRoute = pathname?.startsWith('/projects/')
  const backLinkHref = isProjectsRoute ? '/#projects' : '/'

  useEffect(() => {
    if (pathname?.startsWith('/nexacore/')) router.replace('/projects/benchmark')
  }, [pathname, router])

  if (pathname?.startsWith('/nexacore/')) return null

  return (
    <div className="bx-shell">
      <div className="bx-topbar">
        <Link href={backLinkHref} className="bx-back">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5" /><path d="M12 19l-7-7 7-7" />
          </svg>
          <span>{isProjectsRoute ? 'Back to Projects' : 'Back to Nexacore'}</span>
        </Link>
        <span className="bx-topbar-title">NexaBench · Device Diagnostics</span>
      </div>
      <BenchmarkTool />
    </div>
  )
}
