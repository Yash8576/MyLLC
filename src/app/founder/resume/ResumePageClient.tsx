'use client'

import dynamic from 'next/dynamic'

const ResumeViewer = dynamic(() => import('./ResumeViewerContent'), { ssr: false })

export default function ResumePageClient() {
  return <ResumeViewer />
}
