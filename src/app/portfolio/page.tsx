'use client'
import React, { useEffect } from 'react'
import PortfolioMain from '../components/Portfolio/PortfolioMain'
import Expertise from '../components/Portfolio/Expertise'
import Timeline from '../components/Portfolio/Timeline'
import Project from '../components/Portfolio/Project'
import Contact from '../components/Portfolio/Contact'
import PortfolioFooter from '../components/Portfolio/PortfolioFooter'
import FadeIn from '../components/Portfolio/FadeIn'

const PortfolioPage: React.FC = () => {
  useEffect(() => {
    window.scrollTo({top: 0, left: 0, behavior: 'smooth'});
  }, []);

  return (
    <div className="portfolio-page">
      <FadeIn transitionDuration={700}>
        <section id="main">
          <PortfolioMain/>
        </section>
        <section id="expertise">
          <Expertise/>
        </section>
        <section id="history">
          <Timeline/>
        </section>
        <section id="projects">
          <Project/>
        </section>
        <section id="contact">
          <Contact/>
        </section>
      </FadeIn>
      <PortfolioFooter />
    </div>
  )
}

export default PortfolioPage
