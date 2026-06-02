import { FooterLinkType } from '@/app/types/footerlink'
import { HeaderType } from '@/app/types/menu'
import { ProjectType } from '@/app/types/project'

export const HeaderData: HeaderType[] = [
  { label: 'Home', href: '/' },
  {
    label: 'Yaswanth',
    href: '/#yaswanth',
    submenu: [
      { label: 'Portfolio', href: '/yaswanth/portfolio' },
      { label: 'Resume', href: '/yaswanth/resume' },
    ],
  },
  { 
    label: 'Projects', 
    href: '/#projects',
    submenu: [
      { label: 'BuzzCart', href: '/projects/buzzcart' },
      { label: 'NexAlgo', href: '/projects/nexalgo' },
      { label: 'Nanolink', href: '/projects/nanolink' },
      { label: 'Todo App', href: '/projects/todo' },
      { label: 'Digital Clock', href: '/projects/digitalclock' },
    ]
  },
  { label: 'Contact Me', href: '/#contact' },
]

export const ProjectData: ProjectType[] = [
  {
    title: 'BuzzCart',
    description: 'A social commerce platform with Flutter web, Go services, product media, and real-time shopping flows.',
    imgSrc: '/images/portfolio/mock01.png',
    tags: ['Flutter', 'Go', 'Cloud Run'],
    status: 'Live',
    link: '/projects/buzzcart',
  },
  {
    title: 'NexAlgo',
    description: 'A shared-auth coding interview tracker with LeetCode-linked practice flows, language preferences, and editor-managed explanations.',
    imgSrc: '/images/portfolio/mock02.png',
    tags: ['Next.js', 'Firebase', 'LeetCode'],
    status: 'New',
    link: '/projects/nexalgo',
  },
  {
    title: 'Nanolink',
    description: 'A production URL shortener with Cloud Run, Cloud SQL Postgres, Firebase authentication, and saved link history.',
    imgSrc: '/images/portfolio/Nexa-core-modified.png',
    tags: ['Next.js', 'Cloud Run', 'Postgres'],
    status: 'Live',
    link: '/projects/nanolink',
  },
  {
    title: 'Todo Flow',
    description: 'A feature-rich task management app with Firebase authentication, real-time sync, and status tracking.',
    imgSrc: '/images/portfolio/mock02.png',
    tags: ['React', 'Firebase', 'Authentication'],
    status: 'Live',
    link: '/projects/todo',
  },
  {
    title: 'Digital Clock',
    description: 'A customizable digital clock with theme switching and adjustable sizing options.',
    imgSrc: '/images/portfolio/mock03.png',
    tags: ['React', 'UI/UX', 'Design'],
    status: 'Live',
    link: '/projects/digitalclock',
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
