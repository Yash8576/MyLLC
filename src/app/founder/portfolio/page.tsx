'use client'
import React, { useEffect } from 'react'
import PortfolioMain from '@/app/components/Portfolio/PortfolioMain'
import Expertise from '@/app/components/Portfolio/Expertise'
import Timeline from '@/app/components/Portfolio/Timeline'
import Project from '@/app/components/Portfolio/Project'
import Contact from '@/app/components/Portfolio/Contact'
import PortfolioFooter from '@/app/components/Portfolio/PortfolioFooter'
import FadeIn from '@/app/components/Portfolio/FadeIn'

const FounderPortfolioPage: React.FC = () => {
  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'smooth' })
  }, [])

  return (
    <div className="portfolio-page">
      <FadeIn transitionDuration={700}>
        <section id="main">
          <PortfolioMain />
        </section>
        <section id="expertise">
          <Expertise />
        </section>
        <section id="history">
          <Timeline />
        </section>
        <section id="projects">
          <Project />
        </section>
        <section id="contact">
          <Contact />
        </section>
      </FadeIn>
      <PortfolioFooter />
    </div>
  )
}

export default FounderPortfolioPage
