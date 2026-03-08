'use client'
import { useState } from "react"
import Link from 'next/link'
import DigitalClock from "./DigitalClock"
import "./App.css"

export default function DigitalClockPage() {
  const [theme, setTheme] = useState('light')
  const [isHovering, setIsHovering] = useState(false)
  const [isMenuOpen, setIsMenuOpen] = useState(false)
  const [clockSize, setClockSize] = useState(60)

  const toggleTheme = () => {
    setTheme(currentTheme => (currentTheme === 'light' ? 'dark' : 'light'))
  }

  const toggleMenu = () => {
    setIsMenuOpen(current => !current)
  }

  const themeButtonContainerStyle = {
    position: 'relative' as const,
  }

  const handleSizeChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setClockSize(parseInt(event.target.value, 10))
  }

  const backgroundColor = theme === 'dark' ? 'black' : 'white'
  const textColor = theme === 'dark' ? '#1DB954 ' : 'black'
  const menuColor = theme === 'dark' ? 'black' : '#F5F5F7'
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

  const menuStyle = {
    position: 'fixed' as const,
    top: 0,
    left: 0,
    height: '100%',
    width: '250px',
    backgroundColor: menuColor,
    padding: '20px',
    transform: isMenuOpen ? 'translateX(0)' : 'translateX(-100%)',
    transition: 'transform 0.3s, background-color 0.3s',
    zIndex: 1000,
    boxShadow: isMenuOpen ? '1px 0 3px rgba(255, 255, 255, 0.5)' : 'none',
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
      `}</style>
      <div style={appStyle}>
        <div style={topBarStyle}>
        <button style={buttonStyle} onClick={toggleMenu}>
          ☰
        </button>
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
      <div style={menuStyle}>
        <h2>Menu</h2>
        <Link href="/" style={{
          display: 'inline-block',
          marginTop: '20px',
          padding: '10px 20px',
          background: '#3498db',
          color: 'white',
          textDecoration: 'none',
          borderRadius: '5px',
          fontWeight: 500,
        }}>
          ← Back to Nexacore
        </Link>
        <p style={{marginTop: '40px'}}>This is a sliding menu.</p>
        <ul>
          <li>Option 1</li>
          <li>Option 2</li>
          <li>Option 3</li>
        </ul>
        <button style={{...buttonStyle, color: textColor, position: 'absolute' as const, top: '30px', left: '170px'}} onClick={toggleMenu}>
          close
        </button>
      </div>
      <DigitalClock textColor={textColor} clockSize={clockSize} />
    </div>
    </>
  )
}
