'use client'
import React from "react";
import GitHubIcon from '@mui/icons-material/GitHub';
import LinkedInIcon from '@mui/icons-material/LinkedIn';
import './styles/Footer.scss'

function PortfolioFooter() {
  return (
    <footer>
      <div>
        <a href="https://github.com/Yash8576" target="_blank" rel="noreferrer"><GitHubIcon/></a>
        <a href="https://www.linkedin.com/in/yaswantravitejadammalapati/" target="_blank" rel="noreferrer"><LinkedInIcon/></a>
      </div>
      <p>A portfolio designed & built by <a href="https://github.com/Yash8576" target="_blank" rel="noreferrer">Yaswanth Ravi Teja</a> with 💜</p>
    </footer>
  );
}

export default PortfolioFooter;
