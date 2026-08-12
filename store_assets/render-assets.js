const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const sharp = require(path.join(root, "apps/admin/node_modules/sharp"));
const masterArtwork = path.join(root, "assets/brand/league-hub-master.png");
const brandMark = path.join(root, "assets/brand/league-hub-app-icon-1024.png");
const featureOutput = path.join(__dirname, "google-play/feature-graphic-1024x500.png");

const outputs = new Map([
  ["assets/brand/league-hub-app-icon-1024.png", 1024],
  ["assets/brand/league-hub-play-icon-512.png", 512],
  ["assets/brand/league-hub-web-icon-256.png", 256],
  ["apps/marketing/public/league-hub-icon.png", 256],
  ["apps/admin/public/league-hub-icon.png", 256],
  ["store_assets/google-play/app-icon-512.png", 512],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", 20],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", 40],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", 60],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", 29],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", 58],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", 87],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", 40],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", 80],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", 120],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", 120],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", 180],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", 76],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", 152],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", 167],
  ["ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", 1024],
  ["ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png", 168],
  ["ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png", 336],
  ["ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png", 504],
  ["android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48],
  ["android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72],
  ["android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96],
  ["android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144],
  ["android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192],
]);

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

async function renderBrandAssets() {
  for (const [relativeOutput, size] of outputs) {
    const output = path.join(root, relativeOutput);
    fs.mkdirSync(path.dirname(output), { recursive: true });
    await sharp(masterArtwork)
      .resize(size, size, { fit: "fill", kernel: sharp.kernel.lanczos3 })
      .png({ compressionLevel: 9 })
      .toFile(output);
  }

  await sharp(masterArtwork)
    .resize(630, 630, { fit: "fill", kernel: sharp.kernel.lanczos3 })
    .extend({
      top: 0,
      bottom: 0,
      left: 285,
      right: 285,
      background: "#06182c",
    })
    .png({ compressionLevel: 9 })
    .toFile(path.join(root, "apps/marketing/public/league-hub-social.png"));
}

async function main() {
  await renderBrandAssets();
  await renderFeatureGraphic();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
