const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const sharp = require(path.join(root, "apps/admin/node_modules/sharp"));
const rawDirectory = path.join(__dirname, "screenshots/raw");
const appleDirectory = path.join(
  __dirname,
  "screenshots/app-store-iphone-6.5",
);
const googleDirectory = path.join(__dirname, "screenshots/google-play");

const screenshots = [
  ["01-home.png", "Your league at a glance", "Games, updates and tools in one place"],
  ["02-schedule.png", "Every game. One clean schedule.", "Times, teams and venues—always close"],
  ["03-results.png", "Results without the digging", "Scores and game details in a focused view"],
  ["04-communication.png", "Updates and chats, together", "Pinned announcements lead into every conversation"],
  ["05-team-chat.png", "Team chat that stays organized", "Keep the right people connected"],
  ["06-contacts.png", "The right contact, right away", "League roles and people at a glance"],
];

const escapeXml = (value) => value.replace(/[&<>"']/g, (character) => ({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&apos;",
}[character]));

async function renderScreenshot(fileName, headline, supportingText) {
  const raw = path.join(rawDirectory, fileName);
  const device = await sharp(raw)
    .resize(1120, 2434, { fit: "fill", kernel: sharp.kernel.lanczos3 })
    .png()
    .toBuffer();
  const background = Buffer.from(`
    <svg width="1242" height="2688" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#04172b"/>
          <stop offset="0.7" stop-color="#092743"/>
          <stop offset="1" stop-color="#0b5361"/>
        </linearGradient>
        <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
          <feDropShadow dx="0" dy="20" stdDeviation="22" flood-color="#000" flood-opacity="0.42"/>
        </filter>
      </defs>
      <rect width="1242" height="2688" fill="url(#bg)"/>
      <text x="621" y="105" fill="#64e0dc" text-anchor="middle"
        font-family="Arial, Helvetica, sans-serif" font-size="28" font-weight="800"
        letter-spacing="5">LEAGUE HUB</text>
      <text x="621" y="170" fill="#fff" text-anchor="middle"
        font-family="Arial, Helvetica, sans-serif" font-size="48" font-weight="800">${escapeXml(headline)}</text>
      <text x="621" y="216" fill="#a9c1d4" text-anchor="middle"
        font-family="Arial, Helvetica, sans-serif" font-size="25" font-weight="600">${escapeXml(supportingText)}</text>
      <rect x="61" y="254" width="1120" height="2434" rx="72" fill="#06182c" filter="url(#shadow)"/>
    </svg>`);

  const output = await sharp(background)
    .composite([{ input: device, left: 61, top: 254 }])
    .removeAlpha()
    .png({ compressionLevel: 9 })
    .toBuffer();

  fs.mkdirSync(appleDirectory, { recursive: true });
  fs.mkdirSync(googleDirectory, { recursive: true });
  await fs.promises.writeFile(path.join(appleDirectory, fileName), output);
  await fs.promises.writeFile(path.join(googleDirectory, fileName), output);
}

async function main() {
  for (const screenshot of screenshots) {
    await renderScreenshot(...screenshot);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
