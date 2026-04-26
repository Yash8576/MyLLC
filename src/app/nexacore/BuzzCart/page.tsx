'use client'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function BuzzCartHomeRedirectPage() {
  const router = useRouter()

  useEffect(() => {
    router.replace('/projects/buzzcart')
  }, [router])

  return null
}
