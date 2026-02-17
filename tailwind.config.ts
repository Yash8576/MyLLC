import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "var(--background)",
        foreground: "var(--foreground)",
        primary: "var(--color-primary)",
        secondary: "var(--color-secondary)",
        grey: "var(--color-grey)",
      },
      fontSize: {
        '40': '2.5rem',
        '65': '4.063rem',
      },
      boxShadow: {
        'input': '0 63px 59px rgba(26, 33, 188, 0.1)',
        'card': '0 40px 20px rgba(0, 0, 0, 0.15)',
      },
    },
  },
  plugins: [],
};

export default config;
