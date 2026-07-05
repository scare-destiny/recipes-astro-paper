import React, { type FormEvent, useState, useId } from "react";
// import Link from 'next/link';

import { Border } from "@/components/React/Border";
import { Button } from "@/components/React/Button";
import { Container } from "@/components/React/Container";
import { PageIntro } from "@/components/React/PageIntro";

function TextInput({
  label,
  ...props
}: React.ComponentPropsWithoutRef<"input"> & { label: string }) {
  const id = useId();

  return (
    <div className="group relative z-0 transition-all focus-within:z-10">
      <input
        type="text"
        id={id}
        {...props}
        placeholder=" "
        className="peer block w-full border border-neutral-300 bg-transparent px-6 pt-12 pb-4 text-base/6 text-neutral-950 ring-4 ring-transparent transition group-first:rounded-t-2xl group-last:rounded-b-2xl focus:border-neutral-950 focus:ring-neutral-950/5 focus:outline-none"
      />
      <label
        htmlFor={id}
        className="pointer-events-none absolute top-1/2 left-6 -mt-3 origin-left text-base/6 text-neutral-500 transition-all duration-200 peer-focus:-translate-y-4 peer-focus:scale-75 peer-focus:font-semibold peer-focus:text-neutral-950 peer-[:not(:placeholder-shown)]:-translate-y-4 peer-[:not(:placeholder-shown)]:scale-75 peer-[:not(:placeholder-shown)]:font-semibold peer-[:not(:placeholder-shown)]:text-neutral-950"
      >
        {label}
      </label>
    </div>
  );
}

function RadioInput({
  label,
  ...props
}: React.ComponentPropsWithoutRef<"input"> & { label: string }) {
  return (
    <label className="flex gap-x-3">
      <input
        type="radio"
        {...props}
        className="h-6 w-6 flex-none appearance-none rounded-full border border-neutral-950/20 outline-none checked:border-[0.5rem] checked:border-neutral-950 focus-visible:ring-1 focus-visible:ring-neutral-950 focus-visible:ring-offset-2"
      />
      <span className="text-base/6 text-neutral-950">{label}</span>
    </label>
  );
}

function ContactForm() {
  const [responseMessage, setResponseMessage] = useState("");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setResponseMessage(""); // Clear previous messages

    const formData = new FormData(event.currentTarget);

    try {
      const response = await fetch("/api/contact", {
        method: "POST",
        body: formData,
      });

      // 1. Parse the JSON payload from your Astro endpoint
      const data = await response.json().catch(() => null);

      if (!response.ok) {
        // 2. Print the exact n8n/server error to your browser console (F12)
        console.error("🔴 [Contact Form Error] Debug info:", data?.debug || "No extra debug info provided");
        
        // 3. Throw the user-friendly message returned by the server
        throw new Error(data?.message || "Failed to send message");
      }

      setResponseMessage("Thanks for reaching out! I’ll get back to you soon.");
      
      // Optional: Reset form fields on success
      (event.target as HTMLFormElement).reset();

    } catch (error) {
      // 4. Safely extract the error message for the UI notice
      const clientMessage = error instanceof Error ? error.message : "An unexpected error occurred.";
      setResponseMessage(`Something went wrong. Error: ${clientMessage}`);
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <h2 className="font-display text-base font-semibold text-neutral-950">
        Contact Form
      </h2>
      <div className="isolate mt-6 -space-y-px rounded-2xl bg-white/50">
        <TextInput label="Name" name="name" autoComplete="name" required />
        <TextInput
          label="Email"
          type="email"
          name="email"
          autoComplete="email"
          required
        />
        <TextInput label="Message" name="message" required />
        <div className="border border-neutral-300 px-6 py-8 first:rounded-t-2xl last:rounded-b-2xl">
          {/* Services code if you decide to uncomment it later */}
        </div>
      </div>
      <Button type="submit" className="mt-10">
        Contact now
      </Button>
      {responseMessage && (
        <p className={`mt-4 text-sm ${responseMessage.includes("Success") || responseMessage.includes("Thanks") ? "text-emerald-600" : "text-rose-600"}`}>
          {responseMessage}
        </p>
      )}
    </form>
  );
}

function ContactDetails() {
  return (
    <div>
      <h2 className="font-display text-base font-semibold text-neutral-950">
        Still hesitate?
      </h2>
      <p className="mt-6 text-base text-neutral-600">
        I'm always on the lookout for exciting new projects. Let's discuss
        yours!
      </p>

      {/* <Offices className="mt-10 grid grid-cols-1 gap-8 sm:grid-cols-2" /> */}

      <Border className="mt-16 pt-16">
        <h2 className="font-display text-base font-semibold text-neutral-950">
          Contact Info
        </h2>
        <dl className="mt-6 grid grid-cols-1 gap-8 text-sm sm:grid-cols-2">
          <div>
            <dt className="font-semibold text-neutral-950">Name</dt>
            <dd className="text-neutral-600">Ievgen Venger</dd>
          </div>
          <div>
            <dt className="font-semibold text-neutral-950">Email</dt>
            <dd>
              <a
                href="mailto:eugene@venger.me"
                className="text-neutral-600 hover:text-neutral-950"
              >
                eugene@venger.me
              </a>
            </dd>
          </div>
          <div>
            <dt className="font-semibold text-neutral-950">Phone</dt>
            <dd>
              <a
                href="tel:+48508737592"
                className="text-neutral-600 hover:text-neutral-950"
              >
                +48 508 737 592
              </a>
            </dd>
          </div>
          <div>
            <dt className="font-semibold text-neutral-950">Address</dt>
            <dd className="text-neutral-600">
              Stalowa 13, 03-425 Warsaw, Poland
            </dd>
          </div>
        </dl>
      </Border>

      {/* <Border className="mt-16 pt-16">
        <h2 className="font-display text-base font-semibold text-neutral-950">Find me here</h2>
      Place for socials 
      </Border> */}
    </div>
  );
}

export default function Contact() {
  return (
    <div className="m-auto max-w-app">
      <PageIntro
        centered
        eyebrow="Contact me"
        title="Have an idea for the project or some feedback?"
      >
        <p>Text me back!</p>
      </PageIntro>

      <Container className="my-24 sm:my-32 lg:my-40">
        <div className="flex flex-col-reverse gap-x-8 gap-y-24">
          <ContactDetails />
          <ContactForm />
        </div>
      </Container>
    </div>
  );
}
