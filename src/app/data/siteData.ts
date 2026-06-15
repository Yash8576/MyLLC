import { FooterLinkType } from '@/app/types/footerlink'
import { HeaderType } from '@/app/types/menu'
import { ProjectType } from '@/app/types/project'

export const HeaderData: HeaderType[] = [
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
    description: 'A social shopping app where people can discover products through posts and videos, message sellers, save items, and shop with reviews that feel connected to real buyers.',
    imgSrc: '/images/portfolio/mock01.png',
    status: 'Live',
    link: '/projects/buzzcart',
  },
  {
    title: 'NexAlgo',
    description: 'A coding practice workspace that helps users track interview problems, organize their progress, review explanations, and keep practice notes in one place.',
    imgSrc: '/images/portfolio/mock02.png',
    status: 'New',
    link: '/projects/nexalgo',
  },
  {
    title: 'Nanolink',
    description: 'A simple link shortener for turning long URLs into clean, shareable links, with account-based history so users can come back and manage what they created.',
    imgSrc: '/images/portfolio/Nexa-core-modified.png',
    status: 'Live',
    link: '/projects/nanolink',
  },
  {
    title: 'Todo Flow',
    description: 'A task manager for planning work, tracking what is pending or complete, and keeping personal tasks organized across sessions.',
    imgSrc: '/images/portfolio/mock02.png',
    status: 'Live',
    link: '/projects/todo',
  },
  {
    title: 'Digital Clock',
    description: 'A focused digital clock that lets users adjust the look and size for desks, displays, study sessions, or a clean browser clock view.',
    imgSrc: '/images/portfolio/mock03.png',
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
