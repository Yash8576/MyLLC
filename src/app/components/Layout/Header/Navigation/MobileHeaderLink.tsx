'use client'
import Link from 'next/link'
import { useState } from 'react'
import { HeaderType } from '@/app/types/menu'
import { Icon } from '@iconify/react/dist/iconify.js'

const MobileHeaderLink = ({
  item,
  setNavbarOpen,
}: {
  item: HeaderType
  setNavbarOpen: (value: boolean) => void
}) => {
  const [isOpen, setIsOpen] = useState(false)

  const scrollToTop = (e: React.MouseEvent<HTMLAnchorElement>) => {
    // Only scroll to top if clicking Home or root link
    if (item.href === '/' || item.href === '#') {
      e.preventDefault()
      
      // Close mobile menu immediately
      setNavbarOpen(false)
      
      // Use native smooth scroll - instant, no delay, always smooth
      window.scrollTo({
        top: 0,
        behavior: 'smooth'
      })
    } else {
      setNavbarOpen(false)
    }
  }

  if (item.submenu) {
    return (
      <div>
        <button
          onClick={() => setIsOpen(!isOpen)}
          className='w-full text-left text-black hover:text-primary text-lg font-medium transition-colors duration-300 py-3 flex items-center justify-between'>
          {item.label}
          <Icon
            icon='solar:alt-arrow-down-linear'
            className={`transition-transform duration-300 ${isOpen ? 'rotate-180' : ''}`}
            width={20}
            height={20}
          />
        </button>
        {isOpen && (
          <div className='pl-4 pb-2'>
            {item.submenu.map((subitem, index) => (
              <Link
                key={index}
                href={subitem.href}
                onClick={() => setNavbarOpen(false)}
                className='block text-black/70 hover:text-primary text-base py-2 transition-colors duration-300'>
                {subitem.label}
              </Link>
            ))}
          </div>
        )}
      </div>
    )
  }

  return (
    <Link
      href={item.href}
      onClick={scrollToTop}
      className='text-black hover:text-primary text-lg font-medium transition-colors duration-300 py-3 block'>
      {item.label}
    </Link>
  )
}

export default MobileHeaderLink
