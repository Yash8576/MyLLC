import { FooterLinkType } from '@/app/types/footerlink'
import { HeaderType } from '@/app/types/menu'
import { ProjectType } from '@/app/types/project'
import { NextResponse } from 'next/server'

export const dynamic = 'force-static'

const HeaderData: HeaderType[] = [
  { label: 'Home', href: '/' },
  { 
    label: 'Founder', 
    href: '/#founder',
    submenu: [
      { label: 'About', href: '/#founder' },
      { label: 'Portfolio', href: '/portfolio' },
      { label: 'Resume', href: '/#resume' },
    ]
  },
  { 
    label: 'Projects', 
    href: '/#projects',
    submenu: [
      { label: 'Project1', href: '/projects/project1' },
      { label: 'Project2', href: '/projects/project2' },
      { label: 'Project3', href: '/projects/project3' },
      { label: 'Project4', href: '/projects/project4' },
      { label: 'Project5', href: '/projects/project5' },
    ]
  },
  { label: 'Contact Me', href: '/#contact' },
]

const ProjectData: ProjectType[] = [
  {
    title: 'Coming Soon',
    description: 'Exciting projects are in development. Check back soon!',
    imgSrc: '/images/projects/placeholder.webp',
    tags: ['Innovation', 'Technology'],
    status: 'In Development',
  },
]

const FooterLinkData: FooterLinkType[] = [
  {
    section: 'Quick Links',
    links: [
      { label: 'Home', href: '/' },
      { label: 'Founder', href: '/#founder' },
      { label: 'Projects', href: '/#projects' },
      { label: 'Contact Me', href: '/#contact' },
    ],
  },
]

export const GET = () => {
  return NextResponse.json({
    HeaderData,
    ProjectData,
    FooterLinkData,
  })
}
