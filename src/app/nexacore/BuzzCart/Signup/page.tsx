'use client'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function BuzzCartSignupRedirectPage() {
  const router = useRouter()

  useEffect(() => {
    router.replace('/projects/buzzcart/signup')
  }, [router])

  return null
}
