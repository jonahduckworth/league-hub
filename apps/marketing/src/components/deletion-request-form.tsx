"use client";

import { FormEvent, useState } from "react";
import { ArrowRight, CheckCircle2, LoaderCircle } from "lucide-react";

const endpoint =
  process.env.NEXT_PUBLIC_CONTACT_ENDPOINT ??
  "https://us-central1-jdb-league-hub.cloudfunctions.net/submitLandingContact";

type FormState = "idle" | "sending" | "success" | "error";

export function DeletionRequestForm() {
  const [startedAt, setStartedAt] = useState(0);
  const [state, setState] = useState<FormState>("idle");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState("sending");
    const values = new FormData(event.currentTarget);
    const email = String(values.get("email") ?? "");
    const organization = String(values.get("organization") ?? "");

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          inquiryType: "account_deletion",
          name: "Account deletion request",
          email,
          organization,
          role: "",
          teamCount: "",
          message:
            "Please delete the League Hub account associated with this email address. I understand League Hub may contact me to verify ownership before deletion.",
          website: "",
          startedAt,
        }),
      });
      if (!response.ok) throw new Error("request failed");
      setState("success");
    } catch {
      setState("error");
    }
  }

  if (state === "success") {
    return (
      <div className="deletion-success" role="status">
        <CheckCircle2 size={25} aria-hidden="true" />
        <div>
          <strong>Request received</strong>
          <p>We’ll email you to verify account ownership before completing the deletion.</p>
        </div>
      </div>
    );
  }

  return (
    <form
      className="deletion-form"
      onFocusCapture={() => {
        if (startedAt === 0) setStartedAt(Date.now());
      }}
      onSubmit={submit}
    >
      <div className="field">
        <label htmlFor="deletion-email">League Hub account email</label>
        <input id="deletion-email" name="email" type="email" autoComplete="email" required />
      </div>
      <div className="field">
        <label htmlFor="deletion-organization">Organization or league</label>
        <input id="deletion-organization" name="organization" minLength={2} required />
      </div>
      <div className="honeypot" aria-hidden="true">
        <label htmlFor="deletion-website">Website</label>
        <input id="deletion-website" name="website" tabIndex={-1} autoComplete="off" />
      </div>
      {state === "error" && (
        <p className="form-error" role="alert">
          We couldn’t send that request. Email <a href="mailto:jonah@jdbuilds.ca">jonah@jdbuilds.ca</a> from your account address.
        </p>
      )}
      <button className="button button-primary button-form" type="submit" disabled={state === "sending"}>
        {state === "sending" ? (
          <><LoaderCircle className="spinner" size={18} /> Sending…</>
        ) : (
          <>Request deletion <ArrowRight size={18} /></>
        )}
      </button>
    </form>
  );
}
