'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import DigitalClock from './DigitalClock'
import './ClockPage.css'

export default function DigitalClockPage() {
  const pathname = usePathname()
  const router = useRouter()
  const isProjectsRoute = pathname?.startsWith('/projects/')
  const backLinkHref = isProjectsRoute ? '/#projects' : '/'

  useEffect(() => {
    if (pathname?.startsWith('/nexacore/')) router.replace('/projects/digitalclock')
  }, [pathname, router])

  const [theme, setTheme] = useState('light')
  const [clockSize, setClockSize] = useState(72)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
    const savedTheme = localStorage.getItem('clockTheme')
    const savedSize  = localStorage.getItem('clockSize')
    if (savedTheme) setTheme(savedTheme)
    if (savedSize)  setClockSize(parseInt(savedSize, 10))
  }, [])

  const toggleTheme = () => {
    const next = theme === 'light' ? 'dark' : 'light'
    setTheme(next)
    localStorage.setItem('clockTheme', next)
  }

  const handleSizeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const v = parseInt(e.target.value, 10)
    setClockSize(v)
    localStorage.setItem('clockSize', String(v))
  }

  if (pathname?.startsWith('/nexacore/')) return null
  if (!mounted) return null

  return (
    <div className={`clock-page clock-page-${theme}`}>

      {/* ── Top bar ── */}
      <header className="clock-topbar">
        <Link href={backLinkHref} className="back-to-nexacore">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5"/><path d="M12 19l-7-7 7-7"/>
          </svg>
          <span className="back-label">{isProjectsRoute ? 'Back to Projects' : 'Back to Nexacore'}</span>
        </Link>

        <div className="clock-size-control">
          <span className="clock-size-label clock-size-label-sm">A</span>
          <input
            type="range"
            min="36"
            max="130"
            value={clockSize}
            onChange={handleSizeChange}
            className="clock-slider"
            aria-label="Clock size"
          />
          <span className="clock-size-label clock-size-label-lg">A</span>
        </div>

        <button type="button" onClick={toggleTheme} className="clock-theme-btn" aria-label="Toggle theme">
          {theme === 'light' ? '☾' : '☀︎'}
        </button>
      </header>

      {/* ── Clock ── */}
      <main className="clock-stage">
        <DigitalClock clockSize={clockSize} theme={theme} />
      </main>
    </div>
  )
}
