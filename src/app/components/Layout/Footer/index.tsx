'use client'

import Link from 'next/link'
import Logo from '../Header/Logo'
import { Icon } from '@iconify/react/dist/iconify.js'
import { FooterLinkData } from '@/app/data/siteData'

const Footer = () => {
  const footerlink = FooterLinkData

  return (
    <footer className='bg-deep-slate pt-10'>
      <div className='container'>
        <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8 pb-10'>
          <div>
            <div className='mb-6'>
              <Logo />
            </div>
            <p className='text-black/70 text-base mb-6'>
              Building the future of software, one innovation at a time.
            </p>
            <div className='flex items-center gap-4'>
              <Link
                href='https://github.com'
                target='_blank'
                rel='noopener noreferrer'
                className='hover:text-primary text-black text-3xl'>
                <Icon icon='tabler:brand-github' />
              </Link>
              <Link
                href='https://linkedin.com'
                target='_blank'
                rel='noopener noreferrer'
                className='hover:text-primary text-black text-3xl'>
                <Icon icon='tabler:brand-linkedin' />
              </Link>
              <Link
                href='https://twitter.com'
                target='_blank'
                rel='noopener noreferrer'
                className='hover:text-primary text-black text-3xl'>
                <Icon icon='tabler:brand-twitter' />
              </Link>
            </div>
          </div>

          {footerlink.map((product, i) => (
            <div key={i} className='group relative'>
              <p className='text-black text-xl font-semibold mb-6'>
                {product.section}
              </p>
              <ul>
                {product.links.map((item, i) => (
                  <li key={i} className='mb-3'>
                    <Link
                      href={item.href}
                      className='text-black/60 hover:text-primary text-base font-normal'>
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}

          <div>
            <p className='text-black text-xl font-semibold mb-6'>
              Contact Info
            </p>
            <div className='flex flex-col gap-4'>
              <Link href='mailto:contact@nexacore.com' className='flex items-center w-fit'>
                <Icon
                  icon='solar:mailbox-bold'
                  className='text-primary text-2xl inline-block me-2'
                />
                <p className='text-black/60 hover:text-primary text-base'>
                  contact@nexacore.com
                </p>
              </Link>
            </div>
          </div>
        </div>

        <div className='mt-10 lg:flex items-center justify-between border-t border-black/10 py-5'>
          <p className='text-black/50 text-base text-center lg:text-start font-normal'>
            © {new Date().getFullYear()} Nexacore. All Rights Reserved.
          </p>
        </div>
      </div>
    </footer>
  )
}

export default Footer
