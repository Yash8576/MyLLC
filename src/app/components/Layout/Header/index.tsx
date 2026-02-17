'use client'
import { useEffect, useRef, useState } from 'react'
import Logo from './Logo'
import HeaderLink from '../Header/Navigation/HeaderLink'
import MobileHeaderLink from '../Header/Navigation/MobileHeaderLink'
import { Icon } from '@iconify/react/dist/iconify.js'
import { HeaderData } from '@/app/data/siteData'

const Header: React.FC = () => {
  const [navbarOpen, setNavbarOpen] = useState(false)
  const [sticky, setSticky] = useState(false)
  const navLink = HeaderData

  const mobileMenuRef = useRef<HTMLDivElement>(null)

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

  return (
    <header
      className={`fixed top-0 z-40 w-full transition-all duration-300 ${
        sticky ? 'bg-white shadow-lg py-2' : 'bg-white/80 backdrop-blur-sm shadow-none py-4'
      }`}>
      <div className='container'>
        <div className='flex items-center justify-between'>
          <Logo />
          <nav className='hidden lg:flex items-center lg:gap-6 xl:gap-8'>
            {navLink.map((item, index) => (
              <HeaderLink key={index} item={item} />
            ))}
          </nav>
          <div className='flex items-center gap-4 lg:hidden'>
            <button
              onClick={() => setNavbarOpen(!navbarOpen)}
              className='text-black hover:text-primary'>
              <Icon icon='solar:hamburger-menu-linear' width={32} height={32} />
            </button>
          </div>
        </div>
      </div>

      {navbarOpen && (
        <div className='fixed top-0 left-0 w-full h-full bg-black/50 flex justify-end z-50 lg:hidden'>
          <div
            ref={mobileMenuRef}
            className='w-3/4 max-w-sm bg-white h-full overflow-y-auto'>
            <div className='flex justify-between items-center p-6 border-b'>
              <Logo />
              <button
                onClick={() => setNavbarOpen(false)}
                className='text-black hover:text-primary'>
                <Icon
                  icon='material-symbols:close-rounded'
                  width={32}
                  height={32}
                />
              </button>
            </div>
            <nav className='flex flex-col p-6'>
              {navLink.map((item, index) => (
                <MobileHeaderLink
                  key={index}
                  item={item}
                  setNavbarOpen={setNavbarOpen}
                />
              ))}
            </nav>
          </div>
        </div>
      )}
    </header>
  )
}

export default Header
