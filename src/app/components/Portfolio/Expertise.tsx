'use client'
import React from "react";
import '@fortawesome/free-regular-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faReact, faDocker, faPython } from '@fortawesome/free-brands-svg-icons';
import './styles/Expertise.scss';

const expertiseItems = [
    {
        icon: faReact,
        title: "Full Stack Development",
        description: "I build production-ready web and mobile products with clean frontend flows, reliable backend services, and practical database design.",
        stack: ["React", "Next.js", "Flutter", "Dart", "Go", "Java", "SQL", "PostgreSQL", "MongoDB", "Firebase"]
    },
    {
        icon: faDocker,
        title: "DevOps & Cloud Infrastructure",
        description: "I ship containerized services, automate deployments, and keep environments maintainable across local development and production systems.",
        stack: ["Docker", "Kubernetes", "Linux", "Git", "CI/CD", "REST APIs", "Microservices", "MinIO", "Shell/Bash"]
    },
    {
        icon: faPython,
        title: "AI/ML & LLM Solutions",
        description: "I design applied AI workflows with retrieval, model APIs, and backend orchestration for products that need useful intelligence.",
        stack: ["Python", "FastAPI", "OpenAI", "RAG", "LLMs", "Vector DBs", "ChromaDB", "Machine Learning", "Deep Learning"]
    }
];

function Expertise() {
    return (
    <div className="container" id="expertise">
        <div className="skills-container">
            <div className="section-heading">
                <h1>Expertise</h1>
                <p>Focused engineering across product development, infrastructure, and AI-powered systems.</p>
            </div>
            <div className="skills-grid">
                {expertiseItems.map((item) => (
                    <div className="skill" key={item.title}>
                        <div className="skill-icon">
                            <FontAwesomeIcon icon={item.icon} />
                        </div>
                        <h3>{item.title}</h3>
                        <p>{item.description}</p>
                        <div className="skill-stack" aria-label={`${item.title} technologies`}>
                            {item.stack.map((label) => (
                                <span key={label} className="skill-chip">{label}</span>
                            ))}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    </div>
    );
}

export default Expertise;
