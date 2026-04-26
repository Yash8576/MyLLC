'use client'
import { useState, useEffect } from "react"
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import DigitalClock from "./DigitalClock"
import "./App.css"

export default function DigitalClockPage() {
  const pathname = usePathname()
  const router = useRouter()
  const isProjectsRoute = pathname?.startsWith('/projects/')

  useEffect(() => {
    if (pathname?.startsWith('/nexacore/')) {
      router.replace('/projects/digitalclock')
    }
  }, [pathname, router])

  const [theme, setTheme] = useState('light')
  const [isHovering, setIsHovering] = useState(false)
  const [clockSize, setClockSize] = useState(60)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
    const savedTheme = localStorage.getItem('clockTheme')
    const savedSize = localStorage.getItem('clockSize')
    if (savedTheme) setTheme(savedTheme)
    if (savedSize) setClockSize(parseInt(savedSize, 10))
  }, [])

  const toggleTheme = () => {
    const newTheme = theme === 'light' ? 'dark' : 'light'
    setTheme(newTheme)
    localStorage.setItem('clockTheme', newTheme)
  }

  const themeButtonContainerStyle = {
    position: 'relative' as const,
  }

  const handleSizeChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const newSize = parseInt(event.target.value, 10)
    setClockSize(newSize)
    localStorage.setItem('clockSize', newSize.toString())
  }

  const backgroundColor = theme === 'dark' ? 'black' : 'white'
  const textColor = theme === 'dark' ? '#1DB954 ' : 'black'
  const sliderColor = theme === 'dark' ? '#1DB954' : 'black'

  const tooltipStyle = {
    position: 'absolute' as const,
    bottom: '-75%',
    right: '0',
    transform: isHovering ? 'translateY(-10px)' : 'translateY(0)',
  
    backgroundColor: theme === 'dark' ? '#1C1C1C' : '#F5F5F7',
    color: textColor,
    padding: '5px 10px',
    borderRadius: '4px',
    whiteSpace: 'nowrap' as const,
    fontSize: '12px',

    opacity: isHovering ? 1 : 0,
    visibility: isHovering ? ('visible' as const) : ('hidden' as const),
    transition: 'opacity 0.2s, transform 0.2s',
  }

  const appStyle = {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: '100vh',
    height: '100vh',
    width: '100vw',
    backgroundColor: backgroundColor,
    color: textColor,
    transition: 'background-color 0.3s, color 0.3s',
    position: 'relative' as const,
    overflow: 'hidden',
  }

  const topBarStyle = {
    position: 'absolute' as const,
    top: '20px',
    left: '20px',
    right: '20px',
    width: 'auto',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    zIndex: 100,
    paddingLeft: '10px',
    paddingRight: '10px',
  }

  const sizeControlStyle = {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    fontSize: '14px',
    color: textColor,
    position: 'absolute' as const,
    left: '50%',
    transform: 'translateX(-50%)',
  }

  const buttonStyle = {
    backgroundColor: 'transparent',
    border: 'none',
    color: textColor,
    fontSize: '24px',
    cursor: 'pointer',
  }

  if (pathname?.startsWith('/nexacore/')) return null
  if (!mounted) return null

  return ( 
    <>
      <style jsx global>{`
        body, html {
          overflow: hidden;
          margin: 0;
          padding: 0;
          width: 100%;
          height: 100%;
        }

        .back-to-nexacore {
          display: inline-flex;
          align-items: center;
          gap: 0.4rem;

          color: #5000ca;
          text-decoration: none;
          padding: 0.5rem 1rem;
          border-radius: 0.5rem;
          background: rgba(80, 0, 202, 0.2);

          font-size: 0.9rem;
          font-weight: 500;

          transition: all 0.25s ease;
        }

        .back-to-nexacore:hover {
          background: rgba(80, 0, 202, 0.4);
          color: #5000ca;
          transform: translateX(-4px);
        }

        .app-wrapper.dark .back-to-nexacore {
          color: white !important;
        }

        .app-wrapper.dark .back-to-nexacore:hover {
          color: white !important;
        }

        .back-to-nexacore svg {
          transition: transform 0.25s ease;
        }

        .back-to-nexacore:hover svg {
          transform: translateX(-3px);
        }
      `}</style>
      <div className={`app-wrapper ${theme}`} style={appStyle}>
        <div style={topBarStyle}>
        <Link href="/" className="back-to-nexacore">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5"/>
            <path d="M12 19l-7-7 7-7"/>
          </svg>
          {isProjectsRoute ? 'Back to Projects' : 'Back to Nexacore'}
        </Link>
        <div style={sizeControlStyle}>
          <span style={{ opacity: 0.8 }}>A</span>
          <input
            type="range"
            min="30"
            max="120"
            value={clockSize}
            onChange={handleSizeChange}
            style={{
              cursor: 'pointer',
              width: '100px',
            }}
          />
          <span style={{ fontSize: '20px', opacity: 0.8 }}>A</span>
        </div>
        <div
          style={themeButtonContainerStyle}
          onMouseEnter={() => setIsHovering(true)}
          onMouseLeave={() => setIsHovering(false)}
        >
          <div style={{...tooltipStyle, fontWeight: 'bold'}}>
            switch to {theme === 'light' ? 'Dark Mode ☾' : 'Light Mode ☀︎'}
          </div>
          <button style={buttonStyle} onClick={toggleTheme}>
            {theme === 'light' ? '☾' : '☀︎'}
          </button>
        </div>
      </div>
      <DigitalClock textColor={textColor} clockSize={clockSize} />
    </div>
    </>
  )
}
