'use client'
import React, { useState } from "react";
import './styles/Project.scss';

function Project() {
    const [expandedProject, setExpandedProject] = useState<number | null>(null);

    const toggleDescription = (projectId: number) => {
        setExpandedProject(expandedProject === projectId ? null : projectId);
    };

    return(
    <div className="projects-container" id="projects">
        <h1>Projects</h1>
        <div className="projects-grid">
            <div className="project">
                <a href="https://github.com/Yash8576/BuzzCart" target="_blank" rel="noreferrer" className="project-image-link">
                    <img src="/images/portfolio/mock01.png" className="project-thumbnail" alt="BuzzCart thumbnail"/>
                </a>
                <div className="project-info">
                    <a href="https://github.com/Yash8576/BuzzCart" target="_blank" rel="noreferrer">
                        <h2>BuzzCart (Like2Buy)</h2>
                    </a>
                    <button 
                        className="description-toggle"
                        onClick={() => toggleDescription(1)}
                        aria-expanded={expandedProject === 1}
                    >
                        {expandedProject === 1 ? 'Show Less ▲' : 'Show Description ▼'}
                    </button>
                    <div className={`project-description ${expandedProject === 1 ? 'expanded' : ''}`}>
                        <p>Production-grade social commerce platform with Flutter frontend and Go backend, featuring video reels, shopping integration, and 20+ RESTful APIs. Architected microservices backend using Go/Gin framework, PostgreSQL, MongoDB, and MinIO S3-compatible storage, all containerized with Docker & Kubernetes. Built RAG-powered chatbot service using FastAPI with ChromaDB vector database and OpenAI integration, supporting multiple document formats and maintaining conversation history.</p>
                    </div>
                </div>
            </div>
            <div className="project">
                <a href="https://github.com/Yash8576/RideShareApp" target="_blank" rel="noreferrer" className="project-image-link">
                    <img src="/images/portfolio/mock02.png" className="project-thumbnail" alt="RideShare App thumbnail"/>
                </a>
                <div className="project-info">
                    <a href="https://github.com/Yash8576/RideShareApp" target="_blank" rel="noreferrer">
                        <h2>RideShare App</h2>
                    </a>
                    <button 
                        className="description-toggle"
                        onClick={() => toggleDescription(2)}
                        aria-expanded={expandedProject === 2}
                    >
                        {expandedProject === 2 ? 'Show Less ▲' : 'Show Description ▼'}
                    </button>
                    <div className={`project-description ${expandedProject === 2 ? 'expanded' : ''}`}>
                        <p>Engineered ride-sharing Android application using Java with real-time location tracking, automated ride matching, secure payment integration, and driver-passenger communication. Established Firebase Authentication for secure user management and Firestore for distributed data storage. Leveraged Google Maps API achieving 95% location accuracy and optimized routing. Managed version control using Git workflows with branching and pull requests, resolving 20+ merge conflicts across 50+ commits.</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
    );
}

export default Project;
