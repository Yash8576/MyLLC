'use client'
import React from "react";
import GitHubIcon from '@mui/icons-material/GitHub';
import LinkedInIcon from '@mui/icons-material/LinkedIn';
import './styles/Main.scss';

function PortfolioMain() {
  return (
    <div className="container">
      <div className="about-section">
        <div className="image-wrapper">
          <img src="/images/portfolio/Yaswanth-Profile-Picture.png" alt="Avatar" />
        </div>
        <div className="content">
          <div className="social_icons">
            <a href="https://github.com/Yash8576" target="_blank" rel="noreferrer"><GitHubIcon/></a>
            <a href="https://www.linkedin.com/in/yaswantravitejadammalapati/" target="_blank" rel="noreferrer"><LinkedInIcon/></a>
          </div>
          <h1>Yaswanth Ravi Teja Dammalapati</h1>
          <p>Systems Engineer | AI/ML Developer</p>

          <div className="mobile_social_icons">
            <a href="https://github.com/Yash8576" target="_blank" rel="noreferrer"><GitHubIcon/></a>
            <a href="https://www.linkedin.com/in/yaswantravitejadammalapati/" target="_blank" rel="noreferrer"><LinkedInIcon/></a>
          </div>
        </div>
      </div>
    </div>
  );
}

export default PortfolioMain;
