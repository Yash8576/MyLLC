import React from "react";
import Hero from "@/app/components/Home/Hero";
import Projects from "@/app/components/Home/Projects";
import ContactForm from "@/app/components/ContactForm";

export default function Home() {
  return (
    <main>
      <Hero />
      <Projects />
      <ContactForm />
    </main>
  );
}
