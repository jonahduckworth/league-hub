import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = {
  title: "Privacy Policy | League Hub",
  description: "How League Hub collects, uses, protects, and deletes personal information.",
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  return (
    <LegalPage eyebrow="Privacy" title="Your information should serve your league—not the other way around." intro="This policy explains what League Hub handles, why it is needed, and the choices available to members and organizations." updated="August 11, 2026">
      <section><h2>Who operates League Hub</h2><p>League Hub is a product of JD Builds, based in Alberta, Canada. Questions can be sent to <a href="mailto:jonah@jdbuilds.ca">jonah@jdbuilds.ca</a>.</p></section>
      <section><h2>Information we handle</h2><ul>
        <li><strong>Account and profile information:</strong> name, email address, optional title, phone, address, profile photo, organization, role, and team or league assignments.</li>
        <li><strong>Organization content:</strong> messages, chat attachments, announcements, policies, forms, schedules, results, team information, and contact-directory details supplied through your organization.</li>
        <li><strong>Device and service information:</strong> push-notification tokens, basic connection information, and diagnostic information produced by our hosting and security providers.</li>
        <li><strong>Location:</strong> only when you choose the weather feature and grant permission. Your current coordinates are sent to Open-Meteo to return local weather and are not saved to your League Hub profile.</li>
      </ul></section>
      <section><h2>How we use information</h2><p>We use information to authenticate members, show the correct league and team content, deliver messages and notifications, operate schedules and resources, secure the service, provide support, and improve reliability. League Hub does not sell personal information or use it for third-party advertising.</p></section>
      <section><h2>Service providers and disclosure</h2><p>League Hub relies on Google Firebase for authentication, database, file storage, hosting, and push notifications; Open-Meteo for optional weather; and Resend for messages submitted through LeagueHub.ca. These providers process only the information needed to provide those services. We may also disclose information when required by law, to protect users or the service, or as part of a business transfer with appropriate safeguards.</p></section>
      <section><h2>Organization control and youth users</h2><p>League Hub is an invitation-based organization platform. Each organization controls its membership, assignments, and content. League Hub is not directed to children under 13 for independent use. Organizations that invite youth participants are responsible for obtaining any consent required from a parent or guardian and limiting the information they provide.</p></section>
      <section><h2>Retention, security, and deletion</h2><p>We retain account information while an account is active and as needed to provide, secure, and comply with legal obligations for the service. Users can initiate account deletion in <strong>Settings → Privacy &amp; Security → Delete Account</strong> or use our <a href="/support#delete-account">web request form</a>. Organization owners must transfer ownership first so their league is not orphaned. Deletion removes the sign-in account, personal profile, profile image, push tokens, assignments, and identity from organization content. Organization records such as messages may be retained only in an anonymized historical form where needed for league continuity, safety, dispute resolution, or legal obligations.</p><p>We use encrypted transport, Firebase security controls, role-based access, and scoped administration. No internet service can guarantee absolute security.</p></section>
      <section><h2>Your choices</h2><p>You can edit supported profile fields, control notification and location permissions through your device, request access or correction, or request deletion. Your organization administrator may also help correct organization-managed assignments and content.</p></section>
      <section><h2>Changes</h2><p>We may update this policy as League Hub evolves. Material changes will be posted here with a new effective date.</p></section>
    </LegalPage>
  );
}
