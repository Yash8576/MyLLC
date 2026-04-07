'use client'
import React from "react";
import '@fortawesome/free-regular-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faBook, faBriefcase } from '@fortawesome/free-solid-svg-icons';
import { VerticalTimeline, VerticalTimelineElement }  from 'react-vertical-timeline-component';
import 'react-vertical-timeline-component/style.min.css';
import './styles/Timeline.scss'

function Timeline() {
  return (
    <div id="history">
      <div className="items-container">
        <h1>Education & Experience</h1>
        <VerticalTimeline>
          <VerticalTimelineElement
            className="vertical-timeline-element--work"
            contentStyle={{ background: 'white', color: 'rgb(39, 40, 34)' }}
            contentArrowStyle={{ borderRight: '7px solid  white' }}
            date="Jan 2026 - Present"
            iconStyle={{ background: '#5000ca', color: 'rgb(39, 40, 34)' }}
            icon={<FontAwesomeIcon icon={faBriefcase} />}
          >
            <h3 className="vertical-timeline-element-title">Software Engineer</h3>
            <h4 className="vertical-timeline-element-subtitle">University of Georgia, Athens, GA</h4>
            <p>
              Built a smart IoT system with Redis and InfluxDB.
            </p>
            <p>
              Built real-time web apps and containerized the stack with Docker.
            </p>
          </VerticalTimelineElement>
          <VerticalTimelineElement
            className="vertical-timeline-element--work"
            date="Aug 2025 - Dec 2025"
            iconStyle={{ background: '#5000ca', color: 'rgb(39, 40, 34)' }}
            icon={<FontAwesomeIcon icon={faBriefcase} />}
          >
            <h3 className="vertical-timeline-element-title">Embedded Systems Engineer</h3>
            <h4 className="vertical-timeline-element-subtitle">University of Georgia, Athens, GA</h4>
            <p>
              Designed ESP32-based monitoring systems with Python and GCP integration.
            </p>
            <p>
              Reduced form factor by 66% and validated the system in field use.
            </p>
          </VerticalTimelineElement>
          <VerticalTimelineElement
            className="vertical-timeline-element--work"
            date="Aug 2024 - May 2026"
            iconStyle={{ background: '#5000ca', color: 'rgb(39, 40, 34)' }}
            icon={<FontAwesomeIcon icon={faBook} />}
          >
            <h3 className="vertical-timeline-element-title">MS in Computer Science</h3>
            <h4 className="vertical-timeline-element-subtitle">University of Georgia, Athens, GA</h4>
            <p>
              CGPA: 3.95 | Focus: Mobile Development, AI/ML, Cloud Computing
            </p>
          </VerticalTimelineElement>
          <VerticalTimelineElement
            className="vertical-timeline-element--work"
            date="Dec 2020 - Jun 2024"
            iconStyle={{ background: '#5000ca', color: 'rgb(39, 40, 34)' }}
            icon={<FontAwesomeIcon icon={faBook} />}
          >
            <h3 className="vertical-timeline-element-title">Bachelor of Technology in Information Technology</h3>
            <h4 className="vertical-timeline-element-subtitle">NIT Raipur, India</h4>
            <p>
              CGPA: 8.21 | Focus: Algorithms, Database Systems, Machine Learning, Networks
            </p>
          </VerticalTimelineElement>
        </VerticalTimeline>
      </div>
    </div>
  );
}

export default Timeline;
