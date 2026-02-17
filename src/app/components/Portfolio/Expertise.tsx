'use client'
import React from "react";
import '@fortawesome/free-regular-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faReact, faDocker, faPython } from '@fortawesome/free-brands-svg-icons';
import Chip from '@mui/material/Chip';
import './styles/Expertise.scss';

const labelsFirst = [
    "Python",
    "Java",
    "C++",
    "Go",
    "SQL",
    "Flutter",
    "Dart",
    "Shell/Bash",
    "PostgreSQL",
    "MongoDB",
    "Firebase"
];

const labelsSecond = [
    "Docker",
    "Kubernetes",
    "Git",
    "CI/CD",
    "Linux",
    "MinIO",
    "Android Studio",
    "RESTful APIs",
    "Microservices"
];

const labelsThird = [
    "Machine Learning",
    "Deep Learning",
    "LLMs",
    "RAG",
    "Vector Databases",
    "ChromaDB",
    "OpenAI",
    "FastAPI"
];

function Expertise() {
    return (
    <div className="container" id="expertise">
        <div className="skills-container">
            <h1>Expertise</h1>
            <div className="skills-grid">
                <div className="skill">
                    <FontAwesomeIcon icon={faReact} size="3x"/>
                    <h3>Full Stack Development</h3>
                    <p>I build scalable applications with modern tech stacks including mobile apps with Flutter, backend services with Go, and robust databases. Experienced in developing production-grade platforms with microservices architecture.</p>
                    <div className="flex-chips">
                        <span className="chip-title">Tech stack:</span>
                        {labelsFirst.map((label, index) => (
                            <Chip key={index} className='chip' label={label} />
                        ))}
                    </div>
                </div>

                <div className="skill">
                    <FontAwesomeIcon icon={faDocker} size="3x"/>
                    <h3>DevOps & Cloud Infrastructure</h3>
                    <p>Proficient in containerization, orchestration, and CI/CD pipelines. Experience with Docker, Kubernetes, and managing Linux systems. Skilled in automated deployments and infrastructure management.</p>
                    <div className="flex-chips">
                        <span className="chip-title">Tech stack:</span>
                        {labelsSecond.map((label, index) => (
                            <Chip key={index} className='chip' label={label} />
                        ))}
                    </div>
                </div>

                <div className="skill">
                    <FontAwesomeIcon icon={faPython} size="3x"/>
                    <h3>AI/ML & LLM Solutions</h3>
                    <p>Experienced in building agentic workflows, RAG-powered applications, and deploying ML/LLM models to production. Skilled in prompt engineering, vector databases, and implementing AI-driven solutions for real-world problems.</p>
                    <div className="flex-chips">
                        <span className="chip-title">Tech stack:</span>
                        {labelsThird.map((label, index) => (
                            <Chip key={index} className='chip' label={label} />
                        ))}
                    </div>
                </div>
            </div>
        </div>
    </div>
    );
}

export default Expertise;
