'use client'
import type { Metadata } from 'next'
import Link from 'next/link'
import { useEffect, useRef, useState } from 'react'
import DarkModeIcon from '@mui/icons-material/DarkMode'
import LightModeIcon from '@mui/icons-material/LightMode'
import { Icon } from '@iconify/react/dist/iconify.js'
import './portfolio.scss'

const portfolioNavItems = [
  { label: 'Expertise', section: 'expertise' },
  { label: 'History', section: 'history' },
  { label: 'Projects', section: 'projects' },
  { label: 'Contact', section: 'contact' },
]

export default function PortfolioLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const [navbarOpen, setNavbarOpen] = useState(false)
  const [sticky, setSticky] = useState(false)
  const [darkMode, setDarkMode] = useState(true)
  const [mounted, setMounted] = useState(false)

  const mobileMenuRef = useRef<HTMLDivElement>(null)

  // Initialize theme from localStorage on mount
  useEffect(() => {
    setMounted(true)
    const savedTheme = localStorage.getItem('portfolioTheme')
    if (savedTheme) {
      setDarkMode(savedTheme === 'dark')
    }
  }, [])

  const scrollToSection = (sectionId: string) => {
    const element = document.getElementById(sectionId)
    if (element) {
      const headerOffset = 80
      const elementPosition = element.getBoundingClientRect().top
      const offsetPosition = elementPosition + window.pageYOffset - headerOffset

      window.scrollTo({
        top: offsetPosition,
        behavior: 'smooth'
      })
      setNavbarOpen(false)
    }
  }

  const toggleDarkMode = () => {
    const newMode = !darkMode
    setDarkMode(newMode)
    localStorage.setItem('portfolioTheme', newMode ? 'dark' : 'light')
    console.log('Theme toggled to:', newMode ? 'dark' : 'light')
  }

  useEffect(() => {
    // Data now imported directly for static export
  }, [])

  const handleScroll = () => {
    setSticky(window.scrollY >= 80)
  }

  const handleClickOutside = (event: MouseEvent) => {
    if (
      mobileMenuRef.current &&
      !mobileMenuRef.current.contains(event.target as Node) &&
      navbarOpen
    ) {
      setNavbarOpen(false)
    }
  }

  useEffect(() => {
    window.addEventListener('scroll', handleScroll)
    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      window.removeEventListener('scroll', handleScroll)
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [navbarOpen])

  useEffect(() => {
    if (navbarOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
  }, [navbarOpen])

  // Prevent hydration mismatch by not rendering theme-dependent content until mounted
  if (!mounted) {
    return (
      <div className="portfolio-layout dark-mode">
        <div className="portfolio-content">
          {children}
        </div>
      </div>
    )
  }

  return (
    <div className={`portfolio-layout ${darkMode ? 'dark-mode' : 'light-mode'}`}>
      <header
        className={`portfolio-header fixed top-0 z-40 w-full transition-all duration-300 ${
          sticky ? 'portfolio-header-sticky' : ''
        }`}>
        <div className='portfolio-header-container'>
          <div className='portfolio-header-left'>
            <Link href="/" className="back-to-nexacore">
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                width="20" 
                height="20" 
                viewBox="0 0 24 24" 
                fill="none" 
                stroke="currentColor" 
                strokeWidth="2" 
                strokeLinecap="round" 
                strokeLinejoin="round"
              >
                <path d="M19 12H5M12 19l-7-7 7-7"/>
              </svg>
              Back to Nexacore
            </Link>
          </div>
          
          <nav className='portfolio-nav-links'>
            {portfolioNavItems.map((item, index) => (
              <button 
                key={index} 
                onClick={() => scrollToSection(item.section)}
                className="portfolio-nav-link"
              >
                {item.label}
              </button>
            ))}
          </nav>

          <div className='portfolio-header-right'>
            <button
              onClick={toggleDarkMode}
              className='portfolio-theme-toggle'
              aria-label={darkMode ? 'Switch to light mode' : 'Switch to dark mode'}
              title={darkMode ? 'Switch to light mode' : 'Switch to dark mode'}
            >
              {darkMode ? (
                <LightModeIcon sx={{ fontSize: 24, color: 'white' }} />
              ) : (
                <DarkModeIcon sx={{ fontSize: 24, color: '#0d1116' }} />
              )}
            </button>
            <button
              onClick={() => setNavbarOpen(!navbarOpen)}
              className='portfolio-mobile-menu-btn'>
              <Icon icon='solar:hamburger-menu-linear' width={32} height={32} />
            </button>
          </div>
        </div>

        {navbarOpen && (
          <div className='fixed top-0 left-0 w-full h-full bg-black/70 flex justify-end z-50'>
            <div
              ref={mobileMenuRef}
              className='portfolio-mobile-menu'>
              <div className='portfolio-mobile-header'>
                <h3 className='text-white text-xl font-bold'>Menu</h3>
                <button
                  onClick={() => setNavbarOpen(false)}
                  className='portfolio-mobile-close'>
                  <Icon
                    icon='material-symbols:close-rounded'
                    width={32}
                    height={32}
                  />
                </button>
              </div>
              <nav className='portfolio-mobile-nav'>
                <Link 
                  href="/" 
                  className="portfolio-mobile-link"
                  onClick={() => setNavbarOpen(false)}
                >
                  <svg 
                    xmlns="http://www.w3.org/2000/svg" 
                    width="20" 
                    height="20" 
                    viewBox="0 0 24 24" 
                    fill="none" 
                    stroke="currentColor" 
                    strokeWidth="2" 
                    strokeLinecap="round" 
                    strokeLinejoin="round"
                  >
                    <path d="M19 12H5M12 19l-7-7 7-7"/>
                  </svg>
                  Back to Nexacore
                </Link>
                {portfolioNavItems.map((item, index) => (
                  <button
                    key={index}
                    onClick={() => scrollToSection(item.section)}
                    className="portfolio-mobile-link"
                  >
                    {item.label}
                  </button>
                ))}
                <button
                  onClick={toggleDarkMode}
                  className="portfolio-mobile-link portfolio-theme-link"
                >
                  {darkMode ? (
                    <>
                      <LightModeIcon sx={{ fontSize: 20, color: 'white' }} />
                      <span>Light Mode</span>
                    </>
                  ) : (
                    <>
                      <DarkModeIcon sx={{ fontSize: 20, color: '#0d1116' }} />
                      <span>Dark Mode</span>
                    </>
                  )}
                </button>
              </nav>
            </div>
          </div>
        )}
      </header>
      
      <div className="portfolio-content">
        {children}
      </div>
    </div>
  )
}
