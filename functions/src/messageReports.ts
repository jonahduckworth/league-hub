import {logger} from "firebase-functions";
import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {onDocumentCreated as onFirestoreCreated} from "firebase-functions/v2/firestore";
import {db} from "./helpers";
import {
  messageReportIdempotencyKey,
  requireSuccessfulMessageReportDelivery,
} from "./messageReportsLogic";

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const destination = "jonah@leaguehub.ca";
const sender = "League Hub <no-reply@leaguehub.ca>";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

export const onMessageReportCreated = onFirestoreCreated(
  {
    document: "organizations/{orgId}/messageReports/{reportId}",
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
    secrets: [RESEND_API_KEY],
    retry: true,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const fields = {
      organization: event.params.orgId,
      reportId: event.params.reportId,
      roomId: String(data.roomId ?? "Unknown"),
      messageId: String(data.messageId ?? "Unknown"),
      reporterId: String(data.reporterId ?? "Unknown"),
      reportedUserId: String(data.reportedUserId ?? "Unknown"),
      reason: String(data.reason ?? "Not provided"),
      details: String(data.details ?? "Not provided"),
    };
    const rows = Object.entries(fields)
      .map(([label, value]) =>
        `<tr><th align="left" style="padding:6px 14px 6px 0;color:#59708e">${escapeHtml(label)}</th><td style="padding:6px 0;color:#061a33">${escapeHtml(value)}</td></tr>`,
      )
      .join("");

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY.value()}`,
        "Content-Type": "application/json",
        "Idempotency-Key": messageReportIdempotencyKey(
          event.params.orgId,
          event.params.reportId,
        ),
      },
      body: JSON.stringify({
        from: sender,
        to: [destination],
        subject: `[League Hub Safety] ${fields.reason}`,
        text: Object.entries(fields)
          .map(([label, value]) => `${label}: ${value}`)
          .join("\n"),
        html: `<!doctype html><html><body style="font-family:Arial,sans-serif;background:#f4f8fc;padding:28px"><main style="max-width:680px;margin:auto;background:#fff;border-radius:18px;padding:28px;border:1px solid #d9e5f1"><p style="color:#087e91;font-weight:700;letter-spacing:.08em;text-transform:uppercase">League Hub safety</p><h1 style="color:#061a33;font-size:24px">New message report</h1><table style="border-collapse:collapse">${rows}</table></main></body></html>`,
      }),
    });
    if (!response.ok) {
      const responseBody = await response.text();
      logger.error("League Hub safety report email failed", {
        status: response.status,
        response: responseBody.slice(0, 500),
        reportId: event.params.reportId,
      });
      await db.collection("organizations")
        .doc(event.params.orgId)
        .collection("messageReports")
        .doc(event.params.reportId)
        .set({
          deliveryStatus: "retrying",
          lastDeliveryErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      requireSuccessfulMessageReportDelivery(response.status, responseBody);
    }
    await db.collection("organizations")
      .doc(event.params.orgId)
      .collection("messageReports")
      .doc(event.params.reportId)
      .set({
        deliveryStatus: "delivered",
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    logger.info("League Hub safety report delivered", {
      reportId: event.params.reportId,
    });
  },
);
