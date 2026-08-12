import type { Metadata } from "next";
import { DeletionRequestForm } from "@/components/deletion-request-form";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Support | League Hub", description: "League Hub support, account help, and account deletion requests.", alternates: { canonical: "/support" } };

export default function SupportPage() {
  return (
    <LegalPage eyebrow="Support" title="Get help from a real person." intro="For account access, organization setup, schedule, chat, or policy questions, contact League Hub support." updated="August 11, 2026">
      <section><h2>Contact support</h2><p>Email <a href="mailto:jonah@jdbuilds.ca">jonah@jdbuilds.ca</a>. Include your organization name and the email address used for League Hub. We usually respond within one business day.</p></section>
      <section><h2>Account access</h2><p>League Hub accounts are invitation-based. If your invitation expired, your role or team is incorrect, or you cannot sign in, contact your organization administrator or League Hub support. Never send your password by email.</p></section>
      <section id="delete-account"><h2>Delete your account</h2><p>The fastest method is inside the app: <strong>Settings → Privacy &amp; Security → Delete Account</strong>. You will be asked to re-enter your password. Organization owners must transfer ownership before deleting their account so their league is never left without an owner.</p><p>If you cannot access the app, submit the form below from the email address tied to your account. We will verify ownership before deleting the account. Your Firebase sign-in, personal League Hub profile, push tokens, assignments, profile image, and identity attached to organization content will be removed. Organization records such as messages may remain only in anonymized historical form where needed for league continuity or legal obligations.</p><DeletionRequestForm /></section>
    </LegalPage>
  );
}
