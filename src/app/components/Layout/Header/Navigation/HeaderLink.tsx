'use client'
import Link from 'next/link'
import { useState } from 'react'
import { HeaderType } from '@/app/types/menu'
import { Icon } from '@iconify/react/dist/iconify.js'

const HeaderLink = ({ item }: { item: HeaderType }) => {
  const [isOpen, setIsOpen] = useState(false)

  const scrollToTop = (e: React.MouseEvent<HTMLAnchorElement>) => {
    // Only scroll to top if clicking Home or root link
    if (item.href === '/' || item.href === '#') {
      e.preventDefault()
      
      // Use native smooth scroll - instant, no delay, always smooth
      window.scrollTo({
        top: 0,
        behavior: 'smooth'
      })
    }
  }

  if (item.submenu) {
    return (
      <div
        className='relative group'
        onMouseEnter={() => setIsOpen(true)}
        onMouseLeave={() => setIsOpen(false)}>
        <button className='text-black hover:text-primary text-base font-medium transition-colors duration-300 flex items-center gap-1 py-2'>
          {item.label}
          <Icon
            icon='solar:alt-arrow-down-linear'
            className={`transition-transform duration-300 ${isOpen ? 'rotate-180' : ''}`}
            width={16}
            height={16}
          />
        </button>
        {isOpen && (
          <div className='absolute top-full left-0 pt-2'>
            <div className='bg-white shadow-lg rounded-lg py-2 min-w-[180px] z-50'>
              {item.submenu.map((subitem, index) => (
                <Link
                  key={index}
                  href={subitem.href}
                  className='block px-6 py-2 text-black hover:text-primary hover:bg-gray-50 text-base transition-all duration-300'>
                  {subitem.label}
                </Link>
              ))}
            </div>
          </div>
        )}
      </div>
    )
  }

  return (
    <Link
      href={item.href}
      onClick={scrollToTop}
      className='text-black hover:text-primary text-base font-medium transition-all duration-300 hover:-translate-y-0.5 inline-block'>
      {item.label}
    </Link>
  )
}

export default HeaderLink
