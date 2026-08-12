const fs = require("node:fs");
const path = require("node:path");
const sharp = require("sharp");

const root = path.resolve(__dirname, "..");
const brandMark = path.join(root, "assets/brand/league-hub-app-icon-1024.png");
const featureOutput = path.join(__dirname, "google-play/feature-graphic-1024x500.png");

const escapeXml = (value) => value.replace(/[&<>"']/g, (character) => ({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  "\"": "&quot;",
  "'": "&apos;",
}[character]));

async function renderFeatureGraphic() {
  fs.mkdirSync(path.dirname(featureOutput), { recursive: true });
  const mark = await sharp(brandMark).resize(250, 250).png().toBuffer();
  const svg = Buffer.from(`
    <svg width="1024" height="500" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#04172B"/>
          <stop offset="0.62" stop-color="#092B4B"/>
          <stop offset="1" stop-color="#0B5968"/>
        </linearGradient>
        <radialGradient id="glow">
          <stop offset="0" stop-color="#61D8D5" stop-opacity="0.25"/>
          <stop offset="1" stop-color="#61D8D5" stop-opacity="0"/>
        </radialGradient>
      </defs>
      <rect width="1024" height="500" fill="url(#bg)"/>
      <circle cx="880" cy="-10" r="310" fill="url(#glow)"/>
      <circle cx="1024" cy="500" r="260" fill="url(#glow)" opacity="0.5"/>
      <text x="372" y="167" fill="#FFFFFF" font-family="Arial, Helvetica, sans-serif" font-weight="800" font-size="62">League Hub</text>
      <text x="372" y="253" fill="#FFFFFF" font-family="Arial, Helvetica, sans-serif" font-weight="800" font-size="48">Your league. One clear place.</text>
      <text x="372" y="320" fill="#A9C1D4" font-family="Arial, Helvetica, sans-serif" font-weight="600" font-size="26">${escapeXml("Schedules  •  Updates  •  Chats  •  Policies")}</text>
      <rect x="372" y="363" width="215" height="6" rx="3" fill="#61D8D5"/>
    </svg>`);
  await sharp(svg)
    .composite([{ input: mark, left: 76, top: 125 }])
    .png({ compressionLevel: 9 })
    .toFile(featureOutput);
}

renderFeatureGraphic().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
