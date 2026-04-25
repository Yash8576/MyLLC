'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useState } from 'react'
import { HeaderType } from '@/app/types/menu'

const MobileHeaderLink = ({
  item,
  setNavbarOpen,
}: {
  item: HeaderType
  setNavbarOpen: (value: boolean) => void
}) => {
  const [isOpen, setIsOpen] = useState(false)
  const pathname = usePathname()

  const scrollToTop = (e: React.MouseEvent<HTMLAnchorElement>) => {
    if (item.href === '/' || item.href === '#') {
      if (pathname !== '/') {
        setNavbarOpen(false)
        return
      }

      e.preventDefault()
      setNavbarOpen(false)
      window.scrollTo({
        top: 0,
        behavior: 'smooth',
      })
    } else {
      setNavbarOpen(false)
    }
  }

  if (item.submenu) {
    return (
      <div>
        <button
          type='button'
          onClick={() => setIsOpen(!isOpen)}
          className='w-full appearance-none border-0 bg-transparent p-0 text-left text-black hover:text-primary text-lg font-medium transition-colors duration-300 py-3 flex items-center justify-between'>
          {item.label}
          <svg
            aria-hidden='true'
            viewBox='0 0 16 16'
            className={`h-5 w-5 transition-transform duration-300 ${isOpen ? 'rotate-180' : ''}`}
            fill='none'
            stroke='currentColor'
            strokeWidth='1.5'
            strokeLinecap='round'
            strokeLinejoin='round'>
            <path d='M4 6l4 4 4-4' />
          </svg>
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
