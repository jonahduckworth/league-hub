import {createHash} from "crypto";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";
import {db} from "./helpers";
import {
  allowedLandingOrigin,
  landingContactEmail,
  parseLandingContact,
} from "./landingContactLogic";

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const destination = "jonah@jdbuilds.ca";
const sender = "League Hub <notifications@jdbuilds.ca>";

function clientIp(request: {headers: Record<string, unknown>; ip?: string}): string {
  const forwarded = request.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) {
    return forwarded.split(",")[0].trim();
  }
  return request.ip ?? "unknown";
}

async function consumeRateLimit(ip: string): Promise<boolean> {
  const id = createHash("sha256").update(`league-hub-contact:${ip}`).digest("hex");
  const ref = db.collection("_landingContactRateLimits").doc(id);
  const now = Date.now();
  const windowMs = 60 * 60 * 1000;
  const maximum = 5;

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() ?? {};
    const windowStartedAt = typeof data.windowStartedAt === "number" ?
      data.windowStartedAt : 0;
    const count = typeof data.count === "number" ? data.count : 0;

    if (now - windowStartedAt >= windowMs) {
      transaction.set(ref, {
        count: 1,
        windowStartedAt: now,
        expiresAt: admin.firestore.Timestamp.fromMillis(now + 2 * windowMs),
      });
      return true;
    }
    if (count >= maximum) return false;

    transaction.update(ref, {
      count: count + 1,
      expiresAt: admin.firestore.Timestamp.fromMillis(now + 2 * windowMs),
    });
    return true;
  });
}

export const submitLandingContact = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
    secrets: [RESEND_API_KEY],
    invoker: "public",
  },
  async (request, response) => {
    const origin = allowedLandingOrigin(request.get("origin"));
    if (origin) {
      response.set("Access-Control-Allow-Origin", origin);
      response.set("Vary", "Origin");
    }
    response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    response.set("Access-Control-Allow-Headers", "Content-Type");
    response.set("Cache-Control", "no-store");
    response.set("X-Content-Type-Options", "nosniff");

    if (request.method === "OPTIONS") {
      response.status(origin ? 204 : 403).send();
      return;
    }
    if (request.method !== "POST") {
      response.status(405).json({error: "Method not allowed."});
      return;
    }
    if (!origin) {
      response.status(403).json({error: "Origin not allowed."});
      return;
    }
    if (!request.is("application/json")) {
      response.status(415).json({error: "Send JSON."});
      return;
    }

    const parsed = parseLandingContact(request.body);
    if (!parsed.ok) {
      response.status(parsed.isBot ? 200 : 400).json(
        parsed.isBot ? {ok: true} : {error: parsed.reason},
      );
      return;
    }

    if (!await consumeRateLimit(clientIp(request))) {
      response.status(429).json({error: "Please wait before sending another inquiry."});
      return;
    }

    const message = landingContactEmail(parsed.contact);
    let resendResponse: Response;
    try {
      resendResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: sender,
          to: [destination],
          reply_to: parsed.contact.email,
          subject: message.subject,
          text: message.text,
          html: message.html,
        }),
      });
    } catch (error) {
      logger.error("League Hub contact email request failed", {error});
      response.status(502).json({error: "Message delivery failed."});
      return;
    }

    if (!resendResponse.ok) {
      const failure = await resendResponse.text();
      logger.error("League Hub contact email failed", {
        status: resendResponse.status,
        response: failure.slice(0, 500),
      });
      response.status(502).json({error: "Message delivery failed."});
      return;
    }

    const resendResult = await resendResponse.json() as {id?: unknown};
    logger.info("League Hub contact inquiry accepted by Resend", {
      inquiryType: parsed.contact.inquiryType,
      resendId: typeof resendResult.id === "string" ? resendResult.id : "missing",
    });
    response.status(200).json({ok: true});
  },
);
