'use client'
import Link from "next/link";
import { usePathname } from 'next/navigation'

const Logo: React.FC = () => {
  const pathname = usePathname()

  const scrollToTop = (e: React.MouseEvent<HTMLAnchorElement>) => {
    if (pathname !== '/') {
      return
    }

    e.preventDefault()
    
    // Use native smooth scroll - instant, no delay, always smooth
    window.scrollTo({
      top: 0,
      behavior: 'smooth'
    })
  }

  return (
    <Link href="/" onClick={scrollToTop}>
      <h1 className="text-3xl font-bold text-primary">Nexacore</h1>
    </Link>
  );
};

export default Logo;
