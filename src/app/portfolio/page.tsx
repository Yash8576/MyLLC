'use client'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

const PortfolioPage = () => {
  const router = useRouter()

  useEffect(() => {
    router.replace('/founder/portfolio')
  }, [router])

  return null
}

export default PortfolioPage
