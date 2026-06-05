'use client'
import React from "react";
import './styles/Project.scss';

const projects = [
    {
        title: "BuzzCart",
        image: "/images/portfolio/Buzzcart-image.png",
        href: "https://nexacoreglobal.org/projects/buzzcart",
        description: "A social commerce platform with video-first shopping, product discovery, authentication, backend APIs, and storage workflows built for a production-style deployment.",
        tech: ["Flutter", "Go", "PostgreSQL", "MongoDB", "MinIO", "Docker", "Kubernetes", "FastAPI", "OpenAI"]
    },
    {
        title: "NexAlgo",
        image: "/images/portfolio/NexAlgo.png",
        href: "https://nexacoreglobal.org/projects/nexalgo",
        description: "A coding practice and interview preparation product that combines problem workflows, generated guidance, extension tooling, and backend services.",
        tech: ["Next.js", "TypeScript", "Firebase", "Cloud Run", "Node.js", "Chrome Extension"]
    },
    {
        title: "NanoLink",
        image: "/images/portfolio/NanoLink.png",
        href: "https://nexacoreglobal.org/projects/nanolink",
        description: "A lightweight link management experience focused on clean sharing flows, fast redirects, analytics-ready architecture, and a polished frontend.",
        tech: ["Next.js", "TypeScript", "Firebase", "Tailwind CSS", "API Routes"]
    },
    {
        title: "Todo",
        image: "/images/portfolio/ToDo.png",
        href: "https://nexacoreglobal.org/projects/todo",
        description: "A task management app with authentication, task state handling, and a simple interface for creating, tracking, and completing daily work.",
        tech: ["React", "Firebase", "CSS", "Authentication", "Firestore"]
    },
    {
        title: "Digital Clock",
        image: "/images/portfolio/DigitalClock.png",
        href: "https://nexacoreglobal.org/projects/digitalclock",
        description: "A focused clock interface with responsive presentation and clean time display, built as a compact frontend utility project.",
        tech: ["React", "TypeScript", "CSS", "Responsive UI"]
    }
];

function Project() {
    return(
    <div className="projects-container" id="projects">
        <div className="section-heading">
            <h1>Projects</h1>
            <p>Nexacore products and focused builds, presented with the technologies behind each one.</p>
        </div>
        <div className="projects-list">
            {projects.map((project, index) => (
                <article className="project-row" key={project.title}>
                    <a href={project.href} target="_blank" rel="noreferrer" className="project-media" aria-label={`Open ${project.title}`}>
                        <img src={project.image} className="project-thumbnail" alt={`${project.title} screenshot`}/>
                    </a>
                    <div className="project-info">
                        <span className="project-number">{String(index + 1).padStart(2, "0")}</span>
                        <a href={project.href} target="_blank" rel="noreferrer">
                            <h2>{project.title}</h2>
                        </a>
                        <p>{project.description}</p>
                        <div className="project-tech" aria-label={`${project.title} technologies`}>
                            {project.tech.map((tech) => (
                                <span key={tech}>{tech}</span>
                            ))}
                        </div>
                    </div>
                </article>
            ))}
        </div>
    </div>
    );
}

export default Project;
