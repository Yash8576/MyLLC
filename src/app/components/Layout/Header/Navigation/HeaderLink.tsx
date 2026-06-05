'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useState } from 'react'
import { HeaderType } from '@/app/types/menu'

const HeaderLink = ({ item }: { item: HeaderType }) => {
  const [isOpen, setIsOpen] = useState(false)
  const pathname = usePathname()

  const handleSamePageScroll = (e: React.MouseEvent<HTMLAnchorElement>) => {
    if (item.href === '/' || item.href === '#') {
      if (pathname !== '/') {
        return
      }

      e.preventDefault()
      window.scrollTo({
        top: 0,
        behavior: 'smooth',
      })
      return
    }

    if (item.href.startsWith('/#') && pathname === '/') {
      const section = document.querySelector(item.href.slice(1))

      if (section) {
        e.preventDefault()
        section.scrollIntoView({ behavior: 'smooth' })
      }
    }
  }

  if (item.submenu) {
    return (
      <div
        className='relative group'
        onMouseEnter={() => setIsOpen(true)}
        onMouseLeave={() => setIsOpen(false)}>
        <Link
          href={item.href}
          onClick={handleSamePageScroll}
          className='text-black hover:text-primary text-base font-medium transition-colors duration-300 flex items-center gap-1 py-2'>
          {item.label}
          <svg
            aria-hidden='true'
            viewBox='0 0 16 16'
            className={`h-4 w-4 transition-transform duration-300 ${isOpen ? 'rotate-180' : ''}`}
            fill='none'
            stroke='currentColor'
            strokeWidth='1.5'
            strokeLinecap='round'
            strokeLinejoin='round'>
            <path d='M4 6l4 4 4-4' />
          </svg>
        </Link>
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
      onClick={handleSamePageScroll}
      className='text-black hover:text-primary text-base font-medium transition-all duration-300 hover:-translate-y-0.5 inline-block'>
      {item.label}
    </Link>
  )
}

export default HeaderLink
