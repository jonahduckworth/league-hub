"use client";

import { FormEvent, useState } from "react";
import { ArrowRight, CheckCircle2, LoaderCircle } from "lucide-react";
import { ContactPayload, InquiryType, inquiryLabel } from "@/lib/contact";

const endpoint =
  process.env.NEXT_PUBLIC_CONTACT_ENDPOINT ??
  "https://us-central1-jdb-league-hub.cloudfunctions.net/submitLandingContact";

type FormState = "idle" | "sending" | "success" | "error";

export function ContactForm() {
  const [startedAt] = useState(() => Date.now() - 2_000);
  const [state, setState] = useState<FormState>("idle");
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState("sending");
    setError("");

    const form = event.currentTarget;
    const values = new FormData(form);
    const requestStartedAt = Date.now() - startedAt > 55 * 60 * 1000
      ? Date.now() - 2_000
      : startedAt;
    const payload: ContactPayload = {
      inquiryType: values.get("inquiryType") as InquiryType,
      name: String(values.get("name") ?? ""),
      email: String(values.get("email") ?? ""),
      organization: String(values.get("organization") ?? ""),
      role: String(values.get("role") ?? ""),
      teamCount: String(values.get("teamCount") ?? ""),
      message: String(values.get("message") ?? ""),
      website: String(values.get("website") ?? ""),
      startedAt: requestStartedAt,
    };

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!response.ok) throw new Error("request failed");
      setState("success");
      form.reset();
    } catch {
      setState("error");
      setError(
        "We couldn't send that right now. Please email jonah@leaguehub.ca and we'll get back to you.",
      );
    }
  }

  if (state === "success") {
    return (
      <div className="form-success" role="status" aria-live="polite">
        <span className="success-icon" aria-hidden="true">
          <CheckCircle2 size={28} />
        </span>
        <p className="eyebrow">Message received</p>
        <h3>Thanks — we'll be in touch.</h3>
        <p>
          Your note is on its way to Jonah. Expect a personal response within one business day.
        </p>
        <button className="text-button" type="button" onClick={() => setState("idle")}>
          Send another message
        </button>
      </div>
    );
  }

  return (
    <form
      className="contact-form"
      onSubmit={submit}
    >
      <div className="field field-wide">
        <label htmlFor="inquiryType">What can we help with?</label>
        <select id="inquiryType" name="inquiryType" defaultValue="pricing">
          {(["pricing", "demo", "general"] as InquiryType[]).map((type) => (
            <option key={type} value={type}>
              {inquiryLabel(type)}
            </option>
          ))}
        </select>
      </div>
      <div className="field">
        <label htmlFor="name">Your name</label>
        <input id="name" name="name" autoComplete="name" minLength={2} required />
      </div>
      <div className="field">
        <label htmlFor="email">Work email</label>
        <input id="email" name="email" type="email" autoComplete="email" required />
      </div>
      <div className="field">
        <label htmlFor="organization">League or organization</label>
        <input id="organization" name="organization" autoComplete="organization" minLength={2} required />
      </div>
      <div className="field">
        <label htmlFor="role">Your role <span>Optional</span></label>
        <input id="role" name="role" autoComplete="organization-title" placeholder="e.g. Executive Director" />
      </div>
      <div className="field field-wide">
        <label htmlFor="teamCount">Rough number of teams <span>Optional</span></label>
        <select id="teamCount" name="teamCount" defaultValue="">
          <option value="">Select a range</option>
          <option value="1-10">1–10 teams</option>
          <option value="11-30">11–30 teams</option>
          <option value="31-75">31–75 teams</option>
          <option value="76+">76+ teams</option>
        </select>
      </div>
      <div className="field field-wide">
        <label htmlFor="message">What would make League Hub valuable for you?</label>
        <textarea id="message" name="message" rows={5} minLength={10} required />
      </div>
      <div className="honeypot" aria-hidden="true">
        <label htmlFor="website">Website</label>
        <input id="website" name="website" tabIndex={-1} autoComplete="off" />
      </div>
      {state === "error" && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}
      <div className="form-submit field-wide">
        <p>
          By submitting, you agree that we may contact you about League Hub. We don't sell your details.
        </p>
        <button className="button button-primary button-form" type="submit" disabled={state === "sending"}>
          {state === "sending" ? (
            <>
              <LoaderCircle className="spinner" size={18} aria-hidden="true" /> Sending…
            </>
          ) : (
            <>
              Send inquiry <ArrowRight size={18} aria-hidden="true" />
            </>
          )}
        </button>
      </div>
    </form>
  );
}
