'use client'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function BuzzCartLoginRedirectPage() {
  const router = useRouter()

  useEffect(() => {
    router.replace('/projects/buzzcart/login')
  }, [router])

  return null
}
