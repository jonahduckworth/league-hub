import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Terms of Use | League Hub", description: "Terms governing access to the League Hub mobile and administration services.", alternates: { canonical: "/terms" } };

export default function TermsPage() {
  return (
    <LegalPage eyebrow="Terms of use" title="Clear expectations for a shared league workspace." intro="These terms govern use of the League Hub mobile app, administration workspace, and related services." updated="August 11, 2026">
      <section><h2>Access and eligibility</h2><p>You may use League Hub only through an authorized organization account and must provide accurate information, protect your credentials, and follow your organization’s rules. If you use League Hub for a minor, you confirm you have authority to do so.</p></section>
      <section><h2>Community guidelines and acceptable use</h2><p>Keep communication respectful, relevant, and safe. Do not misuse the service, access another person’s account, bypass access controls, upload unlawful or harmful material, threaten or harass others, promote hate or discrimination, share sexual or exploitative material, spam or mislead people, interfere with the platform, scrape private content, or use League Hub in a way that violates law or third-party rights.</p><p>Users can report messages or people and block other users from message actions in the app. League Hub and organization administrators may review reports, remove content, restrict access, and preserve relevant records where reasonably required for safety, league operations, or legal compliance. Contact <a href="mailto:jonah@jdbuilds.ca">jonah@jdbuilds.ca</a> with urgent safety concerns.</p></section>
      <section><h2>Organization content</h2><p>Organizations and users remain responsible for the content they submit. You grant League Hub the limited permission needed to host, process, display, and transmit that content for the service. Organization administrators control member access and may manage or remove organization content.</p></section>
      <section><h2>Schedules and third-party sources</h2><p>League Hub may display schedule information from organization-approved or public sources. We work to keep it current, but leagues remain the authoritative source for game times, locations, cancellations, and eligibility decisions.</p></section>
      <section><h2>Availability and changes</h2><p>We may maintain, update, suspend, or change parts of League Hub to protect users, comply with law, or improve the service. We do not promise uninterrupted availability, although we design for dependable day-to-day use.</p></section>
      <section><h2>Disclaimer and liability</h2><p>League Hub is provided on an “as available” basis to the extent permitted by law. It is an information and communication tool, not an emergency, medical, legal, officiating, or safety service. JD Builds is not liable for indirect, special, incidental, or consequential damages arising from use of the service to the extent permitted by law.</p></section>
      <section><h2>Termination</h2><p>You may stop using League Hub or request account deletion. We or your organization may restrict access for security, policy violations, legal requirements, or when your role ends. Provisions that reasonably should survive termination will continue.</p></section>
      <section><h2>Contact and governing law</h2><p>Questions can be sent to <a href="mailto:jonah@jdbuilds.ca">jonah@jdbuilds.ca</a>. These terms are governed by the laws of Alberta and the applicable federal laws of Canada, without limiting consumer rights that cannot legally be waived.</p></section>
    </LegalPage>
  );
}
