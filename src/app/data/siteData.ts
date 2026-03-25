import { FooterLinkType } from '@/app/types/footerlink'
import { HeaderType } from '@/app/types/menu'
import { ProjectType } from '@/app/types/project'

export const HeaderData: HeaderType[] = [
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
      { label: 'Todo App', href: '/nexacore/todo' },
      { label: 'Digital Clock', href: '/nexacore/digitalclock' },
    ]
  },
  { label: 'Contact Me', href: '/#contact' },
]

export const ProjectData: ProjectType[] = [
  {
    title: 'Todo Flow',
    description: 'A feature-rich task management app with Firebase authentication, real-time sync, and status tracking.',
    imgSrc: '/images/projects/todo-app.webp',
    tags: ['React', 'Firebase', 'Authentication'],
    status: 'Live',
    category: 'Open Source',
    link: '/nexacore/todo',
  },
  {
    title: 'Digital Clock',
    description: 'A customizable digital clock with theme switching and adjustable sizing options.',
    imgSrc: '/images/projects/digital-clock.webp',
    tags: ['React', 'UI/UX', 'Design'],
    status: 'Live',
    category: 'Open Source',
    link: '/nexacore/digitalclock',
  },
]

export const FooterLinkData: FooterLinkType[] = [
  {
    section: 'Quick Links',
    links: [
      { label: 'Home', href: '/' },
      { label: 'Projects', href: '/#projects' },
      { label: 'Contact Me', href: '/#contact' },
    ],
  },
]
