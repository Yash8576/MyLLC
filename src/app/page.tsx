import React from "react";
import Hero from "@/app/components/Home/Hero";
import Founder from "@/app/components/Home/Founder";
import Projects from "@/app/components/Home/Projects";
import ContactForm from "@/app/components/ContactForm";

export default function Home() {
  return (
    <main>
      <Hero />
      <Founder />
      <Projects />
      <ContactForm />
    </main>
  );
}
