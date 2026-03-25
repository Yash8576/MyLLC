'use client'
import { ProjectData } from '@/app/data/siteData'
import Link from 'next/link'

const Projects = () => {
  const openSourceProjects = ProjectData.filter(
    (project) => project.category === 'Open Source'
  )
  const nexacoreOwnedProjects = ProjectData.filter(
    (project) => project.category === 'Nexacore Owned'
  )

  const renderProjectGrid = (projects: typeof ProjectData) => (
    <div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8'>
      {projects.map((project, index) => {
        const ProjectCard = (
          <div
            key={index}
            className='bg-white rounded-xl p-6 hover:shadow-card-shadow transition-all duration-300 cursor-pointer h-full'>
            <div className='mb-4'>
              <span className='inline-block bg-primary/10 text-primary px-4 py-2 rounded-full text-sm font-medium'>
                {project.status}
              </span>
            </div>
            <h3 className='mb-3'>{project.title}</h3>
            <p className='text-black/70 text-base mb-4'>
              {project.description}
            </p>
            <div className='flex flex-wrap gap-2'>
              {project.tags.map((tag, i) => (
                <span
                  key={i}
                  className='text-xs bg-slate-gray text-black/60 px-3 py-1 rounded-full'>
                  {tag}
                </span>
              ))}
            </div>
          </div>
        )

        return project.link ? (
          <Link href={project.link} key={index}>
            {ProjectCard}
          </Link>
        ) : (
          ProjectCard
        )
      })}
    </div>
  )

  return (
    <section id='projects' className='bg-slate-gray'>
      <div className='container'>
        <div className='text-center mb-12'>
          <h2 className='text-midnight_text mb-4'>Our Projects</h2>
          <div className='w-20 h-1 bg-primary mx-auto mb-6'></div>
          <p className='text-black/70 text-lg max-w-3xl mx-auto'>
            Explore the innovative projects we&apos;re building to shape the future of software.
          </p>
        </div>

        <div className='space-y-12'>
          <div>
            <h3 className='text-midnight_text mb-6'>Open Source</h3>
            {renderProjectGrid(openSourceProjects)}
          </div>

          <div>
            <h3 className='text-midnight_text mb-6'>Nexacore Owned</h3>
            {nexacoreOwnedProjects.length > 0 ? (
              renderProjectGrid(nexacoreOwnedProjects)
            ) : (
              <div className='bg-white rounded-xl p-6 text-black/60'>
                More Nexacore owned projects are coming soon.
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  )
}

export default Projects
